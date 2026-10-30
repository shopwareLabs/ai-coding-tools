# Plugin Backend

Contents: [DAL/modeling](#dal-and-data-modeling), [migrations](#migrations-and-schema-safety), [APIs](#store-api-and-admin-api), [HTTP cache](#http-cache-and-reverse-proxy-safety), [Messenger implementation](messenger-handlers.md), [6.7 changes](#67-core-changes-that-affect-backend-code).

## Architecture

Shape plugin backend code like a disciplined Symfony application:

- thin glue layer
  Controllers, subscribers, message handlers, scheduled tasks, Store API/Admin API routes.
- application services
  Business rules, orchestration, state transitions, idempotency, retries.
- infrastructure adapters
  DAL repositories, HTTP clients, SDK wrappers, filesystem access.

Keep orchestration out of controllers and subscribers.

## First Principles

- Treat every feature as either request-path code or background code. Request-path code must stay cheap.
- Protect hot paths first: cart, checkout, login, account, and any large admin listing.
- Treat cache hit rate, invalidation frequency, indexer backlog, queue backlog, and DB query count as the primary performance levers.
- Keep an uninstall and cleanup story for every custom entity row, custom field, config key, media asset, and scheduled operational artifact.

## Plugin Structure

Baseline structure:

- `composer.json` with PSR-4 autoloading
- `src/<Plugin>.php` kept thin
- `src/Service/`
- `src/Subscriber/`
- `src/MessageHandler/`
- `src/Migration/`
- `src/Resources/config/services.xml`

Use install/update lifecycle code only for plugin lifecycle concerns, not general business behavior.

## Compatibility and Upgrade Safety

- Pin supported Shopware packages conservatively. Avoid broad wildcard constraints.
- Prefer documented extension points and stable core patterns over `@internal` behavior.
- Do not copy core-only metadata such as `#[Package(...)]` or `@internal` tags into plugin public code.
- If a design intentionally couples to a fragile event payload or core behavior, document that coupling explicitly.

## DI and Service Design

- Use constructor injection only.
- Avoid `$container->get()` in runtime code.
- Prefer decoration or events over replacing core behavior by inheritance.
- Wrap external clients in services that centralize timeouts, retries, and logging policy.
- Prefer one reusable seam over duplicated near-identical services when the behavior is actually shared.

## DAL and Data Modeling

- Use DAL first; fall back to DBAL only when necessary.
- Load only required associations. Do not hydrate full entity graphs by default.
- Prefer `searchIds()` when only identifiers are needed, then fetch a second time only if full entities are required.
- Never call repository `search()` inside loops over entities or line items. Treat that as a classic N+1 failure.
- Paginate admin lists, exports, and sync jobs rather than assuming bounded result sizes.
- Distinguish complete reads of a bounded ID set from open-ended discovery. Batch discovery to exhaustion; a hard result cap alone silently drops records.
- Avoid pulling large serialized blobs such as cart payloads unless absolutely necessary; batch and cap memory if you must.
- Use custom fields for merchant-managed metadata, not write-heavy operational data.
- Use entity extensions or custom entities for structured domain state.
- Do not use mutable JSON payload fields on line items, orders, or logs as primary operational query state. If you need to query or deduplicate by that state, model it in indexed columns or a custom entity instead.
- Merge existing custom fields instead of overwriting the full array unless replacing everything is intentional and safe.
- Remove normalization only when the validation contract already guarantees the required format. A `string` return type excludes null, not whitespace or an invalid identifier.

Entity extension decision matrix:

| Need | Prefer | Avoid when |
| --- | --- | --- |
| a few merchant-managed values on an existing entity | custom fields | the data drives high-volume writes, deduplication, or indexed operational queries |
| structured fields attached to an existing entity with code ownership | entity extension | the state really has its own lifecycle or needs standalone queries |
| standalone operational state, dedupe keys, sync history, or batch processing | custom entity | the data is just editorial decoration on an existing entity |
| merchant-defined structure in 6.7+ where dynamic entities truly fit the requirement | dynamic custom entities | the requirement needs plugin-owned behavior, strict invariants, or broad 6.6 support |

Example patterns:

```php
// Bad: full entity hydration just to collect IDs inside a loop
foreach ($customers as $customer) {
    $criteria = new Criteria();
    $criteria->addFilter(new EqualsFilter('customerId', $customer->getId()));

    $orders = $this->orderRepository->search($criteria, $context);
    $this->syncOrderIds($orders->getIds());
}
```

```php
// Preferred: discover all matching IDs in batches, not only the first page
$criteria = new Criteria();
$criteria->addFilter(new EqualsAnyFilter('customerId', $customerIds));
$criteria->setLimit(200);

$iterator = new RepositoryIterator($this->orderRepository, $context, $criteria);
while (($orderIds = $iterator->fetchIds()) !== null) {
    $this->syncOrderIds($orderIds);
}
```

```php
// Bad: loading full associations and blobs for an admin list
$criteria = new Criteria();
$criteria->addAssociation('lineItems');
$criteria->addAssociation('transactions');
$criteria->addAssociation('addresses');
```

```php
// Preferred: bounded list query plus targeted fields
$criteria = new Criteria();
$criteria->setLimit(50);
$criteria->setOffset($offset);
$criteria->addAssociation('transactions.stateMachineState');
$criteria->addFields(['id', 'orderNumber', 'createdAt']);
```

```php
// Preferred: merge custom fields instead of replacing unrelated state
$payload = [
    'id' => $orderId,
    'customFields' => [
        ...($order->getCustomFields() ?? []),
        'my_plugin_sync_state' => 'queued',
    ],
];
```

```php
// A typed string can still need normalization if the input contract allows whitespace
$code = trim($config->getWebhookCode());
```

```php
// Direct use is correct only if validation already guarantees the canonical format
$code = $config->getWebhookCode();
```

## Migrations and Schema Safety

- Keep schema changes idempotent where possible.
- Keep large data backfills out of `update()`. Ship schema first, backfill asynchronously in batches, and add final constraints or indexes only after the data is ready.
- Automatic plugin install/update runs non-destructive `update()` migrations only. Keep schema required by the deployed code there; defer destructive cleanup to an explicitly planned `database:migrate-destructive <BundleName> --all` pass after retention, backup, rollback, and old-code compatibility decisions. Do not move destructive work into automatic updates merely to make it execute. See [lifecycle details](26-plugin-lifecycle-and-activation.md).
- Add indexes that match real filters, joins, and sort keys.
- Add composite unique indexes where they enforce idempotency or natural uniqueness for operational tables.
- Use parameter binding for manual SQL.
- Do not edit already executed migration classes; add a new migration unless the repo explicitly has a safe local-only migration policy.

## Store API and Admin API

- Keep routes thin and decoratable.
- Apply the correct route scope and permissions.
- Expose storefront-relevant behavior through Store API when headless use is plausible.
- Prefer cacheable reads where it is safe and make writes clearly non-cacheable.
- Enforce ownership server-side on Store API routes. Never expose privileged operations there.
- Keep privileged operations behind Admin API plus ACL.
- Provider callbacks are a separate trust boundary: authenticate signatures and replay constraints, resolve provider references server-side, and deduplicate events. They do not require a merchant Admin API access token; choose route scope/authentication deliberately rather than exposing general admin capabilities.
- Keep API error shapes consistent and avoid leaking internal exception details through public responses.
- Version or isolate externally consumed contracts when breaking changes would affect headless or third-party clients.
- Apply rate limiting deliberately on abuse-prone or public endpoints, not blindly across trusted internal flows.
- Never accept raw `Criteria`, arbitrary associations, or client-selected query complexity directly from request payloads. Whitelist filters, pagination, sorting, and include depth explicitly.
- Keep headless endpoints bounded. Do not return "all snippets", "all entities", or deep graphs without a pagination and payload-size strategy.
- Public Store API or headless payment routes must never create authoritative local paid transaction rows or decide payment success from browser-authored inputs.
- For headless payment flows, derive amount, currency, and order context from server-side cart or order recalculation before any provider charge or local payment-state write.
- Resolve current-customer vaulted or saved-payment records server-side. Do not accept raw browser-stored vault identifiers as authoritative without ownership resolution.
- Prefer decorating services or inner routes over redefining existing public routes. Route duplication or controller copy-paste often drops ACL, validation, or behavior guarantees.
- Do not call your own shop's Admin API or Store API over HTTP from backend code in the same project. Inject the underlying services or repositories directly.
- If multiple valid persistence flows exist, pause before choosing when the decision changes entity save behavior, immediate-write behavior, or the data model.
- If plugin-owned data conceptually belongs to the parent entity edit flow, prefer the normal entity save pipeline by default.

Keep detailed collector, processor, validator, delivery, and promotion pipeline rules in `18-cart-and-checkout-pipeline.md` instead of expanding this file with cart internals.

## HTTP Cache and Reverse Proxy Safety

- Mark storefront routes cacheable only when they are `GET`-only, read-only, and state-safe.
- For custom storefront controllers, use `defaults: ['_httpCache' => true]` and load data through page loaders or Store API routes so core cache tags remain authoritative.
- `sw-cache-hash` groups equivalent contexts, not individual customers or carts. It includes selected rules, version, currency, tax state, and login state, plus Store API language in 6.7.15.1. Customer IDs, cart tokens, and cart contents are not default hash parts. See [exact keys and precedence](23-cache-and-http-cache.md#what-the-http-cache-key-varies-on).
- Legacy `sw-invalidation-states` can skip cache for `logged-in`/`cart-filled`; those states are bypassed under `CACHE_REWORK` or `PERFORMANCE_TWEAKS`. Inspect the installed patch and flags, not a permanent logged-in bypass assumption.
- Never touch the session, set custom cookies, or render customer-specific markup from an otherwise cacheable route just to personalize a small fragment. Split that fragment into AJAX, ESI, or a dedicated non-cacheable endpoint.
- Verify that loaded dependencies contribute tags to the cached response and that writes invalidate them. Add targeted tags/invalidation for plugin-owned dependencies; merely calling a page loader is not proof of coverage.

Example patterns:

```php
// Bad: cacheable route mutates session state and renders personalized data
#[Route(path: '/promo', name: 'frontend.my-plugin.promo', methods: ['GET'], defaults: ['_httpCache' => true])]
public function promo(Request $request, SalesChannelContext $context): Response
{
    $request->getSession()->set('my_plugin_seen', true);

    return $this->renderStorefront('@MyPlugin/storefront/page/promo.html.twig', [
        'customerName' => $context->getCustomer()?->getFirstName(),
    ]);
}
```

```php
// Preferred: keep the page cacheable and move personalization behind a separate endpoint
#[Route(path: '/promo', name: 'frontend.my-plugin.promo', methods: ['GET'], defaults: ['_httpCache' => true])]
public function promo(): Response
{
    return $this->renderStorefront('@MyPlugin/storefront/page/promo.html.twig');
}

#[Route(path: '/widgets/promo/customer-badge', name: 'frontend.my-plugin.promo.customer-badge', methods: ['GET'], defaults: ['_noStore' => true])]
public function customerBadge(SalesChannelContext $context): JsonResponse
{
    return new JsonResponse([
        'firstName' => $context->getCustomer()?->getFirstName(),
    ]);
}
```

## Performance, Cache, and Async

- Treat cart, checkout, login, account, and high-volume queries as hot paths.
- Do not block request paths on external I/O unless absolutely required.
- Push expensive derived data or sync work into Messenger, indexers, or scheduled tasks.
- Separate low-priority or bulk background work from checkout-sensitive consumers when queue backlog could affect customer-facing flows.
- Plan for reverse proxy, CDN, and Varnish-style caching behavior.
- Avoid cache-key explosions from extra cookies, headers, or highly dynamic fragments.
- Do not assume "logged-in users disable HTTP cache" as a permanent invariant.
- If user-specific data is required, make it explicit with AJAX, ESI fragments, or non-cacheable routes rather than globally disabling cache.
- Before increasing cache variation or invalidation frequency, estimate the hit-rate impact and state the least destructive alternative.
- Do not perform DAL writes, entity updates, or expensive recalculations inside storefront read routes or generic render events just to decorate response data. Use runtime extensions, response extensions, or cacheable precomputation.
- Avoid `order.written` or state-transition subscribers that write the same entity again or call external systems synchronously. That pattern creates recursion, duplicate processing, and checkout latency.
- Normalize cache keys and derive quote TTLs from provider validity and business freshness. Separate read-only quotes from payment/booking side effects and transient failures; see [provider cache policy](24-external-api-caching-in-cart.md).

## Messenger and Handler Patterns

Read [Messenger handlers](messenger-handlers.md) when implementing queues: transport routing, concurrent/durable idempotency, provider retry seams, the `DelayStamp` portability guard, scheduled-task constructors, message size, and `WEBHOOKS_REWORK`.

## External Integrations

- Centralize HTTP clients.
- Set explicit timeouts.
- Prefer retries only for safe, idempotent operations.
- Add circuit-breaker or fallback logic when the dependency can degrade the shop.
- Queue non-interactive sync work.
- Never disable TLS verification in production clients.
- Do not build callback or return URLs from `HTTP_HOST` or other untrusted request host headers. Use configured sales-channel domains or explicit trusted configuration.

If the integration is a payment provider, stop here and load `07-payments.md`.

## 6.7 Core Changes That Affect Backend Code

### Migrations And Schema

- **FK naming changed** in the migration generator / `SchemaBuilder` from `fk.<table>.<column>` to `fk__<table>__<column>` (double underscore). This applies to **newly generated** constraints; constraints already present in a migrated database keep their old names. Audit both spellings when a migration drops or renames a foreign key by string. Source: release notes 6.7.8.
- **Translation-table references** now use `ON DELETE CASCADE` in new migrations.
- **Use `\Shopware\Core\Framework\Util\Database\TableHelper`** for schema introspection. `EntityDefinitionQueryHelper::columnExists()` and `tableExists()` are deprecated in favour of it. `columnIsNullable()` is deprecated as unused and has **no** `TableHelper` replacement.
- **`MigrationStep` named-parameter renames** — the table parameter is still `$table`, do not rename it:
  - `dropColumnIfExists`: `column` → `columnName`
  - `dropForeignKeyIfExists`: `column` → `foreignKeyName`
  - `dropIndexIfExists`: `index` → `indexName`

### `EntityDefinition::__construct` Deprecated

Calling `parent::__construct()` from an `EntityDefinition` subclass is deprecated for the next major. Do not emit `parent::__construct()` in generated entity definitions.

Source: UPGRADE-6.7.md §6.7.2.0.

### Custom Field Naming

Custom field names may no longer contain hyphens or dots — they are used directly as Twig variable names. Use `snake_case`.

### `ScheduledTaskHandler` Requires `LoggerInterface`

See [scheduled-task compatibility](messenger-handlers.md#scheduled-task-and-message-size-compatibility), including custom subclass constructor and DI changes.

### Messenger Message Size Limit

The opt-in defaults and source are in [Messenger handlers](messenger-handlers.md#scheduled-task-and-message-size-compatibility).

### Webhook Messenger Transport (`WEBHOOKS_REWORK`)

See [webhook transport](messenger-handlers.md#webhook-messenger-transport-webhooks_rework) before changing consumers or rolling the flag back.

### `NavigationRoute` Cache Key Event

Default navigation category levels are cached by root, depth, sales channel, and language. If a plugin changes the cached loader output using another context input, extend `\Shopware\Core\Content\Category\Event\CategoryLevelLoaderCacheKeyEvent` or disable that cache for the affected flow. A missing key part matters only when output actually differs for otherwise identical keys.

Note the namespace: `Category\Event\`, not `Category\SalesChannel\`. A wrong FQCN can register without firing (`::class` alone does not check existence). Demonstrate the missing required key extension and shared-output failure before reporting impact.

Source: [CachedDefaultCategoryLevelLoader::getCacheKey](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Content/Category/Service/CachedDefaultCategoryLevelLoader.php) and UPGRADE-6.7.md §6.7.2.0, §6.7.3.0.

### Sync API Foreign-Key Resolvers

From 6.7.11 the Sync API accepts human-readable keys instead of UUIDs:

- `currency.iso_code`
- `locale.code`
- `payment_method.technical_name`
- `shipping_method.technical_name`
- `document_type.technical_name`
- `salutation.salutation_key`
- `tax.tax_rate`

Prefer these over UUID lookups in import/sync code.

Source: release notes 6.7.11.

### State Machine Per-Entity Locking

From 6.7.11 `StateMachineRegistry::transition()` acquires per-entity locks to protect the transition/history write. Reuse that protection rather than duplicating its lock. It does not make an adjacent provider call or the whole handler idempotent; those need their own business-operation guard.

Source: release notes 6.7.11.

### Store-API `limit` Cap

`shopware.api.store.max_limit` (default 100) caps the `limit` parameter on `/store-api/product-listing/{categoryId}`, `/store-api/search`, and `/store-api/search-suggest`. Fetch in pages; do not request unbounded limits.

From 6.7.13 Store-API requests no longer start PHP sessions unless code explicitly does. Do not rely on side effects that depended on session start (e.g., cart token in `$_SESSION`).

Source: UPGRADE-6.7.md §6.7.3.0, release notes 6.7.13.

### `ResetInterface` For Long-Running Runtimes

For FrankenPHP / RoadRunner runtime compat, any custom service holding request-scoped state (per-request caches, current context) must implement `Symfony\Contracts\Service\ResetInterface::reset()` to clear it between requests.

Source: release notes 6.7.2.

### Product `states` → `type` Model

`product.states`, `order_line_item.states`, `LineItem::$states`, `StatesUpdater`, `ProductStatesBeforeChangeEvent`, and `ProductStatesChangedEvent` are deprecated in 6.7.7 in favor of `product.type` and `order_line_item.payload.product_type` / `LineItem::$payload['productType']`. Register custom types via `shopware.product.allowed_types` config.

Source: release notes 6.7.7.

### Sales Channel Repository Default

Use sales-channel repositories for storefront visibility, availability, and context-sensitive prices. Admin, migration, and background operational reads may need the ordinary entity repository instead; pass explicit scope and filters. The number of sales channels alone does not choose the repository.

### Hard Limits On Data Fetches

Bound open-ended discovery with stable pagination/keyset iteration and consume every batch. For `new Criteria($ids)`, the validated ID set already bounds the read; an unrelated `setLimit(50)` can truncate it. Chunk very large ID sets for parameter/memory limits without dropping IDs. Limits for interactive lists are appropriate when the API exposes pagination.

### Write Events Carry Only The Written Fields

`EntityWriteResult::getPayload()` is built from the write command, so it holds only the fields that were part of that write, plus the primary key. The admin saves only changed fields. A subscriber that reads a foreign key or flag from the payload (`productId`, `active`) sees it on the first insert and almost never again, so later updates, toggles, and edits are silently ignored.

- Load the missing fields by ID instead of expecting them in the payload.
- To see old and new values, request a change set: in a `PreWriteValidationEvent` listener, call `requestChangeSet()` on the relevant `ChangeSetAware` commands, then read `EntityWriteResult::getChangeSet()`.
- **Deletes never fire `<entity>.written`.** They dispatch `EntityDeletedEvent` named `<entity>.deleted`. Recalculations, cache invalidation, and aggregates that only listen to `.written` drift after a delete.

```php
// Bad: only the first save carries productId; toggling `active` later never invalidates
public function onWritten(EntityWrittenEvent $event): void
{
    foreach ($event->getPayloads() as $payload) {
        if (isset($payload['productId'])) {
            $this->invalidate($payload['productId']);
        }
    }
}

// Preferred: resolve the owner from the written IDs and also listen to my_entity.deleted
public static function getSubscribedEvents(): array
{
    return [
        'my_entity.written' => 'onChanged',
        'my_entity.deleted' => 'onChanged',
    ];
}
```

For deletes, read the owner ID before the row is gone: listen to `EntityDeleteEvent` (dispatched before the delete), load what you need, and register follow-up work with `$event->addSuccess(…)`. Afterwards the row can't be loaded.

### Custom Translations Need A System-Language Row

Translated fields are read from a subquery that starts **from the system-language translation row** and joins the other languages in the chain onto it (`TranslationFieldResolver::getTranslationQuery()`, "use the system language to enforce we have a record"). If an entity has a translation only in French and none in the system language, the French value is never returned, even in a French context.

- When a custom translatable entity can be created in a non-system language, also write an (empty) system-language translation row.
- Data imported only in a shop language, without the system-language row, reads as empty.

### `EntitySearchResult` Collection Methods Are Deprecated For 6.8

Recent 6.7 releases (present by 6.7.14) deprecate almost every collection method on `EntitySearchResult` for 6.8: `getElements()`, `first()`, `last()`, `get()`, `count()`, `isEmpty()`, `has()`, `getIds()`, `map()`, `filter()`, `slice()`, `sortByIdArray()`, and `getIterator()`, so a plain `foreach` over the result too. The result wrapper becomes immutable.

```php
// Bad: deprecated in 6.7, removed in 6.8
foreach ($repository->search($criteria, $context) as $entity) { /* ... */ }
$first = $repository->search($criteria, $context)->first();

// Preferred
$entities = $repository->search($criteria, $context)->getEntities();
foreach ($entities as $entity) { /* ... */ }
$first = $entities->first();
```

Fix the whole call site, not only the method the first deprecation notice names; the next line usually triggers the next notice.

### Doctrine DBAL 4

6.7 ships Doctrine DBAL 4 (6.6 used DBAL 3). DBAL 4 removed `Connection::PARAM_STR_ARRAY` and `Connection::PARAM_INT_ARRAY`. Use the `ArrayParameterType` enum:

```php
use Doctrine\DBAL\ArrayParameterType;

$connection->fetchAllAssociative(
    'SELECT id FROM product WHERE id IN (:ids)',
    ['ids' => Uuid::fromHexToBytesList($ids)],
    ['ids' => ArrayParameterType::BINARY],
);
```

Also check custom `Type` classes, `fetchAll*` signatures, and any code that relied on implicit DBAL 3 behaviour when upgrading.

### No Dynamic Properties On Structs

Shopware supports PHP 8.2+, where creating a property that isn't declared is deprecated. `Struct` does not opt in with `#[AllowDynamicProperties]`. Declare the property on your own struct, or attach data to core structs and entities with `addExtension()` / `addArrayExtension()` instead of `$entity->myValue = …`.

## Cross-References

- Cache and HTTP cache details: `23-cache-and-http-cache.md`.
- Cart, checkout, delivery, promotion pipeline: `18-cart-and-checkout-pipeline.md`.
- External API caching in cart (tax, shipping providers): `24-external-api-caching-in-cart.md`.
- Testing patterns: `19-testing-patterns.md`.
- Patching, PHPStan, Frosh Tools: `25-patching-and-dependency-tooling.md`.

## Source Anchors

Behavior above is checked against 6.7.15.1; resolve installed package versions and inspect the matching patch before applying it to 6.6 or an earlier 6.7:

- [RepositoryIterator::fetchIds](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/DataAbstractionLayer/Dbal/Common/RepositoryIterator.php) and [Criteria](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/DataAbstractionLayer/Search/Criteria.php).
- [PluginLifecycleService::runMigrations](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Plugin/PluginLifecycleService.php) and [MigrationDestructiveCommand::collectMigrations](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Migration/Command/MigrationDestructiveCommand.php).
- [API authentication opt-out](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Api/EventListener/Authentication/ApiAuthenticationListener.php) (`auth_required`); opting out supplies no provider authentication by itself.
- [StateMachineRegistry::transition](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/System/StateMachine/StateMachineRegistry.php).
- [6.7 upgrade guide](https://github.com/shopware/shopware/blob/v6.7.15.1/UPGRADE-6.7.md) for the minor-version changes listed here; [cache source anchors](23-cache-and-http-cache.md#source-anchors) for route/key behavior.
