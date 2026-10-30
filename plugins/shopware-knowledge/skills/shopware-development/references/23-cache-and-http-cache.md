# Cache and HTTP Cache

Contents: [delayed invalidation](#delayed-cache-invalidation), [feature flags](#cache_rework-feature-flag), [shared-output review](#finding-shape-personalised-output-in-a-shared-response), [keys/precedence](#what-the-http-cache-key-varies-on), [ESI](#esi-header-and-footer), [sources](#source-anchors).

Resolve installed `shopware/core`/`shopware/storefront` versions and active flags before applying these details. The key/policy behavior below is pinned to **6.7.15.1**, not all 6.7 patches or 6.6.

## Delayed Cache Invalidation

Shopware batches cache-tag invalidations by default in 6.7 (immediate in 6.6 unless configured).

The config key changed between majors — using the 6.6 name on 6.7 fails config validation with "Unrecognized option":

| Version | Key | Type | Default |
| --- | --- | --- | --- |
| 6.6 | `shopware.cache.invalidation.delay` | integer seconds | `0` (delayed invalidation **off**) |
| 6.7 | `shopware.cache.invalidation.delay_enabled` | boolean | `true` (delayed invalidation **on**) |

Delayed invalidation requires the `shopware.invalidate_cache` scheduled task to be running. Its cadence is a **separate** setting from the delay flag — see the interval section below; do not conflate them.

- Delayed storage: `shopware.cache.invalidation.delay_options.storage` — `mysql` by default in 6.7.15.1. Redis is an alternative for suitable shared infrastructure; multi-node operation does not by itself make shared MySQL invalid.
- If a plugin write must invalidate instantly (admin save that must show up in the storefront), send the `sw-force-cache-invalidate: 1` request header on the write.
- Debug pending invalidations: `bin/console cache:watch:delayed`.
- Flush pending invalidations manually: `bin/console cache:clear:delayed`.

Sources: [6.7.15.1 configuration tree](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/DependencyInjection/Configuration.php) and [CacheInvalidator](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Adapter/Cache/CacheInvalidator.php). Check the matching 6.6 config tree before copying a 6.7 YAML key.

## CACHE_REWORK Feature Flag

`CACHE_REWORK` opts into Store API HTTP caching and policy-driven response headers. `CACHE_CONTEXT_HASH_RULES_OPTIMIZATION` remains registered but is marked **deprecated/not used anymore** in 6.7.15.1; its presence is not proof of an active optimization path.

- **Opt-in and experimental:** `default: false` at 6.7.15.1. Inspect the deployed flag, route attributes, policies, and proxy config; do not infer enabled state from upgrade plans.
- Store API caching requires `CACHE_REWORK` (or the next-major flag); `_httpCache` alone is not sufficient in the legacy path. Route coverage changes by patch, so inspect the actual route rather than relying on a fixed endpoint count.
- `CACHE_REWORK`, `PERFORMANCE_TWEAKS`, or the next-major flag suppress legacy cart-filled/logged-in invalidation states. Only `CACHE_REWORK`/next-major selects the new Store API/policy branch and hash-mismatch guard; `PERFORMANCE_TWEAKS` alone does not.
- Under those hash-optimization branches, rule IDs are selected using resolved rule areas (default `RuleAreas::PRODUCT_AREA`), not a universal list of price-only rules. Extend `ResolveCacheRelevantRuleIdsExtension` or the relevant rule's `RuleAreas` metadata when another area changes shared content.

Sources: [feature declarations](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Resources/config/packages/feature.yaml), `CacheResponseSubscriber::setResponseCache`, and `CacheHeadersService::buildCacheHash` linked below.

## Finding Shape: Personalised Output In A Shared Response

Logged-in state is **not** customer identity. With `CACHE_REWORK`, cacheable Store-API responses stay cached for logged-in customers, so "the user is logged in" no longer implies "this response is private".

Prove that two authorized contexts with different output share a reusable public cache entry. Customer-dependent prices can be safely shared when every price-determining audience input is keyed; private responses or uncached fragments are also valid. A missing `_noStore` attribute alone is not evidence of exposure.

If private addresses/entitlements actually cross that boundary, report data exposure with the route, active policy, full cache key, authorization path, and affected contexts. For wrong shared prices/content, describe the demonstrated pricing/content impact rather than assuming all personalization is a disclosure.

Choose a fix that matches the data: a private/uncacheable policy, a non-cacheable fragment, or complete safe variation plus invalidation. Use `_noStore` when storage itself must be prohibited. In 6.7.15.1 the attribute is checked by **presence**, and under policy mode `CachePolicyProvider` enforces it for default policies; explicit route-policy mappings take precedence. Inspect final response headers and every proxy layer instead of assuming a controller's `setPrivate()` or an attribute cannot be overridden later.

## What The HTTP Cache Key Varies On

At 6.7.15.1, `HttpCacheKeyGenerator::generate()` combines the normalized URI (scheme/host, sales-channel base URL, path, sorted query minus configured ignored parameters), installation cache hash, variant headers, and context hash/fallback currency. `HttpCacheKeyEvent` listeners may add parts.

`HttpCacheVariantHeaders::HEADERS` contains `sw-access-key`, `sw-language-id`, `sw-currency-id`, `sw-include-seo-urls`, and `sw-cache-hash`. The first four are read as case-sensitive header values; the context hash has special precedence:

- **Key generation:** response `sw-cache-hash` cookie if supplied → request `sw-cache-hash` header → request cookie. The response cookie is server-computed and authoritative on write.
- **Mismatch guard:** with `CACHE_REWORK`/next-major, `CacheResponseSubscriber` compares request header → request cookie → empty string with the server-computed hash (or empty string). A mismatch sends `sw-dynamic-cache-bypass: 1` and takes the uncacheable-policy path. Test missing, stale, forged, and disagreeing header/cookie values against the deployed proxy too; this does not retroactively validate a cache hit served before PHP.
- **Hash parts:** sorted unique selected rule IDs, context version ID, currency ID, tax state, login state; Store API additionally includes language ID. Configured cache-relevant cookies and `HttpCacheCookieEvent` listeners can add parts. It is **not per-customer or per-cart**: neither customer ID nor cart token/items are default parts.
- `CacheHeadersService::isCacheHashRequired()` also considers filled carts, non-default currency/country/payment/shipping, persisted Store API language, and configured cookies. Requiring a hash does not mean all those raw values are in it; country may change rules/tax without being a direct hash part.
- Custom country-specific output (for example a shipping notice) needs complete variation if the existing rule/tax parts do not distinguish it. Add a part via `HttpCacheCookieEvent` and ensure `CacheHashRequiredExtension` requests a hash for affected contexts, or keep the output private/fragmented. `Accept-Language`, GeoIP, and arbitrary custom headers are not automatically direct key inputs.

Do not project this precedence or header set onto 6.6: [6.6.10.30 HttpCacheKeyGenerator](https://github.com/shopware/shopware/blob/v6.6.10.30/src/Core/Framework/Adapter/Cache/Http/HttpCacheKeyGenerator.php) prefers a response cookie, then the request cookie, and has a different `generate()` signature. Check the installed patch before adapting a decorator.

### Redirects From Cacheable Routes Get Cached

`CacheResponseSubscriber` skips caching for 404s, non-GET requests, and routes without the `_httpCache` attribute. It does **not** skip 3xx responses. A redirect returned from a cacheable route (for example a language or country redirect on `frontend.home.page`) gets `s-maxage` and can be stored by the app cache, Varnish, or a CDN. Combined with the key above, one visitor's language decides where everyone is sent.

- Keep visitor-dependent redirects outside a shared variant unless the key fully represents the decision. Apply the intended private/no-store policy and verify the final headers: the legacy subscriber can later set shared max-age, and policy mode replaces existing cache headers.
- Use temporary redirects for temporary visitor/context decisions. A permanent redirect may be retained by browsers; do not rely on a later shared-cache purge to undo it.

## Deprecated Cache Symbols (removed in 6.8)

- `CacheStateValidator`
- `CacheStateSubscriber`
- `HttpCacheKeyGenerator::SYSTEM_STATE_COOKIE`, `CURRENCY_COOKIE`, `INVALIDATION_STATES_HEADER`
- Config: `shopware.cache.invalidation.http_cache`
- Env: `SHOPWARE_HTTP_DEFAULT_TTL` (and the whole group)

Do not reference these in new code. Warn when a plugin decorator uses them.

Source: release notes 6.7.6.

## Removed Store-API `Cached*Route` Classes

All `Cached<Foo>Route` Store-API decorators are deleted in 6.7.0. Caching now happens via HTTP cache policies (6.7.6+) or route attributes. Do not scaffold new `Cached*Route` classes; do not extend the removed ones.

Source: release notes 6.7.0.

## ESI Header And Footer

6.7.0 renders header and footer through Symfony ESI.

- New route names: `frontend.header`, `frontend.footer`. Paths: `/_esi/global/header` and `/_esi/global/footer` (the paths changed in 6.7.1; 6.7.0 used `/header` and `/footer`).
- New entry templates: `@Storefront/storefront/layout/header.html.twig` and `.../footer.html.twig`.
- New blocks in `base.html.twig`: `base_esi_header`, `base_esi_footer`.
- ESI render errors now throw; they were silently swallowed before.
- Requires ESI support in the reverse proxy (Symfony HttpCache, Nginx SSI/ESI, or Varnish). Configure `/_esi/global/header` and `/_esi/global/footer` in the proxy.

Extension pattern: extend `header.html.twig` / `footer.html.twig` directly. Pass extra data via `StorefrontRenderEvent` or the `headerParameters` merge, not inline `base.html.twig` block overrides (those blocks are now empty).

Source: release notes 6.7.0, UPGRADE-6.7.md §6.7.0.1.

## Varnish, Fastly, WebScale

External HTTP-cache plugins hook the Shopware cache-tag system.

- WebScale, Fastly, and similar plugins clear tags to their proxy — they do not clear Varnish directly.
- Never confuse `cluster_setup` (Symfony cache clustering across nodes) with HTTP cache. They are separate systems.
- The Symfony HttpCache app inside Shopware and an external reverse proxy in front of it can both cache. Tag invalidation must reach both.
- Nitro (Nuxt), Varnish/Fastly at the edge, and Shopware's own Symfony cache are three separate cache layers when a headless storefront sits in front. Invalidating one does not invalidate the others.

## Invalidation Cost Is Real

A broad purge can create an origin miss burst; measure purge volume, cache hit rate, and origin latency instead of treating a private deployment's key count or delay as a universal threshold.

- Batch: keep delayed invalidation enabled in production (`delay_enabled: true` on 6.7, `delay > 0` on 6.6) so many small writes coalesce into one purge.
- Target tags to the changed dependencies. When complete invalidation really is required, batch to the provider's limits without silently dropping tags; plan for warm-up/origin capacity.
- Observe: alert on edge-purge count and origin request-rate step-changes; correlate with admin activity.

## `NavigationRoute` Cache Key Event

`NavigationRoute` caches category level per sales channel in 6.7.

- If a plugin changes cached category-level output by customer group, B2B context, or feature flag not already in the key, use `\Shopware\Core\Content\Category\Event\CategoryLevelLoaderCacheKeyEvent` to add that input or bypass this cache. Note `Category\Event\`, not `Category\SalesChannel\`; a wrong FQCN may register without ever receiving the dispatched event.
- Demonstrate different output sharing the same root/depth/sales-channel/language key before claiming stale or leaked navigation. Changes outside this cached loader may require a different cache boundary.

Source: [CachedDefaultCategoryLevelLoader::getCacheKey](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Content/Category/Service/CachedDefaultCategoryLevelLoader.php) and UPGRADE-6.7.md §6.7.2.0, §6.7.3.0.

## Message Queue For Cache Work

Cache invalidation runs on a scheduled task (`InvalidateCacheTask`) that must actually execute.

- Production must run CLI workers with explicit transports and a failure queue. Do not rely on the admin worker.
- Interval default is 5 minutes on 6.7 (was 20 seconds on 6.6). If you customize it, run the scheduled task at the same or faster cadence.
- Choose and test Elasticsearch outage behavior deliberately. `SHOPWARE_ES_THROW_EXCEPTION` trades visible failure against database fallback load; it already defaults to `1` in the 6.7.15.1 Elasticsearch package. Do not describe re-setting it as an additional hardening step.

Source: [InvalidateCacheTask::getDefaultInterval](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Adapter/Cache/InvalidateCacheTask.php). Scheduler cadence and transport consumers must both support the chosen interval.

## Source Anchors

- [HttpCacheKeyGenerator::generate/addCookies](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Adapter/Cache/Http/HttpCacheKeyGenerator.php), [HttpCacheVariantHeaders::HEADERS](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Adapter/Cache/Http/HttpCacheVariantHeaders.php), and [CacheHeadersService](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Adapter/Cache/Http/CacheHeadersService.php).
- [CacheResponseSubscriber](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Adapter/Cache/Http/CacheResponseSubscriber.php), [CachePolicyProvider::getPolicy](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Adapter/Cache/Http/CachePolicyProvider.php), and [default policies](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Resources/config/packages/shopware.yaml).
- [CacheRelevantRulesResolver](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Adapter/Cache/Http/CacheRelevantRulesResolver.php), [HttpCacheCookieEvent](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Adapter/Cache/Event/HttpCacheCookieEvent.php), and [hash-validation regression cases](https://github.com/shopware/shopware/blob/v6.7.15.1/tests/unit/Core/Framework/Adapter/Cache/Http/CacheResponseSubscriberTest.php) (`testCacheHashValidation`).
- [6.7 upgrade guide](https://github.com/shopware/shopware/blob/v6.7.15.1/UPGRADE-6.7.md) for removed/deprecated cache symbols and ESI changes; [Elasticsearch defaults](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Elasticsearch/Resources/config/packages/elasticsearch.yaml).
