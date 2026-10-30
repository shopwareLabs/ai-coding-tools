# Storefront and Themes

Index: rendering, Twig, storefront JS, SCSS/theme, performance/cache, 6.7 structure, SEO/accessibility.

Contents: [Rendering](#rendering-strategy) | [Twig](#twig-rules) | [JS and consent](#storefront-js) | [Replaced markup](#plugins-inside-replaced-markup-run-once) | [SCSS](#scss-and-theme-work) | [Cache](#performance-and-cache) | [6.7 structure](#67-storefront-structure) | [SEO/accessibility](#seo-and-accessibility) | [6.7 changes](#67-storefront-changes).

## Rendering Strategy

- Keep Twig templates cheap.
- Precompute data in controllers, page loaders, Store API routes, or dedicated services.
- Pass minimal context to templates.
- Extend templates with blocks before copying files.

## Twig Rules

- Use `sw_extends` and block overrides for upgrade safety.
- Do not copy full core templates unless block overrides or smaller partial overrides are insufficient.
- Keep autoescaping enabled.
- Avoid `|raw` on untrusted data.
- Do not hide business logic, authorization logic, or ownership checks in templates.
- Do not traverse heavy entity graphs or large collections in templates when the data can be prepared once upstream.
- Do not leave `dump()` or debug helpers in shipped templates.
- Use snippets for translatable text.
- Do not fetch database-backed data from Twig in loops or CMS slots via helpers such as `searchMedia()`. Resolve data once in a page loader, CMS resolver, or service.
- Do not use hard-coded static IDs in reusable product, listing, CMS, or account components.
- Do not use `href="#"` or similar pseudo-controls for button behavior.
- Do not use positive `tabindex`.
- Do not embed inline script or style blocks inside repeated product-card, slider, or CMS loops.
- Do not render customer-specific fragments or set plugin cookies from otherwise cacheable template paths just to personalize one label or banner.

Example patterns:

```twig
{# Bad: copied control markup plus pseudo-button navigation #}
<a href="#" class="buy-widget__toggle" onclick="toggleDetails()">
    {{ "my-plugin.details"|trans }}
</a>
```

```twig
{# Preferred: block-safe override with semantic control #}
{% sw_extends '@Storefront/storefront/component/product/card/action.html.twig' %}

{% block component_product_box_action_inner %}
    <button
        type="button"
        class="btn btn-secondary"
        aria-controls="product-details-{{ detailsInstanceId }}"
        aria-expanded="false">
        {{ "my-plugin.details"|trans }}
    </button>
    <div id="product-details-{{ detailsInstanceId }}" hidden>
        {{ product.translated.description|sw_sanitize }}
    </div>
{% endblock %}
```

The caller supplies `detailsInstanceId`, an opaque, DOM-safe ID unique to this rendered card occurrence. `product.id` alone is not instance-unique: the same product can appear in several sliders or twice in one listing. Preserve the parent action block with `{{ parent() }}` when adding rather than intentionally replacing its buy actions. Wire the disclosure to toggle `hidden` and `aria-expanded` together.

```twig
{# Bad: repeated IDs and expensive helper work in a listing loop #}
{% for product in searchResult %}
    <button id="details-toggle" aria-controls="details-panel">
        {{ "my-plugin.details"|trans }}
    </button>

    {% set media = searchMedia([product.coverId], context.context) %}
{% endfor %}
```

```twig
{# listingInstanceId is unique per rendered listing, including AJAX fragments. #}
{# Product data is preloaded upstream; loop.index0 distinguishes duplicate products. #}
{% for product in searchResult %}
    {% set detailsId = 'details-' ~ listingInstanceId ~ '-' ~ loop.index0 %}
    <button
        type="button"
        id="{{ detailsId }}-toggle"
        aria-controls="{{ detailsId }}-panel"
        aria-expanded="false">
        {{ "my-plugin.details"|trans }}
    </button>
    <div id="{{ detailsId }}-panel" hidden>
        {{ product.translated.description|sw_sanitize }}
    </div>
{% endfor %}
```

## Storefront JS

- Use the Shopware storefront plugin system and data attributes for progressive enhancement.
- Keep client code thin and avoid duplicating server-side business rules.
- Prefer Store API or purpose-built endpoints for dynamic data.
- Prefer native `fetch` for new storefront JS unless the project already standardizes on an existing HTTP helper.
- Do not embed secrets or privileged logic in storefront JS.
- Do not load third-party libraries globally when the feature only exists on one route or widget.
- Do not write untrusted HTML with `innerHTML`, `insertAdjacentHTML`, or equivalent sinks. Treat `v-html` with the same suspicion.
- Prefer `textContent` for status and label updates.
- Use `role="status"` or `role="alert"` for async UI feedback where users need an announcement.
- Manage focus explicitly for modals, flyouts, offcanvas panels, and other custom widgets that move the user through a stateful flow.
- Avoid browser `alert()` for recoverable failures or normal UI state changes.
- Scope selectors and event handling to the component root rather than broad document queries.
- Validate `postMessage` origins before trusting cross-window data.
- Escape data for JavaScript context explicitly; HTML escaping alone does not make inline JS safe.
- Do not inject the same external script, inline script, or inline style block inside product-card or CMS loops. Load once per page or route.
- Keep third-party widgets route-scoped and consent-aware.
- Throttle scroll handlers, constrain MutationObservers, and avoid polling loops that run across the whole storefront without a hard need.
- Do not use body-wide MutationObservers as the default way to repair labels, alt text, or other accessibility issues after render.
- Prefer Shopware's plugin registration and modal utilities over one-off global event wiring or bespoke modal shells.

```js
// Bad: global query and HTML sink in a repeated component
document.querySelector('.coupon-status').innerHTML = response.message;
```

```js
// Preferred: component-scoped update with safe text and status semantics
this.el.querySelector('[data-coupon-status]').textContent = response.message;
this.el.querySelector('[data-coupon-status]').setAttribute('role', 'status');
```

```js
// No iframe, external request, or SDK is created before opt-in.
import Plugin from 'src/plugin-system/plugin.class';
import CookieStorage from 'src/helper/storage/cookie-storage.helper';
import { COOKIE_CONFIGURATION_UPDATE } from 'src/plugin/cookie/cookie-configuration.plugin';

let widgetInstance = 0;

export default class ConsentWidgetPlugin extends Plugin {
    init() {
        this._frame = null;
        this._destroyed = false;
        this._consentEmitter = document.$emitter;
        this._consentEvent = `${COOKIE_CONFIGURATION_UPDATE}.MyWidget${++widgetInstance}`;
        this._consentEmitter.subscribe(this._consentEvent, () => this.syncConsent());
        this.syncConsent();
    }

    syncConsent() {
        const allowed = CookieStorage.getItem('my-plugin-widget') === '1';
        if (!allowed || this._destroyed) {
            this.removeWidget();
            return;
        }
        if (this._frame) { return; }

        const frame = document.createElement('iframe');
        frame.title = this.el.dataset.widgetTitle;
        frame.src = 'https://widget.example/embed';
        this.el.append(frame);
        this._frame = frame;
    }

    removeWidget() {
        this._frame?.remove();
        this._frame = null;
    }

    destroy() {
        this._destroyed = true;
        this._consentEmitter.unsubscribe(this._consentEvent);
        this.removeWidget();
    }
}
```

Register the class from the extension's `main.js` and render its root only on the route that owns the widget:

```js
import ConsentWidgetPlugin from './consent-widget.plugin';

window.PluginManager.register('ConsentWidget', ConsentWidgetPlugin, '[data-consent-widget]');
```

```twig
<div data-consent-widget data-widget-title="{{ 'my-plugin.widgetTitle'|trans|e('html_attr') }}"></div>
```

Register optional cookie `my-plugin-widget` with value `'1'` in the cookie groups (see `12-extension-patterns.md`, "Cookie Provider Replaced By Event"). Do not set it from this plugin. `CookieStorage.getItem()` is **static** and returns a string or `false`. Initial absent/denied consent leaves the root empty; saved consent loads once; grant creates the iframe; revocation removes it; re-grant creates a fresh one. Core publishes `CookieConfiguration_Update` on `document` after applying cookie changes, so the handler can re-read the cookie. This is not the newer `window.Shopware` bus.

The URL is a fixed illustrative provider endpoint; use a reviewed provider URL, translated title, appropriate CSP/frame policy, and fallback content. Removing an iframe stops that browsing context, but cannot undo already sent data or erase provider cookies. A script-based SDK needs its documented stop/unload and storage cleanup; hiding markup or removing its `<script>` is not teardown. For asynchronous loading, re-check consent/instance state after every `await` before mounting. Do not preconnect, preload, or server-render external media before opt-in.

Use the unique event suffix for each instance: core `unsubscribe(eventName)` does **not** accept a callback filter. In v6.7.15.1 the manager calls `destroy()` when replacing a plugin implementation, not automatically whenever arbitrary DOM is removed. Code that removes this root must call its instance's `destroy()` first; older supported versions need their own verified teardown integration.

```twig
{# Preferred: use Shopware's pseudo modal shell for route-scoped modal content #}
<button
    type="button"
    data-ajax-modal="true"
    data-url="{{ path('frontend.my-plugin.modal') }}">
    {{ "my-plugin.openModal"|trans }}
</button>
```

### Plugins Inside Replaced Markup Run Once

In v6.7.15.1, `PluginManager` initialises plugins on the DOM it finds. `CartWidget` (`plugin/header/cart-widget.plugin.js`) replaces its descendants from stored markup during `init()` and from the checkout-info fetch response, without initialising plugins inside that replacement. A descendant instance can therefore be detached or never created in the new markup; do not rely on its first initialisation order.

- Attach the plugin to a stable root **outside** the replaced descendants and listen on the actual `[data-cart-widget]` element. `CartWidget` publishes `insertStoredContent` after stored-content handling and `fetch` after fetch-content handling (`event.detail.content` is available for `fetch`). They are non-bubbling DOM `CustomEvent`s, not native network events. Subscribe directly, refresh once immediately to cover an already-fired initial event, and remove both listeners during teardown.
- When your own code replaces markup that contains plugins, clean up outgoing instances first, then `await window.PluginManager.initializePluginsInParentElement(el)`. In v6.7.15.1 this scans matching **descendants**, not the parent itself. To initialise the parent too, use `await window.PluginManager.initializePlugin('MyPlugin', el)`. Verify availability on older supported versions rather than assuming this helper exists there.
- Carry data for JS in a `<template>` or `data-*` attribute rather than a hidden `<div>` inside a link. Templates are never rendered and screen readers skip them.

```js
// Inside a Plugin whose stable root contains the cart-widget element.
init() {
    this._cart = this.el.querySelector('[data-cart-widget]');
    if (!this._cart) { return; }
    this._refresh = () => this.refreshFromCart();
    this._cart.addEventListener('insertStoredContent', this._refresh);
    this._cart.addEventListener('fetch', this._refresh);
    this.refreshFromCart(); // read current DOM even if CartWidget already initialised
}

destroy() {
    this._cart?.removeEventListener('insertStoredContent', this._refresh);
    this._cart?.removeEventListener('fetch', this._refresh);
}
```

Implement `refreshFromCart()` as an idempotent, component-scoped read of the current widget markup/data. It must not call `CartWidget.fetch()` in response to `fetch`, or it creates a request feedback loop.

Source (v6.7.15.1): [cookie helper](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Storefront/Resources/app/storefront/src/helper/storage/cookie-storage.helper.js), [cookie update publication](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Storefront/Resources/app/storefront/src/plugin/cookie/cookie-configuration.plugin.js), [emitter subscribe/unsubscribe](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Storefront/Resources/app/storefront/src/helper/emitter.helper.js), [CartWidget](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Storefront/Resources/app/storefront/src/plugin/header/cart-widget.plugin.js), [plugin manager](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Storefront/Resources/app/storefront/src/plugin-system/plugin.manager.js).

## SCSS and Theme Work

- Respect theme inheritance.
- Prefer variables, configuration, and stable CSS hooks over brittle selectors.
- Keep overrides local to the feature.
- Do not mix a large redesign with unrelated backend refactors.

### CSS Gotchas

- **Check core icon alignment.** v6.7.15.1 `_icon.scss` sets `.icon > svg { position: relative; top: 0.25em; }` to align icons with running text. In a flex row that already centres its items, this can appear too low. Reset `top: 0` only for the affected component, not globally.
- **Check overflow ancestors when sticky fails.** `overflow: hidden` can create a scrolling ancestor that changes `position: sticky` behaviour; `html`/`body` also have viewport-specific behaviour. Where clipping is actually needed, consider `overflow-x: clip` and test supported browsers rather than prescribing it globally.
- **Use `100dvh`, not `100vh`, for full-height mobile panels.** On iOS Safari `100vh` is the height with the toolbar collapsed. A menu sized `calc(100vh - …)` puts its bottom content behind the browser toolbar. `dvh` follows the visible viewport.
- **Find horizontal scroll at the source.** Common causes are fixed-width embeds (third-party iframes with a `width` attribute; give them `max-width: 100%`), the negative margins of a block's `.row` in a full-width CMS section, and fixed pixel font sizes that don't fit a 375px screen. Don't hide the overflow globally.
- **Inspect the installed Bootstrap utilities.** Whether `.text-primary` and similar utilities use `!important` depends on the bundled version and utility configuration, not simply project age. Prefer removing/replacing a conflicting utility; if an important override is necessary, scope it to the component and check specificity/load order.

Source: [v6.7.15.1 icon SCSS](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Storefront/Resources/app/storefront/src/scss/component/_icon.scss). Other layout symptoms above are diagnostic patterns to verify in the target theme/browser, not defects guaranteed in every project.

## Performance and Cache

- Treat storefront performance as a cache and payload problem first.
- Avoid adding cookies or headers on cacheable responses without a strong reason.
- Move user-specific fragments to AJAX, Store API, or non-cacheable routes rather than disabling cache broadly.
- Protect LCP by keeping hero media, server response time, and render-blocking CSS under control.
- Protect CLS by avoiding late banners, async style jumps, and unstable placeholders.
- Protect INP by keeping interaction handlers and storefront JS bundles small.
- If navigation, catalog visibility, or shipping/payment presentation varies by customer segment, rule, or sales role, enforce that variation server-side and ensure the cache key varies accordingly. Hiding it only in Twig is not a security boundary.
- Preserve cacheability of shared routes. If the page stays anonymous and cacheable, move customer-specific or high-churn fragments behind AJAX or purpose-built non-cacheable endpoints instead of forcing a whole-page miss.

## 6.7 Storefront Structure

- Review header and footer overrides carefully on 6.7 because shared fragment rendering changed.
- Re-check cache and template-target implications before copying older 6.6 storefront assumptions into 6.7 projects.
- Keep theme overrides block-scoped on 6.7 so shared fragment and cache-tag behavior stays aligned with upstream template changes.

## SEO and Accessibility

- Preserve canonical and SEO URL behavior when adding pages or custom entities.
- Keep landmarks, headings, labels, control relationships, and focus handling correct on checkout and interactive UI.
- Use buttons for actions and links for navigation.
- Prefer semantic HTML over ARIA patching. Only add advanced ARIA patterns when the full behavior is implemented.
- Use snippets and semantic HTML instead of hardcoded strings or div-heavy widgets.
- If the change adds tracking, embeds, or third-party storefront scripts, verify consent and store-readiness impact explicitly.
- Do not set global noindex or similar SEO-breaking directives from a theme override without scoping and intent.
- For deeper storefront accessibility requirements, U.S. ecommerce baseline guidance, and WCAG-oriented review output, also load `17-accessibility-and-template-best-practices.md`.

## 6.7 Storefront Changes

### `controllerName` / `controllerAction` → `activeRoute`

Deprecated in 6.7.3 across Twig, JS, and CSS.

- Twig: use `activeRoute` (already resolved) instead of `controllerName` + `controllerAction`.
- CSS: use `.is-active-route-*` classes instead of `.is-ctl-*` / `.is-act-*`. Generate the class with `activeRoute|replace({'.': '-'})`.
- JS: use `window.activeRoute` instead of `window.controllerName` / `window.actionName`.

Never emit the deprecated names in generated Twig, JS, or CSS.

Source: UPGRADE-6.7.md §6.7.3.0, release notes 6.7.3.

### Cookie Provider Replaced By Event

`CookieProviderInterface` is deprecated. Register cookies via listener on `\Shopware\Core\Content\Cookie\Event\CookieGroupCollectEvent` using `CookieEntry` / `CookieGroup` structs. The new Store-API route is `\Shopware\Core\Content\Cookie\SalesChannel\CookieRoute` → `/store-api/cookie-groups`.

Twig properties `snippet_name` / `snippet_description` are deprecated; use `name` / `description` (they handle both snippet keys and plain strings).

Source: UPGRADE-6.7.md §6.7.3.0.

### Global Storefront Event Bus (Target-Version Check)

- v6.7.15.1 includes `window.Shopware.emit('Namespace:Event', payload)` and `window.Shopware.on('Namespace:Event', handler)` in the component-system runtime. Use the established bus when that runtime is loaded instead of inventing another global dispatcher; verify availability and API stability on the supported release. Do not move existing `document.$emitter` cookie events onto this bus.
- `window.PluginManager.callPluginMethod(pluginName, methodName, ...args)` invokes a method on registered instances of a plugin. Verify the method exists and outgoing instances are cleaned up; it does not itself filter detached elements or initialise missing plugins.

Source: [v6.7.15.1 component-system singleton](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Storefront/Resources/app/storefront/src/component-system/shopware.ts), [plugin manager](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Storefront/Resources/app/storefront/src/plugin-system/plugin.manager.js). These anchors prove the target-version APIs, not their first release.

### Vite Dev Server Replaces `composer watch:storefront`

The v6.7.15.1 core checkout provides `composer storefront:dev-server` for the Vite dev server and marks `composer watch:storefront` deprecated. Use the project's own available Composer/CLI scripts: production templates and older 6.7/6.6 projects need not expose the same root scripts. Do not assume a 6.7.11 minimum from an unverified release summary.

Source: [v6.7.15.1 Composer scripts/descriptions](https://github.com/shopware/shopware/blob/v6.7.15.1/composer.json).

### Theme Config As CSS Custom Properties

In v6.7.15.1 `ThemeCompiler::dumpVariables()` writes eligible typed `theme.json` fields (excluding `scss: false`) as **SCSS** variables. It does not automatically export every theme field as `--<field-name>`. Inspect the actual generated CSS; export a custom property explicitly when runtime styling needs one:

```scss
:root {
    --my-plugin-brand-primary: #{$sw-color-brand-primary};
}

.my-plugin-widget {
    color: var(--my-plugin-brand-primary);
}
```

- A runtime custom-property change affects only CSS that consumes it; it does not switch the entire compiled theme.
- Keep SCSS variables for compile-time calculations and theme compilation.

Source: [v6.7.15.1 ThemeCompiler::dumpVariables/formatVariables](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Storefront/Theme/ThemeCompiler.php).

### `theme.json` Per-File References

In v6.7.15.1, `style` / `script` entries can point to `@BundleName/path/to/file.(scss|js)` for surgical references instead of pulling a whole bundle. Verify resolution/build output on an older supported release rather than assuming this syntax is universal.

Source: [v6.7.15.1 ThemeFileResolver bundle-relative references](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Storefront/Theme/ThemeFileResolver.php).

### `context.token` Removed From Twig

The Store-API context token is no longer exposed in Twig. Do not reference `context.token` in templates, DOM IDs, cacheable markup, or logs. Prefer the storefront session for storefront routes. A genuinely separate Store API client must manage its own context deliberately; do not re-expose the removed token through a public controller as a workaround.

Source: [v6.7.15.1 SalesChannelContext::getToken Twig guard](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/System/SalesChannel/SalesChannelContext.php). Verify an older release's guard when supporting it; regardless of guard availability, keep the credential out of HTML.

### ESI Header And Footer

Header and footer render through ESI under route names `frontend.header` and `frontend.footer` (paths `/_esi/global/header` and `/_esi/global/footer` since 6.7.1; 6.7.0 used `/header` and `/footer`). New entry templates `@Storefront/storefront/layout/header.html.twig` and `.../footer.html.twig`. New blocks `base_esi_header` / `base_esi_footer` in `base.html.twig`.

- Extend `header.html.twig` / `footer.html.twig` directly. Do not override inline `base.html.twig` blocks that are now empty.
- Pass extra data via `StorefrontRenderEvent` or the `headerParameters` merge.
- Core renders the fragments with `ignore_errors: false`; fragment failures must not be silently swallowed. Verify `/_esi/global/header` and `/_esi/global/footer` with the actual ESI-capable cache/proxy (for example Symfony HttpCache or Varnish). Nginx SSI is not interchangeable with ESI support.

Full details in `23-cache-and-http-cache.md`.

Source: release notes 6.7.0.

Exact rendering: [v6.7.15.1 base ESI blocks](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Storefront/Resources/views/storefront/base.html.twig).

### `sw_breadcrumb_full*` Requires `SalesChannelContext`

`sw_breadcrumb_full` and `sw_breadcrumb_full_by_id` require the full `SalesChannelContext` (not `context.context`). Call `sw_breadcrumb_full(category, context)` in Twig.

Source: UPGRADE-6.7.md §6.7.1.0.

### Accessibility Markup Baseline (EAA)

6.7.0 sets `$font-size-base: 1rem` (16px) and switches key controls to semantic markup:

- Language/currency widgets and pagination use `<button>` / `<a>` (not styled hidden radios).
- Cart line items are `<ul>` / `<li>` (not `<div>`).
- Product-card duplicate link removed — the image no longer wraps a second anchor.
- Modal triggers use `<button class="btn btn-link-inline">`.
- `{% sw_icon %}` sets `aria-hidden="true"` by default. Give an icon-only control its own accessible name and leave its icon decorative; for a meaningful standalone icon, pass both `ariaHidden: false` and a translated `ariaLabel`. See `17-accessibility-and-template-best-practices.md`.
- New modal snippet keys use `%…ModalTagOpen%` params. Prefer the `-Modal` snippet key variants.

Full accessibility guidance in `17-accessibility-and-template-best-practices.md`.

Source: release notes 6.7.0, UPGRADE-6.7.md §6.7.0.0.
