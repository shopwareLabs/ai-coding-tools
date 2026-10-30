# Quality and Operations

Index: security, external APIs, observability, cache/queue/index operations, testing/CI, store readiness, failure modes, scheduled work.

## Security Baseline

- Escape output by default and treat rich HTML as hostile unless it is sanitized.
- Prefer DAL to reduce injection risk. If raw SQL is necessary, bind every parameter.
- Treat any URL ingestion, remote file import, or webhook callback target as SSRF-sensitive: validate scheme and host, block private IP ranges, apply timeouts, and cap payload size.
- Use the official request-authenticity protections for storefront or admin-initiated write flows where the platform expects them.
- Enforce ACL for admin operations and ownership checks for storefront or Store API operations.
- Distinguish browser-write routes from server-to-server endpoints. Browser-initiated writes need platform request protection; webhooks and signed callbacks replace CSRF with sender authentication, replay defense, and idempotency.
- Never commit secrets. Treat system configuration values, API keys, and provider tokens as sensitive and keep them out of logs.
- Never set `verify => false` or equivalent TLS-disable flags in production HTTP clients.
- State-changing customer-facing endpoints should be POST-only and protected against IDOR or ownership bypass. Do not expose mutations over GET.
- Do not log tokens, context tokens, provider responses, or payment payloads to the browser console or client-side telemetry by default.
- Do not treat `localStorage`, `sessionStorage`, or other browser-persisted values as authoritative payment, vault, or ownership state.

## External API Resilience

- Timeouts are mandatory.
- Use circuit-breaker or graceful-degradation behavior when a dependency can affect storefront, checkout, or admin usability.
- Favor queue-first synchronization and retries for non-interactive work.
- Handle provider outages explicitly rather than leaking an unhandled exception. Use a valid cached result or approved fallback where safe; block checkout with an actionable error when authoritative totals or payment status cannot be established.
- Public callback or authorization endpoints need explicit hardening: signed tokens, bounded input, rate limiting, and narrow purpose.

Example patterns:

```php
// Bad: inline provider call in checkout path with no timeout or fallback
$quote = $this->shippingClient->fetchRates($cartPayload);
$cart->setExtension('shippingQuote', $quote);
```

```php
// Preferred: bounded timeout plus graceful fallback or cached quote
$quote = $this->shippingQuoteService->resolveQuote($cartContext);
if ($quote !== null) {
    $cart->setExtension('shippingQuote', $quote);
}
```

### Shipping and Tax Notes

- Cache or decouple shipping-rate reads where the provider/business contract permits it; do not submit an order without a valid required rate merely to avoid blocking.
- Keep shipping method technical names and config migrations stable.
- Bound external tax reads with timeouts and a provider-derived freshness/failure policy; see [quote caching](24-external-api-caching-in-cart.md). Reporting/commit side effects need idempotency rather than ordinary response caching.
- Push reporting and other tax side effects into async processing.

## Observability

- Use structured logging with correlation IDs and actionable context.
- Log failures, retries, and state changes without dumping full request or response payloads.
- Redact tokens, signatures, secrets, and PII by default.
- Keep a lightweight audit trail for merchant support, but do not turn application tables into an unbounded log sink.
- If the domain stores order snapshots, cart snapshots, or provider payloads, keep only the minimum fields needed for support and reconciliation.
- Review recurring-payment and webhook logs specifically for leaked provider tokens, card identifiers, customer identifiers, signatures, and raw payload bodies.

## Cache, Queue, and Index Operations

- Treat cache variation, queue backlog, and indexer pressure as first-class rollout risks for Shopware 6.7 plugin changes.
- For cache-sensitive releases, verify anonymous/default, `cart-filled`, and `logged-in` state behavior explicitly because Shopware's HTTP cache and reverse proxies key off `sw-cache-hash` and invalidation states.
- Do not add cookies, cache-relevant headers, or session writes casually on storefront pages that should stay Varnish-safe.
- Use explicit transports and failure handling for production work. Doctrine/MySQL can be appropriate at modest load; evaluate a dedicated broker when measured contention, throughput, or isolation needs justify it. Check backend-specific claim/redelivery settings and supervision.
- A queue failure path is part of the design. Configure `failure_transport`, retries, and operator commands before rollout, not after the first stuck batch.
- Watch index rebuild cost after mapping or indexer changes: reindex duration, queue growth, DB load, and search fallback behavior.

Example patterns:

```yaml
# Preferred: explicit production-oriented transport split
framework:
  messenger:
    failure_transport: failed
    transports:
      async: '%env(MESSENGER_TRANSPORT_DSN)%'
      low_priority: '%env(MESSENGER_TRANSPORT_LOW_PRIORITY_DSN)%'
      failed: '%env(MESSENGER_TRANSPORT_FAILURE_DSN)%'
```

```text
Good cache rollout check:
- warm the changed page anonymously
- verify no new plugin cookie is set on the cacheable response
- verify cart-filled or logged-in state changes only the intended variant
- verify invalidation after a relevant entity update
```

## Testing and CI

- Unit-test core services.
- Integration-test DAL definitions, migrations, and critical flows.
- Use Store API or HTTP-level tests for custom routes and customer-facing API behavior.
- Use reusable fixtures or builders when repeated setup would otherwise hide intent.
- For frontend-heavy extensions, add smoke checks and compare Lighthouse results where performance risk is real.
- Improve PHPStan incrementally instead of freezing a huge baseline forever.
- Keep coding standards aligned with Shopware conventions.
- Do not ship or leave behind `die`, `exit`, or `var_dump`.
- Validate and package distributable extensions with Shopware CLI when the project uses it.
- For 6.7.3+ translation work, add `bin/console translation:lint-filenames` and `bin/console translation:validate` to CI when possible.
- Run at least one container-compile or boot-path check when service wiring, decorators, handlers, or scheduled tasks changed.
- For cache, queue, or indexing work, add one targeted operational check: cache-hit behavior, worker consume path, failed-message command, or `dal:refresh:index` on a safe environment.

Concrete CI example:

```text
Good: after changing services.xml, a handler, and a scheduled task, run targeted tests plus one container boot or compile-path check instead of relying only on php -l.
```

## Store Readiness

- Test against the highest supported Shopware version before release.
- Keep the binary clean: do not ship unnecessary tests, CI config, editor settings, lock files, or other forbidden packaging artifacts.
- Register storefront cookies with the cookie consent manager when the feature sets them.
- For third-party storefront widgets or embeds, verify consent impact, keyboard/focus/status behavior, and ask for a VPAT or vendor accessibility statement when the feature is accessibility-sensitive. See `17-accessibility-and-template-best-practices.md` for the storefront audit baseline.
- Use store quality guidelines and store review errors as release gates, not as cleanup after the implementation is done.
- Ship a plugin icon at `src/Resources/config/plugin.png`. `shopware-cli extension validate` reports its absence as an error.
- Ship new Flow Builder flows **inactive**. `flow.active` defaults to `false` in the DAL and the database; don't set `active: true` in a migration or installer. A flow that sends mail or changes data must be switched on by the merchant.
- Write a short note for the Store tester. Say what is inactive by default, where the feature shows up, what it does **not** need (keys, accounts, theme changes), and which less obvious features to try. "I installed it and nothing happened" is the most common avoidable rejection.

### Store Listing And Uploads With `shopware-cli`

`shopware-cli account producer extension …` manages the Store side from the repository:

| Command | Effect |
| --- | --- |
| `account producer extension info pull <path>` | Writes the current listing (texts, FAQ, images, icon) into the extension's `.config/shopware-extension.yml` and `src/Resources/store/` |
| `account producer extension info push <path>` | Pushes that local config to the listing. Does **not** upload a version |
| `account producer extension upload <zip>` | Uploads a new version and, unless `--skip-for-review-result`, waits for the automated code review |
| `account producer extension list` | Lists your extensions |

- Log in once with `shopware-cli account login`; in CI set `SHOPWARE_CLI_ACCOUNT_CLIENT_ID` / `SHOPWARE_CLI_ACCOUNT_CLIENT_SECRET` (created in the Shopware Account under the extension partner's development settings).
- Observed behaviour of `info push` (0.19.x): listing images are **replaced**, not merged, and the Store name and short description are taken from `composer.json` `extra.label` / `extra.description`. Keep those in sync before pushing, or a push overwrites texts edited in the Account.
- Gate push and upload jobs behind tags, and check the tag against the `composer.json` version before uploading.

## Common Failure Modes

Treat these as explicit regression checks:

- external HTTP calls in cart, checkout, or login without tight timeouts and fallback
- rendering user-specific HTML into cacheable responses
- DAL `search()` inside loops or other N+1 query shapes
- unbounded criteria queries or large blob hydration without batching
- broad cache invalidations on high-frequency events
- missing ACL or ownership checks
- logging secrets, tokens, or raw payloads
- browser console or client telemetry logging of tokens, context tokens, or payment payloads
- exposing Admin API credentials or private third-party keys to the storefront
- browser storage used as an authoritative source for saved-method, vault, or payment identity
- browser routes that disable CSRF without replacing it with the right security model
- GET endpoints that mutate customer data or order state
- internal plugins calling the shop's own HTTP API instead of shared services
- writes or recalculations triggered from storefront render events or read routes
- route duplication that drops core ACL or validation
- custom cookies or session writes added to cacheable storefront routes
- cacheable routes rendering customer-specific markup instead of isolating the fragment
- scheduled tasks with tiny intervals, unbounded scans, or duplicate handler registration
- scheduled tasks, reminders, or renewal workers that branch on translated state names instead of technical names
- invalid DAL association usage such as treating `customFields` like a normal association
- heavy blob hydration or full snapshot loading on large recurring batches without a clear need
- cache entries with unbounded growth because keys are serialized payloads and TTL is missing
- mutable operational flags stored in JSON payloads or custom fields and later queried at scale
- missing failure transport, retry strategy, or low-priority separation on production message queues
- indexer changes shipped without a bounded reindex plan or fallback check
- deep template copying instead of block extension
- copying core-only metadata into plugin code
- silent API contract changes without versioning or compatibility planning
- shipping dev artifacts or duplicated translation files in the plugin package

## Scheduled Tasks and Recurring Batches

- Batch due-item scans explicitly. Do not assume production data sets stay small.
- Keep loop control safe when external failures or partial processing happen. Do not advance business-critical schedule fields before success is known.
- Prefer technical names, stable IDs, or persisted state markers over translated labels in task logic.
- Avoid broad association trees in scheduled-task hydration unless every field is required for the batch decision.
- If a task stores snapshots or support data, put a bound on retention and growth.

## 6.7 Operational Defaults

### Shopware Usage Data Collection

In 6.7.15.1, `shopware.usage_data.collection_enabled` defaults to `true`, but `EntityDispatchService::dispatchCollectEntityDataMessage()` also checks accepted backend-data consent before dispatch. The flag alone does not prove collection is running or explain database load.

- If measured entity-sync load conflicts with operational requirements, review collection/consent and the task/queue path with the operator. Where disabling this collection is the chosen mitigation, the configuration is:

  ```yaml
  # config/packages/shopware.yaml
  shopware:
      usage_data:
          collection_enabled: false
  ```

- Verify new dispatches and already-queued work separately after changing it. Do not assume the switch removes pending messages or controls unrelated Analytics/GMV integrations.
- Catalog size alone supplies no universal disable threshold; correlate actual sync queries, queue pressure, and database metrics before attributing an incident.

Sources: [usage-data defaults](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Resources/config/packages/shopware.yaml), [EntityDispatchService](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/System/UsageData/Services/EntityDispatchService.php), and [CollectEntityDataTaskHandler](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/System/UsageData/ScheduledTask/CollectEntityDataTaskHandler.php). Earlier patches/6.6 may use different consent plumbing; inspect the installed version.

### Message Size Cap

Message-size enforcement is **off by default**: `shopware.messenger.enforce_message_size` is `defaultFalse()`, and the listener returns immediately unless it is true. `shopware.messenger.message_max_kib_size` (default 1024 KiB, introduced in 6.7.4) applies only once enforcement is enabled. Design messages to reference DB rows instead of carrying blobs regardless — a bigger limit is not a long-term fix.

Source: release notes 6.7.0, 6.7.4.

### `maintenanceIpWhitelist` → `maintenanceIpAllowlist`

Renamed from 6.7.13 for inclusive language. Update configs generated for 6.7.13+.

Source: release notes 6.7.13.

### `SHOPWARE_SKIP_WEBINSTALLER` For Read-Only FS

For PaaS deployments or read-only filesystems, set `SHOPWARE_SKIP_WEBINSTALLER=1` to bypass the web installer and lock file.

Source: UPGRADE-6.7.md §6.7.3.0.

### Elasticsearch Env Vars

- `SHOPWARE_ES_THROW_EXCEPTION` and `SHOPWARE_ES_USE_LANGUAGE_ANALYZER` both already default to `1`. Confirm an existing `.env` has not overridden them rather than treating setting them as a hardening step.
- Admin ES needs `ADMIN_OPENSEARCH_URL` **and** `SHOPWARE_ADMIN_ES_ENABLED=1`; then run `bin/console es:admin:index`. Omitting the URL leaves it non-functional.
- `ENABLE_OPENSEARCH_FOR_ADMIN_API` is a separate experimental **feature flag** (`default: false`) for routing Admin API entity searches through OpenSearch — not part of admin ES setup.

Full search/indexing details in `20-search-and-indexing.md`.

Source: developer.shopware.com/docs/guides/hosting/performance/performance-tweaks.html, release notes 6.7.5, 6.7.11.

### Performance Baseline

- Enable/test HTTP caching where responses can be safely shared; consider an external reverse proxy when traffic and infrastructure justify it.
- Redis can reduce DB contention for invalidation, number ranges, increments, and locks. Choose per subsystem/topology; MySQL remains a supported delayed-invalidation default, not a forbidden backend.
- Disable the Product Stream Indexer only after checking category-cache freshness and the installed invalidation path. Use DBAL for measured bulk-query bottlenecks only when bypassing DAL events/indexing/validation is intentional.
- Check target-version requirements for `group_concat_max_len` and SQL modes rather than applying database settings from another release blindly. For high-volume mail, assess `update_mail_variables_on_send: false` and async delivery against required behavior.
- Provision queue schema before disabling Messenger `auto_setup`; move sitemap scheduling to cron only with an owner and no duplicate scheduled execution.
- Tune OPcache, assertions, classmap/preload, compression, and dumped environment configuration for the actual PHP/runtime/deployment. zstd needs compatible extensions/readers on web and workers; benchmark it rather than declaring gzip invalid.

Sources: [Shopware performance guide](https://developer.shopware.com/docs/guides/hosting/performance/performance-tweaks.html) (match the installed release) and [6.7.15.1 cache config/defaults](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/DependencyInjection/Configuration.php).

### Frosh Tools Observability

`FriendsOfShopware/FroshTools` is optional in-admin observability when installed and compatible. Its queue-count endpoint can help:

- `GET /api/_action/frosh-tools/queue/list`
- Verify counters against the installed FroshTools version and actual transport; do not assume per-message-type counts are reliable across all 6.6/6.7 packages. Core CLI queue/task commands remain useful without the plugin.

Full patching/tooling details in `25-patching-and-dependency-tooling.md`.

Source: [FroshTools maintained capabilities](https://github.com/FriendsOfShopware/FroshTools#readme); inspect the installed tag for endpoint/counter implementation.

### Static Analysis Baseline

Resolve compatible PHPStan, framework extensions, and formatter versions from the project's lock/config and supported PHP floor. The matching core tag is useful compatibility evidence, not a universal plugin tool pin. A PHPStan major upgrade can require config/rule changes.

Scope analysis to owned code (including tests where configured), raising memory only as needed. Incremental per-plugin remediation is often practical; a project-wide change is valid when intentionally scoped and tested.

Full setup in `25-patching-and-dependency-tooling.md`.

Source: [6.7.15.1 development constraints/scripts](https://github.com/shopware/shopware/blob/v6.7.15.1/composer.json); use the matching 6.6 tag for a 6.6 project.

### MySQL Dump Canonical Form

```bash
mysqldump --routines --hex-blob --single-transaction --no-tablespaces db > dump.sql
```

This is an InnoDB-oriented example, not a universal backup command. Review concurrent DDL, other table engines, routines/events, privileges, and restore requirements. Preserve or deliberately remap `DEFINER` according to target accounts/security semantics; do not strip it with a broad regex. See [dump options and restore checks](25-patching-and-dependency-tooling.md#mysql-dump-canonical-form).

Source: [MySQL 8.4 mysqldump](https://dev.mysql.com/doc/refman/8.4/en/mysqldump.html).
