# Source Analysis

How to analyze a source class to decide whether an integration test is appropriate and which integration pattern fits.

## Decision Test — before applying any pattern

> **"Does the SUT's contract require wired-up code (real DAL, real container, real HTTP/messaging, real multi-service coordination) to make the assertion meaningful?"**

- Yes → continue to pattern detection below.
- No → return SKIPPED with `skip_type: unit_test_more_appropriate`. The SUT is unit-shape; `phpunit-unit-test-generation` produces a higher-signal test.

The integration test generator is conservative on purpose: a misplaced integration test will be flagged by `phpunit-integration-to-unit-migrating` and bucketed for migration. Better to defer to the unit generator than to ship a placement-violating test.

## Pattern Detection

Evaluate top to bottom. The first match wins.

### Pattern 1 — `controller`

| Indicator | How to detect |
|---|---|
| Class extends `Symfony\Bundle\FrameworkBundle\Controller\AbstractController` | Read `extends` clause |
| Class extends an `Abstract*Route` (`AbstractRoute`, `AbstractCartLoadRoute`, etc.) | Read `extends` clause; match name suffix `Route` |
| Class has methods with `#[Route(...)]` attribute | Scan method attributes |
| Class is in a `SalesChannel/`, `Storefront/Controller/`, or `Api/Controller/` namespace and constructor takes request-stack-or-router types | Check namespace path + constructor dependencies |

**Test shape**: `IntegrationTestBehaviour` + the appropriate request-test trait (`SalesChannelApiTestBehaviour`, `AdminApiTestBehaviour`, or `StorefrontControllerTestBehaviour`). Add `MailTemplateTestBehaviour` when the route dispatches mail. Compose an `IdsCollection`. Build a browser via `$this->createCustomSalesChannelBrowser([...])` (sales-channel) or the admin/storefront equivalent. Request through `$browser->request(...)`. Assert on response status, decoded body, and persisted side effects via DAL.

### Pattern 2 — `scheduled-task`

A `ScheduledTaskHandler` invoked directly via its `run()` method.

| Indicator | How to detect |
|---|---|
| Class extends `Shopware\Core\Framework\MessageQueue\ScheduledTask\ScheduledTaskHandler` | Read `extends` clause |
| Class has `#[AsMessageHandler]` attribute AND its `__invoke()` parameter type is a `ScheduledTask` subclass | Scan class + method attributes |

**Test shape**: `DatabaseTransactionBehaviour + KernelTestBehaviour` (NOT full `IntegrationTestBehaviour` — scheduled tasks rarely need fixture loaders / sales-channel context). Call `parent::setUp()`. Fetch the handler from the container, invoke `$handler->run()` directly, then assert via raw SQL `Connection::fetchOne(...)` or DAL search.

### Pattern 3 — `message-handler`

A non-scheduled message handler. Only generate this pattern when the test must traverse the real bus (e.g., asserting middleware behavior, transport routing). If the test only needs to verify the handler's logic, defer to unit test generation.

| Indicator | How to detect |
|---|---|
| Class has `#[AsMessageHandler]` attribute on `__invoke()` | Scan attribute |
| `__invoke()` parameter is a domain message class (not a `ScheduledTask`) | Read parameter type |
| Source class lives in a `MessageQueue/`, `MessageHandler/`, or `*Handler/` directory and is registered with the `messenger.message_handler` tag | Check namespace + module DI config |

**Test shape**: `IntegrationTestBehaviour`. Either invoke `$handler($message)` directly (most cases) or dispatch via `static::getContainer()->get('messenger.bus.shopware')` only when transport/routing is part of the SUT contract.

### Pattern 4 — `indexer`

| Indicator | How to detect |
|---|---|
| Class extends `Shopware\Core\Framework\DataAbstractionLayer\Indexing\EntityIndexer` | Read `extends` clause |
| Class implements `iterate()` and `update(EntityWrittenContainerEvent $event): ?EntityIndexingMessage` | Scan method signatures |

**Test shape**: `DatabaseTransactionBehaviour + KernelTestBehaviour` (lighter than `IntegrationTestBehaviour`). Fetch the indexer + relevant repositories from the container. Test pattern: write entities via DAL, capture the `$event` returned by `$repository->update([...], $context)`, call `$indexer->update($event)`, assert on the returned `EntityIndexingMessage`'s data (typically the list of IDs queued for indexing).

The backfill flow (`$indexer->iterate(...)` → `$indexer->handle(...)`) exists but is less common; reserve it for tests that specifically cover full reindex behavior, not realtime indexing.

### Pattern 5 — `dal-flow`

A service whose contract is "data persists" / "indexer was triggered" / "the event reached its subscribers". The integration apparatus is load-bearing for the assertion.

| Indicator | How to detect |
|---|---|
| Constructor takes one or more `EntityRepository` dependencies | Scan constructor parameter types |
| Public method calls `->create(`, `->update(`, `->upsert(`, `->delete(` on a repository | Read method bodies |
| Public method emits an event whose subscribers persist additional state | Look for `EventDispatcherInterface::dispatch(` and check the event class for subscribers |
| Public method's externally observable result requires reading data back via DAL | Inspect the SUT contract: does the assertion live in the DB? |

**Test shape**: `IntegrationTestBehaviour`. Arrange via DAL (`$repository->create([...], $context)` or a behaviour-trait fixture loader like `MediaFixtures`), invoke SUT, assert through a separate DAL read (`$repository->search(new Criteria([$id]), $context)->first()`).

> [!IMPORTANT]
> A repository dependency alone is not enough. If the SUT only *reads* through DAL to materialize an entity it then computes on (no persistence assertion), the test is a DAL materializer per `phpunit-integration-to-unit-migrating/references/refactoring-patterns.md` Pattern 6 and should be a unit test. The flow that justifies integration is: write → observable persisted result.

### Pattern 6 — `multi-service`

A coordinator that drives ≥ 2 stateful collaborators end-to-end (DAL + indexer, DAL + event bus, DAL + cache, SystemConfig + DAL + dispatcher).

| Indicator | How to detect |
|---|---|
| Constructor takes ≥ 3 dependencies | Count constructor parameters |
| At least 2 dependencies are stateful (not boundary): `EntityRepository`, `EntityIndexerRegistry`, `EventDispatcherInterface`, `SystemConfigService`, `CacheItemPoolInterface`, `Connection` | Cross-reference dependency FQCNs with the boundary list in `INTEGRATION-002` |
| Public method's assertion only emerges from interaction between ≥ 2 of those collaborators | Inspect the SUT contract |

**Test shape**: `IntegrationTestBehaviour` composed with any domain-specific behaviour traits the SUT requires (`AppSystemTestBehaviour`, `MailTemplateTestBehaviour`, `GuzzleTestClientBehaviour` for HTTP boundary mocking). Configure inputs via the real services, invoke SUT, assert cross-collaborator effects.

## Negative cases — when to defer to unit test generation

If the source class matches any pattern below, return SKIPPED with `skip_type: unit_test_more_appropriate` and quote the relevant refactoring pattern. These are exactly the patterns the migration skill moves *out of* integration; generating them as integration tests would be churn.

| Negative pattern | Where it belongs | Refactoring pattern reference |
|---|---|---|
| Container-fetched factory or stateless service whose collaborators are constructable | unit | Pattern 1 |
| Symfony compiler pass (operates on `Definition`s) | unit | Pattern 2 |
| Single event subscriber, handler invoked directly with a constructed event | unit | Pattern 3 |
| XML / JSON parser reading fixture files | unit (with `__DIR__`-relative fixtures) | Pattern 4 |
| Constraint-only `Rule` validation via `Validation::createValidatorBuilder()` | unit | Pattern 5 |
| DAL materializer: reads through DAL only to call a pure method on the result | unit (construct the entity in-memory) | Pattern 6 |

## Trait selection

Based on the detected pattern. The choice between `IntegrationTestBehaviour` and the lighter `DatabaseTransactionBehaviour + KernelTestBehaviour` pair matters: `IntegrationTestBehaviour` composes the lighter pair plus fixture-loader machinery and sales-channel helpers. Use it only when those helpers are needed.

| Pattern | Required traits | Optional add-ons |
|---|---|---|
| `controller` (SalesChannel) | `IntegrationTestBehaviour`, `SalesChannelApiTestBehaviour` | `MailTemplateTestBehaviour` (when the route dispatches mail) |
| `controller` (Admin) | `IntegrationTestBehaviour`, `AdminApiTestBehaviour` | — |
| `controller` (Storefront) | `IntegrationTestBehaviour`, `StorefrontControllerTestBehaviour` | — |
| `scheduled-task` | `DatabaseTransactionBehaviour`, `KernelTestBehaviour` | — |
| `message-handler` | `IntegrationTestBehaviour` | `QueueTestBehaviour` when asserting queue state |
| `indexer` | `DatabaseTransactionBehaviour`, `KernelTestBehaviour` | — |
| `dal-flow` | `IntegrationTestBehaviour` | Domain fixture traits (`MediaFixtures`, `BasicTestDataBehaviour`) when fixtures are needed |
| `multi-service` | `IntegrationTestBehaviour` | Domain behaviours per dependency (`AppSystemTestBehaviour`, `GuzzleTestClientBehaviour`, `MailTemplateTestBehaviour`) |

When using `DatabaseTransactionBehaviour + KernelTestBehaviour`, the test must call `parent::setUp()` explicitly so the transaction wrapper kicks in.

## ID management convention

Use `Shopware\Core\Test\Stub\Framework\IdsCollection` for any test that creates more than one entity or needs to refer to created IDs across arrange/act/assert. The collection produces deterministic UUIDs from human-readable keys (`$this->ids->create('landing-page')`, then `$this->ids->get('landing-page')`), which satisfies INTEGRATION-004's determinism requirement without sacrificing readability.

Use raw `Uuid::randomHex()` only for one-off IDs whose value the test does not assert on.

## Repository PHPDoc typing convention

When fetching an entity repository from the container, type the property both for IDE autocompletion and for PHPStan's `->search(...)->first()` chain:

```php
/**
 * @var EntityRepository<MediaCollection>
 */
private EntityRepository $mediaRepository;
```

Without the generic, PHPStan reports `->first()` as `Entity|null` instead of the specific entity type, forcing `assertInstanceOf` boilerplate the codebase otherwise avoids.

## Boundary collaborators (mockable per INTEGRATION-002)

The following are boundary types whose mocks the rule allows. Anything else that appears in the SUT's constructor must be retrieved from the container.

- `Symfony\Contracts\HttpClient\HttpClientInterface`, Guzzle client, curl wrappers — but in App/HTTP tests, prefer `GuzzleTestClientBehaviour::appendNewResponse(...)` over raw mocks
- `Symfony\Component\Mailer\MailerInterface` and Shopware mail dispatch interfaces — but `MailTemplateTestBehaviour` is the idiomatic alternative when mail is involved
- `Psr\Clock\ClockInterface` and Shopware clock abstractions
- Randomness sources (`Random\Randomizer`, custom RNG interfaces)
- Third-party SDKs the project does not own

When in doubt, prefer the real service from the container or the appropriate behaviour trait.
