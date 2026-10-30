# External API Caching In Cart

Contents: [scope](#cache-contract), [keys](#cache-key-components), [freshness](#ttl-rules), [invalidation](#admin-invalidation-endpoint), [order validation](#live-check-on-order-placement), [callbacks](#provider-side-auto-invalidation), [audit](#auditing-an-existing-cache).

## Why This Is A Correctness Boundary

Shopware cart flows can recalculate repeatedly. Invocation counts depend on the calling flow and extensions; a collector is not guaranteed to run once per HTTP request. Reuse eligible read-only quote data within `CartDataCollection` when its inputs are unchanged, and consider cross-request caching when provider validity and the business freshness contract allow it.

Repeated lookups can add latency or yield inconsistent intermediate values. Conversely, caching without complete inputs or adequate freshness can return the wrong tax, shipping, or price. Keep processors deterministic over prepared collector data; do not hide charging, reservation, or reporting side effects in cart calculation.

## Cache Contract

Classify the operation before choosing storage:

1. **Read-only quotes/lookups:** reuse only for equivalent inputs and within provider/business validity. If reuse is forbidden or no valid value exists, perform a bounded live lookup or block with an actionable error.
2. **Payment, capture, booking, reservation, reporting:** do not treat response caching as idempotency. Use a stable business-operation key, durable state, and provider reconciliation; see [Messenger recovery seams](messenger-handlers.md#durable-and-concurrent-idempotency) and [payments](07-payments.md).
3. **Errors/timeouts:** do not cache them as successful quotes. A documented short negative-cache/circuit-breaker policy can bound repeated failures, but must distinguish failure from a valid zero tax/rate result and allow recovery. A timeout after a side effect is an unknown outcome, not a safe retry signal.
4. **Cross-request data:** use deterministic scoped keys, a bounded lifetime appropriate to the data, and invalidation/revalidation for changes not captured by key variation. Manual admin invalidation is optional operational tooling, not a universal requirement.

## Cache Key Components

A correct key represents every input that determines the **used fields of this provider's response**, unless another proven invalidation/versioning boundary covers it. Canonicalize before hashing; there is no universal field order or seven-field list.

- Scope by provider account/tenant, API/config revision, and environment where those can change the answer. A sandbox quote must not satisfy a production lookup.
- Tax examples: origin/destination jurisdiction, line tax codes, taxable amount/discounts, shipping tax treatment, currency, and customer exemption identity/version when the API uses them.
- Shipping examples: origin/destination, package weight/dimensions, contents, service level, currency, and negotiated carrier account when applicable.
- Price/eligibility examples: provider product identity, quantity, effective date, audience/customer contract, sales channel, and currency when applicable.

Sort unordered collections and normalize units/decimal representations without discarding provider-significant differences. Avoid raw addresses, secrets, or entire serialized cart blobs in cache keys/logs. Include cart/customer identity only when the result is actually specific to it; hashing an incomplete input set does not make it correct. Key variation, expiry, and explicit invalidation/revalidation are complementary refresh mechanisms.

## TTL Rules

- Derive lifetime from provider expiry/quote validity, rate or exemption update cadence, and the merchant's tolerated staleness. There is no universal eight-hour default.
- Store enough metadata to validate freshness (`fetchedAt`, provider expiry/version or quote reference as applicable). Expire no later than the permitted validity window; bypass/refresh when the provider requires current validation.
- Decide whether stale-on-error is permitted for this field/operation. Do not silently reuse expired tax, price, or shipping data when the domain contract requires a current value.
- Bound storage growth and use the selected cache backend's expiry/pruning behavior. TTL is a freshness boundary, not proof that every backend physically deletes expired entries immediately.

## Admin Invalidation Endpoint

First prefer automatic scoped invalidation on provider-account/config changes and relevant local writes. If support needs manual invalidation, an Admin API action can be useful, for example:

- `DELETE /api/_action/<plugin>/cache` — full cache invalidation for the plugin.
- `DELETE /api/_action/<plugin>/cache/{customerId}` — per-customer invalidation.

Guard such actions with Admin API authentication and `_acl` for a plugin-owned permission (e.g., `plugin.<name>.cache_clear`). Do not expose administrative cache clearing through public cart routes. Use namespaced pools/tags or versioned keys so a provider purge does not flush unrelated shop data.

Optional UI actions when they solve a support workflow:

- One button on the customer detail page: "Clear cached <provider> data for this customer".
- One button in the plugin config: "Clear all cached <provider> data".

## Live Check On Order Placement

Follow the provider's quote/commit contract at final order submission; do not invent a universal 30-minute threshold:

1. Compute the cache key for the final cart.
2. Check expiry, provider quote/reference validity, and any required current eligibility validation. Refresh only when that contract requires it, with bounded I/O and no duplicated side effects.
3. If authoritative totals or availability change, recalculate and require the appropriate customer confirmation/error before order persistence. If validity cannot be established, use an explicitly approved fallback or block submission; do not silently accept stale totals.

This closes the "cart cached at 5pm, order placed at 8am, tax-exemption changed overnight" case.

## Extendability

Design the caching layer so a downstream plugin can decorate it.

- Separate the external client from quote policy/cache storage using injected services or decoration. Arbitrary DI tags do not provide behavior unless a compiler pass consumes them.
- Expose a key/freshness seam when downstream extensions legitimately add value-determining inputs (e.g., a promotion group).

A caller embedded in a calculator can make policy replacement difficult. Extract the smallest useful seam for the actual integration; an admin endpoint or configurable TTL alone does not fix incomplete keys or unsafe caching of mutations.

## Provider-Side Auto-Invalidation

The ideal case is: the provider notifies Shopware when a customer's status changes (e.g., TaxJar customer becomes tax-exempt), and Shopware invalidates the affected keys.

- Where supported, use a dedicated callback authenticated by the provider's signature scheme, timestamp/replay checks, and durable event idempotency. Resolve affected account/customer keys from trusted local mappings. The provider does **not** need a merchant Admin API access token; an Admin API URL prefix is neither required nor sufficient for callback authenticity.
- An API-scoped callback may deliberately opt out of merchant bearer authentication with `auth_required: false` only when its own authentication runs before any effect. Do not remove authentication from ordinary admin actions or give the callback general administrative capabilities.
- Not all providers push status changes. Document the resulting freshness gap and select bounded expiry, polling/revalidation, or a required live check according to the provider contract; manual clearing is optional.

## Auditing An Existing Cache

The contract above is for a plugin with no cache. Auditing one that already has a cache is a different exercise, and checking the key against a fixed list is not enough — the list does not know what this provider returns.

Work from the payload, not from the list:

1. **Enumerate the fields of the cached payload.** What does the provider actually return, and which of those values does the plugin use?
2. **For each returned field, ask what inputs determine it.** A tax rate depends on delivery address, product tax class, and customer exemption status. A shipping quote depends on weight, dimensions, and origin.
3. **Name value-determining inputs absent from the key and not covered by proven invalidation/versioning.** Demonstrate the stale-hit path: change the input, reuse the old answer.
4. **Check the inverse too** — inputs in the key that determine nothing. These fragment the cache and cost hit rate without buying correctness.

The output is a list shaped "field X depends on input Y; Y is not in the key," which is directly actionable and survives the provider adding fields later.

## Review Prompts

When reviewing a plugin that calls an external API in cart:

- Is this operation an eligible read, a side effect, or an error/unknown outcome?
- Which used response field depends on which inputs, and how are key variation and invalidation covering them?
- Is lifetime bounded by provider validity and the business freshness contract? What happens on expiry/outage?
- If manual invalidation exists, is it authenticated, ACL-protected, and scoped?
- Does final submission satisfy the provider's current validation/quote-commit contract?
- Can a downstream plugin extend the cache-key builder or replace the caller?
- Does provider-side status-change notification exist? If not, is that gap documented?

## Source Anchors

- [Shopware Processor](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Checkout/Cart/Processor.php) and [CartCalculator](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Checkout/Cart/CartCalculator.php): collector/processor invocation and recalculation, not a mandatory cross-request cache contract.
- [Symfony HttpClient caching](https://symfony.com/doc/7.4/http_client.html#caching-requests-and-responses): HTTP caching is a read-response mechanism, not payment idempotency.
- [ApiAuthenticationListener](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Api/EventListener/Authentication/ApiAuthenticationListener.php): merchant authentication and `auth_required`. Provider verification must be implemented separately.
- Record the actual provider API/version, response fields, expiry/signature/idempotency documentation, and adapter call site in each implementation/review. Those contracts determine the concrete key/TTL/callback policy; Shopware core does not prescribe one for all providers.
