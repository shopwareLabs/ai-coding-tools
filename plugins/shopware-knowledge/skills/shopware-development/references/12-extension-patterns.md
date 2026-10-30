# Extension Patterns

Index: config, Flow Builder, CMS, import/export, media, rules, line items, mail, product/catalog choices.

## Plugin Configuration

- Use `config.xml` and a typed configuration wrapper for merchant-facing settings.
- Read configuration with sales-channel awareness when the behavior can vary by channel.
- Validate and normalize config values before use; do not pipe raw config values directly into clients.
- Keep shop-specific secrets in Shopware configuration, not hardcoded constants or generic environment variables meant for one global value.
- API URL, timeout, debug mode, and feature flags belong in plugin configuration with a typed service, not in `private const` values scattered across services.
- When writing custom fields programmatically, merge with the existing custom field array instead of replacing unrelated keys.

## Flow Builder

- Dispatch explicit business events or Flow Builder-compatible events for meaningful domain actions instead of hardcoding follow-up emails, tags, or webhooks.
- Use Flow Builder-compatible events when merchants should be able to react without code changes.
- Implement custom flow actions when the plugin exposes a domain operation merchants should be able to call from Flow Builder.
- Put the business decision in the service, then emit the event once state is committed.
- When a subscription or approval state changes, dispatch one event and let Flow Builder or other subscribers handle mail, tagging, and webhook actions.

## CMS Elements and Blocks

Deep reference: `27-cms-elements-and-blocks.md` (slot config storage, override merge, inheritance wrappers, previews, page types, resolvers, rule-based visibility).

- Split CMS work into admin registration, storefront template, data resolver, and data struct responsibilities.
- Load data in the resolver and attach a struct to the slot; do not query inside Twig.
- Keep configuration-driven ordering and defaults explicit.
- A custom product slider should collect product IDs in `collect()`, enrich the slot in `enrich()`, and render a prepared struct in Twig.
- Preserve the normal parent admin save pipeline by default. Ask only about unresolved high-impact persistence/UX choices not already authorized by the user; do not turn routine extension-point selection into a mandatory pause.

## Import and Export

- Prefer Shopware import/export profiles, field mappings, and serializers over raw CSV loops.
- Chunk large imports and track progress or logs for resumability.
- Keep mapping rules explicit for nested fields, translations, media, and custom fields.
- Add custom serializers or converters when external data formats need normalization instead of baking conversion logic into controllers or commands.
- A product sync profile should map `price.DEFAULT.gross`, tax, media, and custom fields instead of manually parsing rows into repository writes.

## Media Handling

- Use Shopware media services, file savers, folders, and associations rather than writing directly into public media paths.
- Validate remote sources before downloading them and treat URL-based imports as SSRF-sensitive.
- Keep folder configuration and thumbnail behavior explicit.
- Upload a remote image through `MediaService` or `FileSaver`, create the media entity first, then associate the media ID to products or CMS content.
- Clean up temporary files after uploads, imports, and remote downloads.

## Rule Builder Conditions

- Use custom rules when pricing, shipping, promotions, or content need merchant-configurable conditions.
- Match the correct scope and expose configuration via `RuleConfig`.
- Keep payload lookups and custom-field reads deterministic.
- A customer-tier rule or product custom-field rule should use typed operators and scopes instead of scattering conditional checks across checkout services.

## Custom Line Item Types

- Use a dedicated line item type for plugin-specific discounts, credits, fees, or bundle markers.
- Do not identify your business logic by translated labels or by reusing a generic line item type such as `credit`.
- Store credit should be a dedicated `store_credit` line item with explicit payload or extensions, not a generic credit item guessed by label text like "Store credit discount".

## Mail and Notification Patterns

- Keep transactional email ownership explicit. Do not hardcode mail sends across random subscribers when Flow Builder, business events, or one orchestration service should own the decision.
- Customize mail templates and payloads through stable extension points, not copy-pasted mail-rendering logic in controllers.
- Do not block hot paths on email delivery when the business flow can durably queue or defer the send.

Example pattern:

```text
Bad: send mail directly from every state-transition subscriber that notices the same order change.
Good: dispatch one business event after the state is committed and let Flow Builder or one mail orchestration path send the notification.
```

## Product and Catalog Extension Choices

- Use custom fields for light editorial product metadata.
- Use entity extensions when the product needs structured extra fields but the lifecycle still belongs to the product.
- Use custom entities when the domain needs its own lifecycle, synchronization, batching, or indexes.
- Keep variant, property, stream, and cross-selling logic aligned with existing Shopware catalog models before inventing plugin-side shortcuts.
- When those models remain genuinely unresolved and materially change persistence, UX, or scale, ask before choosing; retain an already authorized model and normal parent save semantics. Multiple technically possible models alone are not a reason to stop.

Example pattern:

```text
Bad: store variant-generation rules and stream membership as unindexed product customFields and query them at scale.
Good: use Shopware property groups, product streams, or a dedicated custom entity when the data drives operational catalog behavior.
```

## 6.7 Extension Pattern Changes

### Custom Fields In XML (Not Manifest Inline)

From 6.7.13, inline `<custom-fields>` in `manifest.xml` is deprecated. Move to `Resources/config/custom-fields.xml`.

The file is XSD-validated at install/update, so a malformed one throws rather than degrading quietly. On a field, `name` is a required **attribute**. The custom-field **set** requires `name`, `label`, `related-entities`, and `fields` elements; do not put `related-entities` inside an individual field.

```xml
<!-- src/Resources/config/custom-fields.xml -->
<custom-fields>
    <custom-field-set>
        <name>my_plugin_products</name>
        <label>My Plugin Product Fields</label>
        <related-entities>
            <product/>
        </related-entities>
        <fields>
            <text name="my_plugin_sku_supplier">
                <label>Supplier SKU</label>
                <include-in-search>true</include-in-search>
            </text>
        </fields>
    </custom-field-set>
</custom-fields>
```

`includeInSearch` has always defaulted to `false`. 6.7.13 did not change that default — it added a way to declare it in XML rather than only through the Admin UI or Admin API. Existing extensions are unaffected.

From **6.7.7** the `Immutable` DAL flag protects `custom_field.name`, `custom_field.type`, and `custom_field_set.name`. Do not attempt to update fields marked immutable.

Source: `System/CustomField/Schema/custom-fields-1.0.xsd`; `CustomFieldSet::REQUIRED_FIELDS`; release notes 6.7.7 (Immutable) and 6.7.13 (declarative XML).

### Cookie Provider Replaced By Event

On 6.7.3+, `CookieProviderInterface` is deprecated. Register cookies via listener on `\Shopware\Core\Content\Cookie\Event\CookieGroupCollectEvent` using `CookieEntry` / `CookieGroup` structs. The Store-API route is `/store-api/cookie-groups` (`\Shopware\Core\Content\Cookie\SalesChannel\CookieRoute`). For a 6.6 target, verify that exact release's provider API rather than copying this event unconditionally.

```php
<?php declare(strict_types=1);

namespace MyPlugin\Subscriber;

use Shopware\Core\Content\Cookie\Event\CookieGroupCollectEvent;
use Shopware\Core\Content\Cookie\Struct\CookieEntry;
use Shopware\Core\Content\Cookie\Struct\CookieEntryCollection;
use Shopware\Core\Content\Cookie\Struct\CookieGroup;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;

final class WidgetCookieSubscriber implements EventSubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return [CookieGroupCollectEvent::class => 'collect'];
    }

    public function collect(CookieGroupCollectEvent $event): void
    {
        $entry = new CookieEntry('my-plugin-widget');
        $entry->name = 'my-plugin.widgetCookie';
        $entry->description = 'my-plugin.widgetCookieDescription';
        $entry->value = '1';
        $entry->expiration = 30; // example policy in days, not a legal requirement

        $group = new CookieGroup('my-plugin.optionalWidgets');
        $group->setEntries(new CookieEntryCollection([$entry]));
        $event->cookieGroupCollection->add($group);
    }
}
```

Register the subscriber as a service with autoconfiguration or the `kernel.event_subscriber` tag and supply the named snippets. `isRequired` defaults to `false`; do not mark an optional widget required. A group may contain entries **or** be a standalone cookie, not both. This declares consent metadata; it must not load the provider or set its consent marker itself. The initial/grant/revoke/cleanup JS lifecycle is owned by `05-storefront-and-themes.md`, "Storefront JS".

Twig properties `snippet_name` / `snippet_description` deprecated → `name` / `description` (handle both snippet keys and plain strings).

Source: [v6.7.15.1 CookieGroupCollectEvent](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Content/Cookie/Event/CookieGroupCollectEvent.php), [CookieEntry](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Content/Cookie/Struct/CookieEntry.php), [CookieGroup](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Content/Cookie/Struct/CookieGroup.php); UPGRADE-6.7.md §6.7.3.0.

### Rule Builder Condition Contract

- `LineItemProductStatesRule` deprecated → `LineItemProductTypeRule`. Register custom types via `shopware.product.allowed_types` config.
- `LineItemPurchasePriceRule` `bool $isNet` → `?string $type` (`'gross'|'net'`, auto-migrated).
- `LineItemCustomFieldRule` now throws `RuleException::unsupportedOperator()` (not `CartException`).
- `CustomerBirthdayRule` no longer throws on null.
- Deprecated admin components: `sw-condition-line-item-in-category`, `sw-condition-line-item-purchase-price`, `sw-condition-is-net-select`. Use `sw-condition-generic`.

Source: UPGRADE-6.7.md §6.7.7.0, §6.7.12.0, §6.7.13.0.
