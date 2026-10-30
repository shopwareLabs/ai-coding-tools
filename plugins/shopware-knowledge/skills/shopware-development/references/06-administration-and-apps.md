# Administration and Apps

Index: admin rules, admin Twig, 6.7/6.6 surfaces, apps, cloud, manifest, webhooks, actions, scripts, validation.

Contents: [Admin rules](#administration-rules) | [Admin Twig](#administration-twig-templates) | [Migration](#67-migration-surfaces) | [6.6](#66-compatibility-mode) | [Apps](#app-extensions) | [Cloud](#cloud-and-app-first-guidance) | [Validation](#validation) | [6.7 changes and pitfalls](#67-administration-changes).

Decide first whether the task belongs in:

- a plugin administration module
- a Shopware app extension
- a project-local admin customization

Use the lightest surface that fits the requirement.

## Administration Rules

- Keep admin UI thin. Heavy work belongs in backend services and Admin API routes.
- Prefer System Config for simple settings pages. Build a full admin module only when the workflow justifies it.
- Enforce ACL in both UI and backend.
- Use repository access, Criteria, and service utilities consistently.
- Use the documented administration extension surfaces rather than ad hoc global bridges between modules.
- Never embed secrets, private keys, or privileged provider credentials in admin JS.
- If the feature integrates an external API, prefer a clear diagnostics path such as an API test action and actionable error reporting.
- Never expose Admin API tokens, client secrets, or equivalent privileged credentials to storefront JavaScript or Twig.
- Do not make the storefront call custom Admin API routes directly. Bridge through a backend route with the correct customer-facing validation or use the Store API where appropriate.
- Preserve the normal entity save pipeline by default, including validation, pending associations, loading/error state, and the parent's returned promise. Do not replace it with an isolated repository save or immediate writes from an embedded tab.
- Ask only about an unresolved, high-impact choice that materially changes save behavior, write timing, entity modeling, native-component reuse, or UX structure. Do not ask again about an already user-authorized direction or ordinary implementation details.
- Bind plugin-owned entity data to the loaded entity/association and let the parent save it. If an override is needed, delegate to the parent (`return this.$super('onSave')`) rather than copying its implementation. Check the exact parent contract: a resolved promise can also mean validation stopped the save, so `.then()` alone is not proof of persistence for follow-up writes.

Source: [v6.7.15.1 product detail onSave](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Administration/Resources/app/administration/src/module/sw-product/page/sw-product-detail/index.js), [category detail onSave](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Administration/Resources/app/administration/src/module/sw-category/page/sw-category-detail/index.js).

Example patterns:

```js
// Bad: storefront bridge to privileged admin route
fetch('/api/_action/my-plugin/rebuild-index', {
    method: 'POST',
    headers: { Authorization: `Bearer ${adminToken}` },
});
```

```text
Preferred: keep the privileged action in the admin or app backend, protect it with ACL or signed app requests, and expose only customer-safe storefront routes through Store API or another ownership-checked backend route.
```

## Administration Twig Templates

- Administration Twig templates do not have access to storefront-only PHP Twig functions.
- Administration templates are automatically extended; do not add `{% extends '...' %}` or `{% sw_extends '...' %}`.
- A block with the same name replaces the parent block. Use `{% parent %}` only when appending to parent content is intentional.

```text
Bad: a new category tab writes cross-selling rows immediately on every click even though the data belongs to the category edit flow.
Good: keep changes pending on the category and preserve its save flow. Use immediate writes only for an explicitly authorized independent workflow; scale concerns alone do not authorize changing Save/Cancel semantics.
```

## 6.7 Migration Surfaces

Treat these as explicit modernization tasks:

- Vue 3 migration
- Pinia store migration
- Vite build migration

Use them only when the project already targets them or the user asked for the migration.

## 6.6 Compatibility Mode

For 6.6 work:

- verify the admin surface against `/docs/v6.6/` when available
- keep transition-era code stable unless the migration is the task
- avoid mixing admin modernization with unrelated feature work
- if the plugin must support both 6.6 and 6.7 admin builds, assume a version split or build split may be necessary and verify it explicitly

## App Extensions

Use app surfaces when the requirement fits the app model:

- manifest-driven configuration
- custom modules
- action buttons
- webhooks
- app scripts
- custom fields and extension surfaces declared through the manifest

## Cloud and App-First Guidance

- If the target is Shopware Cloud, assume app-first constraints unless the project proves it is self-hosted.
- Prefer apps when the requirement fits manifest-declared permissions, Admin API or Store API access, webhooks, action buttons, custom modules, or app scripts.
- Prefer plugins only when the project is self-hosted and the feature truly needs plugin-only capabilities such as PHP runtime extensions, DAL entity definitions, migrations, or storefront plugin code.
- Do not design cloud features around filesystem writes, direct DB access, or plugin-only extension points that cannot exist in the app model.

Concrete scope examples:

```text
Bad: pick a plugin admin module for a cloud-compatible settings form that only needs config, action buttons, and one backend webhook.
Good: use an app with manifest permissions, a custom module, and a signed backend for the webhook or action flow.
```

```text
Bad: force an app script to own a workflow that actually needs durable operational state, batch processing, and server-side retries.
Good: if the project is self-hosted and the flow needs DAL entities, queues, and PHP services, keep it in a plugin.
```

## App Manifest Rules

- Keep `manifest.xml` complete and least-privilege. Do not request permissions "just in case".
- Declare only the hosts, cookies, webhooks, payment methods, tax providers, and custom fields the app actually needs.
- Keep compatibility explicit and align manifest features with the supported Shopware versions.
- If the app only needs to read orders and trigger one action button, do not request create/update/delete permissions across unrelated entities.

## App Webhooks

- Verify signatures before processing.
- Make handlers idempotent and safe for retries.
- Return success only after the event is durably accepted; return failure when you need Shopware to retry.
- Queue or defer slow downstream sync logic.
- `product.written` should upsert sync state keyed by the Shopware entity ID instead of blindly creating duplicate remote records.

## Action Buttons and Admin Actions

- Verify signed action payloads on the app backend.
- Handle single-item and bulk actions deliberately.
- Return the right action response type for UX: notification, modal, new tab, or reload.
- Keep privileged writes on the app backend or Admin API; never trust client-side action payloads by themselves.
- A "Sync to ERP" action should return a success or error notification, while a "Show report" action can open a modal or new tab.

## App Scripts

- Use app scripts for light hook-based behavior that does not need a full admin module or plugin backend.
- Do not hide complex business logic in Twig scripts when the flow deserves a service or app backend endpoint.
- Prefer app scripts or manifest-declared extension points when they solve the task cleanly; do not escalate to a full plugin or admin module without a reason.

## Validation

For admin or app changes, verify:

- ACL and route permissions
- translation and snippet resolution
- build path used by the project
- error states and progress handling
- no leakage of secrets into client bundles
- no mixed Vuex and Pinia assumptions during 6.7 migration work
- dependency hygiene when adding SDKs or large NPM packages to the admin bundle
- least-privilege app permissions, webhook signature handling, and action-button response behavior
- no storefront-to-admin credential bridging or browser-side use of admin tokens

## 6.7 Administration Changes

### Vite + Pinia + Vue 3

- Admin builds with Vite. Webpack is out.
- Vue 2 compat layer is removed.
- Components are async by default (with core exceptions). Template refs may not exist until the child mounts; use `@vue:mounted` or the component's actual readiness signal and guard access. `nextTick` alone does not wait for an unloaded async component.
- State management uses Pinia via `Shopware.Store.register({ id, state, getters, actions })`.
- Vuex helpers renamed to `mapVuexState`, `mapVuexMutations`, `mapVuexGetters`, `mapVuexActions` (legacy). New code uses Pinia's `mapState`.
- `vue-i18n` v10 drops `tc`. `$tc` is still shimmed to `$t` — migrate to `$t('key', { count })` now.

Extensions shipping administration builds for both 6.6 and 6.7 need the matching build distribution; the 6.7 upgrade guide calls for a separate plugin version for that administration build boundary. This is not a blanket requirement for every backend-only extension or every later minor.

Source: UPGRADE-6.7.md §6.7.0.0, release notes 6.7.0.

### Meteor Components (`mt-*`)

Many `sw-*` primitives are renamed. Full mapping:

- `sw-button` → `mt-button`
- `sw-text-field` → `mt-text-field`
- `sw-select-field` → `mt-select`
- `sw-card` → `mt-card`
- `sw-tabs` → `mt-tabs`
- `sw-icon` → `mt-icon`
- `sw-checkbox-field` → `mt-checkbox`
- `sw-datepicker` → `mt-datepicker`
- `sw-password-field` → `mt-password-field`
- `sw-colorpicker` → `mt-colorpicker`
- `sw-external-link` → `mt-external-link`
- `sw-progress-bar` → `mt-progress-bar`
- `sw-switch-field` → `mt-switch`
- `sw-number-field` → `mt-number-field`
- `sw-loader` → `mt-loader`
- `sw-textarea-field` → `mt-textarea`
- `sw-email-field` → `mt-email-field`
- `sw-url-field` → `mt-url-field`
- `sw-skeleton-bar` → `mt-skeleton-bar`
- `sw-popover` → `mt-floating-ui`

Prefer `mt-*` in 6.7 templates. Fall back to `sw-*` only when explicitly targeting 6.6. `mt-*` enforces Shopware Design System — expect behavioral changes beyond prop renames.

For wrappers that provide it, the boolean `deprecated` prop (for example `<sw-button deprecated />` or `:deprecated="true"`) selects the legacy component. It is a transition aid, not a universal switch on every `sw-*` component and not a substitute for compatible 6.6/6.7 builds. Verify the exact supported 6.6 release before applying it there.

Source: UPGRADE-6.7.md §6.7.0.0.

**Event names differ between the two flavours.** Meteor value fields normally bind `model-value` and emit `update:model-value`; legacy fields such as `sw-text-editor` bind `value` and emit `update:value`. Core's own CMS text config uses both, behind `METEOR_TEXT_EDITOR`. A listener on the wrong event does not receive the update; do not rely on a console warning. Check the concrete component's props/`emits` rather than inferring a contract from its prefix. In v6.7.15.1, `sw-select-field`'s default Meteor branch renders `mt-select` with `:options` and does not forward child `<option>` elements; its `deprecated` branch differs. Pass options as data or migrate the component deliberately.

Source: [CMS text config](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Administration/Resources/app/administration/src/module/sw-cms/elements/text/config/sw-cms-el-config-text.html.twig), [select wrapper](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Administration/Resources/app/administration/src/app/component/form/sw-select-field/sw-select-field.html.twig).

### Runtime Pitfalls (Vue 3 Admin)

Verified against the v6.7.15.1 administration source; runtime frequency and layout symptoms depend on the extension and configuration.

- **`sw-entity-listing` emits `update-records` for data you passed in.** Its `dataSource`/`items` watchers and `createdComponent()` call `applyResult()`, which emits `update-records`. A parent that unconditionally reloads on `@update-records` can feed new data back in and trigger a search feedback loop. Adopt a distinct result without starting another search, or omit this handler when the parent owns loading. Do not treat the event as a request to fetch.

    ```js
    // Bad: every load triggers the next one
    onUpdateRecords() { this.getList(); }

    // Preferred: ignore our own data; only adopt results the listing loaded itself
    onUpdateRecords(result) {
        if (result === this.items) { return; }
        this.items = result;
    }
    ```

- **Route query read only in `created()` goes stale.** Vue Router reuses the component when you navigate to the same route with a different query (dashboard link → filtered list). `created()` doesn't run again, so filters taken from `$route.query` keep the old values. Watch `$route.query`, or use `beforeRouteUpdate`, and debounce: one watcher per filter fires one reload per filter on reset.
- **`ApiService.getBasicHeaders()` defaults to `Content-Type: application/json`.** It allows additional-header overrides, but the unchanged defaults mislabel `FormData` and can prevent server-side multipart parsing. For uploads, keep authentication/language headers and remove `Content-Type` so the browser/HTTP client supplies the multipart boundary; verify interceptors do not add JSON back:

    ```js
    const headers = this.getBasicHeaders();
    delete headers['Content-Type'];
    return this.httpClient.post('/_action/my-plugin/import', formData, { headers });
    ```

- **The router doesn't exist yet when plugin scripts run.** `Application.bootFullApplication()` runs `loadPlugins()` first. `createRouterInstance()` runs later, inside `view.initDependencies()`. `Shopware.Application.getContainer('init').router.getRouterInstance()` returns `null` in a plugin's `main.js`, so `router.beforeEach()` guards can't be attached there. Use a module's `routeMiddleware(next, currentRoute)` or change the route definitions before the router is built (for example, set `redirect` on a registered route object). If a guard needs the live router, add it from a component that mounts after boot.

Source (v6.7.15.1): [listing watchers/applyResult](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Administration/Resources/app/administration/src/app/component/entity/sw-entity-listing/index.js), [API headers](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Administration/Resources/app/administration/src/core/service/api.service.ts), [boot sequence](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Administration/Resources/app/administration/src/core/application.ts), [view dependencies](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Administration/Resources/app/administration/src/app/adapter/view/vue.adapter.ts).

### Admin Layout, Theming, And Branding

- **`sw-page` has two side areas.** The `side-content` slot is a left column (grid, `$sw-page-side-content-default-width: 440px`), suited to a vertical tab menu (`mt-tabs` with `vertical`). The `sidebar` slot is the right-hand `sw-sidebar` with `sw-sidebar-item`s. Core lists put filters and refresh there (`sw-product-list`). Put listing filters in the right sidebar to match core. To narrow the left column, override with a selector more specific than core's `.sw-page .sw-page__content.has--side-content`, or load order decides the winner.
- **When you add a left column, re-check centring.** Core still centres the search bar and smart bar on the full page width, so content centred in the remaining area looks shifted by half the column width (*observed*).
- **Dark mode.** The 6.7 admin (present by 6.7.14) switches appearance with `data-theme="dark"`. The Meteor tokens (`@shopware-ag/meteor-tokens`, `deliverables/administration/dark.css`) redefine the `--color-*` custom properties under `[data-theme='dark']`. Use the tokens (`var(--color-background-primary-default)`, `var(--color-text-primary-default)`, `var(--color-border-primary-default)`) instead of hardcoded colours, and use `[data-theme="dark"] &` only for exceptions, as core does in `sw-cms-slot.scss`. Keep colours that preview customer-facing output (a banner canvas, a mail preview) independent of the admin theme. Test every custom module in both appearances.

Source: [v6.7.15.1 sw-page layout](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Administration/Resources/app/administration/src/app/component/structure/sw-page/sw-page.scss), [CMS slot appearance handling](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Administration/Resources/app/administration/src/module/sw-cms/component/sw-cms-slot/sw-cms-slot.scss). Width/centring symptoms are layout-dependent observations, not reasons for a global CSS reset.

### Admin Codemod

Run codemods for admin migration:

```bash
composer run admin:code-mods -- --plugin-name MyPlugin --fix -v 6.7
```

- Requires the plugin to live under `custom/plugins/`.
- Adds `// TODO` comments where manual work is required. Do not assume 100% automation.

### `sw-entity-listing` `items` → `dataSource`

In v6.7.15.1, passing `items` to `sw-entity-listing` is deprecated for removal in 6.8. Pass `:data-source="…"` instead; the template prop maps to `dataSource`. Verify an older target's component API before changing a cross-version build.

Source: [v6.7.15.1 listing props/internalDataSource](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Administration/Resources/app/administration/src/app/component/entity/sw-entity-listing/index.js).

### Rule Builder Condition Contract

- `LineItemPurchasePriceRule`: `bool $isNet` → `?string $type` (`'gross'|'net'`, auto-migrated).
- `LineItemCustomFieldRule` now throws `RuleException::unsupportedOperator()` (not `CartException`).
- `CustomerBirthdayRule` no longer throws on null.
- `LineItemProductStatesRule` deprecated → `LineItemProductTypeRule`.
- Rule builder condition components `sw-condition-line-item-in-category`, `-purchase-price`, `-is-net-select` are deprecated for `sw-condition-generic`.
- `sw-condition-base` no longer exposes `mapPropertyErrors('condition', […])` spreads or `conditionValue*Error` computeds. Use `sw-condition-field-errors` and read errors off the entity's error collection.

Source: UPGRADE-6.7.md §6.7.12.0, §6.7.13.0.

### Filesystem `visibility`

`filesystems.<name>.config.visibility` is deprecated. Use `filesystems.<name>.visibility` at the top level in generated `config/packages/shopware.yaml` snippets.

Source: UPGRADE-6.7.md §6.7.1.0.

### OAuth `scope` Format

`/api/oauth/token` requires space-delimited `scope: 'write admin'` (a string, not an array). Since the `league/oauth2-server` 9.x upgrade, non-spec-compliant requests are rejected with an error rather than accepted. `/api/oauth/authorize` is removed.

Source: UPGRADE-6.7.md §6.7.0.0.

### MCP Server Integration

Experimental MCP endpoints at `/api/_mcp` and `/store-api/_mcp`.

On 6.7.11-6.7.13, check the `MCP_SERVER` feature flag (default `false`). From 6.7.14 the flag is removed and has no effect; in v6.7.15.1 the endpoints are available when `symfony/mcp-bundle` is installed, subject to authentication, permissions, and deployment routing. Do not assume reachability on an unchecked shop.

Register capabilities with DI tags:

- Admin: `mcp.tool`, `mcp.prompt`, `mcp.resource`
- Store API: `shopware.store_api_mcp.tool`, `shopware.store_api_mcp.prompt`, `shopware.store_api_mcp.resource`

CLI: `bin/console debug:mcp` lists registered capabilities. Classes are `@experimental` until 6.8 — do not inherit from them.

Source: [v6.7.15.1 upgrade guide, MCP flag removal](https://github.com/shopware/shopware/blob/v6.7.15.1/UPGRADE-6.7.md#mcp-server-no-longer-uses-the-mcp_server-feature-flag).

### Payment/Shipping `technicalName` Non-Nullable

`payment_method.technical_name` and `shipping_method.technical_name` are non-nullable in 6.7 (auto-migrated). Always set a plugin-prefixed `technicalName` in plugin migrations and method creation. Custom field set `name` must be unique per app (from 6.7.1). Payment or shipping methods without `technicalName` at upgrade time get `temporary_<id>` assigned automatically — set meaningful names before upgrade or lose the ability to reference them cleanly.

Source: release notes 6.7.0, 6.7.1.
