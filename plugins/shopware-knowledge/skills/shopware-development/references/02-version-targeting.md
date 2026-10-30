# Version Targeting

Index: default rule, detection order, 6.7 deltas, PHP/Symfony/Redis versions, 6.6 compatibility, backport policy, migration playbook, replacement strategy, anchors.

## Default Rule

Default to Shopware 6.7 guidance. Switch to explicit 6.6 compatibility mode when:

- the root project or plugin constraints cap Shopware at `6.6.*`
- the user says the work must remain 6.6-compatible
- the repo contains transition-era admin or payment code that should not be silently migrated

## Detection Order

Check in this order:

1. Root `composer.json`
2. Plugin/theme/app `composer.json`
3. Installed package metadata or `composer show` output when available
4. Focused `composer.lock` search for specific package entries only when exact installed versions matter
5. Existing code patterns that imply a versioned extension surface

State the version assumption before changing behavior. Do not read the full lock file by default; it is too large for routine version detection.

## 6.7-First Deltas

Use these as default assumptions for 6.7 work:

- Payments
  Use `AbstractPaymentHandler`. Order placement invokes validation; after-order payment handling can reach `pay()` without that validation step. Enforce payment-time authority in `pay()` too. Follow the redirect/finalize path in the matching processor, not a blanket assumption that every entry point calls every hook.
- Administration
  Use the official Vue 3, Pinia, and Vite migration docs when the task includes admin modernization. Treat these as explicit migrations, not incidental cleanup.
- Translations
  Shopware 6.7.3 introduced the country-independent snippet base layer. Use base files such as `messages.en.base.json` and `messages.de.base.json`, keep country-specific files as small overrides, preserve empty former country-specific files where backward compatibility needs them, and validate with `bin/console translation:lint-filenames` plus `bin/console translation:validate`.
- Caching
  Follow the current cache and HTTP cache docs. Do not depend on legacy assumptions like "logged-in users always disable cache." Delayed cache invalidation is on by default in 6.7 with 5-minute batching. The `CACHE_REWORK` feature flag is a **separate, opt-in, experimental** change (`default: false` through 6.7.13) that becomes the default in 6.8 — do not assume Store-API HTTP caching or rule-filtered `sw-cache-hash` are live. See `23-cache-and-http-cache.md`.

## Runtime Version Matrix (6.7 series)

- PHP: **8.2 is the floor**. `shopware/core` declares `~8.2.0 || ~8.3.0 || ~8.4.0 || ~8.5.0` through 6.7.13; 8.5 support was added in 6.7.6. Because 8.2 is the minimum, target 8.2-compatible syntax unless the project pins higher.
- Symfony: 7.3 baseline from 6.7.2, upgraded to 7.4 from 6.7.7.
- Redis: `php-redis` v6.1+ required from 6.7.7. Redis 7.0+ recommended for cluster/multi-node.
- MySQL/MariaDB: unchanged; `group_concat_max_len >= 320000`, no `ONLY_FULL_GROUP_BY`.

Source: release notes 6.7.2, 6.7.6, 6.7.7.

## Translation Migration Preparation

For a 6.7 project migrating from the Language Pack to core translation management, verify installed patch and plugin compatibility before running:

```bash
bin/console translation:install --locales it-IT,fr-FR
```

- Activate every needed language under Settings → Languages before install; inactive languages are ignored.
- Repoint sales-channel domains from `LanguagePack en-US` snippet sets to `BASE en-US`; Language Pack ≥5.37.1 does this automatically.
- If FK constraint errors appear during removal, upgrade to Shopware ≥6.7.7.0 and Language Pack ≥5.37.1 first.

Source: developer.shopware.com/docs/guides/upgrades-migrations/language-pack-migration.html.

## 6.6 Compatibility Rules

When the project targets 6.6:

- Open the archived docs under `/docs/v6.6/` before relying on a 6.7-only pattern.
- Keep admin migrations explicit. Do not force Pinia or Vite unless the project is already migrating.
- Treat 6.7 translation-layer improvements as optional, not assumed.
- Re-check payment handler contracts and extension points against 6.6 docs before applying 6.7 examples.

## Backport Policy

Not every Shopware fix is backported to older minors.

- Example: `shopware/shopware` PR #18205 ("perf: Improve category breadcrumb updater") first ships in 6.7.13.0 with no 6.6 backport. Check the PR's own target branches on GitHub rather than assuming a fix reached the older minor.
- Before assuming a fix exists on 6.6, check the PR's target branches on GitHub.
- If the fix must exist on 6.6, evaluate an upstream-supported upgrade or a narrowly scoped reproducible patch using the project's patch tooling. See `25-patching-and-dependency-tooling.md`.
- Document each patch with the upstream URL and the target version where it can be removed.

## Compatibility Strategy

Use the least risky path:

- If behavior can stay version-neutral, do that.
- If the implementation must differ, isolate the version-sensitive seam in one service or adapter.
- If the task would require a wide migration, stop and name it as a separate chunk rather than mixing it into a feature change.

## Migration Playbook

When the task is an upgrade, scan first and migrate second.

Check these surfaces explicitly:

- payment handlers, prepared-payment validation, and redirect/finalize flow
- admin build stack and state management assumptions
- copied Twig templates or old storefront JS hooks
- snippet filename conventions and fallback behavior
- service decoration against fragile or deprecated core services
- tests that depend on older bootstrap or admin assumptions

Concrete scan examples:

Example patterns:

```text
Bad: "While touching this admin module, also migrate it from Vuex to Pinia."
Good: Keep the feature fix version-neutral unless the task is explicitly the admin migration.
```

```text
Bad: On 6.7.3+, keep duplicating every language file as messages.en-GB.json and messages.de-DE.json without base files.
Good: Move shared translations into messages.en.base.json or messages.de.base.json and keep country-specific files only as overrides where needed.
```

```text
Bad: Reuse a 6.7 payment example in a 6.6 plugin without re-checking the archived payment guide.
Good: Verify the exact 6.6 payment-handler contract first, then isolate any version-sensitive seam in one service or adapter.
```

### Upgrade Traps That Fail Silently

- **Overrides of removed Twig blocks do nothing.** With `sw_extends`, a `{% block %}` that no longer exists in the parent template is never rendered, and nothing warns you. After a core upgrade, check every overridden block name against the new core template (`vendor/shopware/storefront/Resources/views/…`). Payment and shipping form overrides are common casualties on 6.7.
- **Extending a core class ties you to an `@internal` constructor.** Core service constructors are marked `@internal` and change in minor releases. `ProductSliderCmsElementResolver` gained a fourth argument within 6.6 and was rebuilt around processors in 6.7, which broke plugins that subclassed it. Decorate the abstract class or wrap the service instead; if you must extend, expect to adjust on every update.
- **`shopware/conflicts` blocks known-bad combinations.** When Composer refuses an update because of a conflict declared there, constrain the conflicting package below the listed version (for example a `twig/twig` upper bound). Don't remove `shopware/conflicts`.
- **Core may now ship what a plugin built.** Check release notes for overlaps and migrate data to the core field instead of keeping two:
  - `order.internalComment` (6.7.0.0) replaces custom "internal comment" order custom fields. Move existing values with a migration and update templates and PDFs that print it; escape it (`|nl2br` on escaped text, not `|raw`).
  - The EU legal guarantee notice (GARAN label: `Content/LegalGuaranteeNotice`, `store-api/legal-guarantee-notice`) arrived in 6.7.14.0 and was backported to 6.6.10.25.

## Replacement Strategy

Prefer small, explicit version seams over scattered conditionals:

- one adapter for version-sensitive admin build logic
- one payment-orchestration seam for handler contract differences
- one snippet or translation compatibility layer when 6.6 and 6.7.3+ filename rules differ
- one dedicated migration chunk when a copied legacy storefront template must be brought back in line with newer core markup

## Official Anchors

Start here when versioned behavior matters:

- 6.7 payment guide: `https://developer.shopware.com/docs/guides/plugins/plugins/checkout/payment/add-payment-plugin.html`
- 6.6 payment guide: `https://developer.shopware.com/docs/v6.6/guides/plugins/plugins/checkout/payment/add-payment-plugin.html`
- 6.7 template guide: `https://developer.shopware.com/docs/guides/plugins/plugins/storefront/customize-templates.html`
- 6.6 template guide: `https://developer.shopware.com/docs/v6.6/guides/plugins/plugins/storefront/customize-templates.html`
- 6.7 migrations guide: `https://developer.shopware.com/docs/guides/plugins/plugins/plugin-fundamentals/database-migrations.html`
- 6.6 migrations guide: `https://developer.shopware.com/docs/v6.6/guides/plugins/plugins/plugin-fundamentals/database-migrations.html`
- Vue 3 upgrade: `https://developer.shopware.com/docs/guides/plugins/plugins/administration/system-updates/vue3.html`
- Pinia upgrade: `https://developer.shopware.com/docs/guides/plugins/plugins/administration/system-updates/pinia.html`
- Vite upgrade: `https://developer.shopware.com/docs/guides/plugins/plugins/administration/system-updates/vite.html`
- Translation extension upgrade: `https://developer.shopware.com/docs/resources/references/upgrades/core/translation/extension-translation.html`
