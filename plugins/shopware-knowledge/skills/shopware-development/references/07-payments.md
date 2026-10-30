# Payments

Index: non-negotiables, handler model, architecture, data collection, correctness, state sync, webhooks, saved methods, recurring/headless, validation.

## Non-Negotiables

- Never receive, store, or forward raw PAN, CVV, bank account, or routing data through your server.
- Treat client-reported payment state, amount, and provider identifiers as hints only.
- Mark a payment as successful only after server-side provider verification or a valid signed webhook.
- Keep checkout request-path work minimal.
- Make webhook processing signature-verified and idempotent.
- Keep admin operations behind Admin API plus ACL.
- Keep logs payload-minimal and secret-safe.

## Handler Model

For Shopware 6.7, start from the official payment guide:

- use `AbstractPaymentHandler`
- register with the `shopware.payment.method` tag
- expect order-placement validation, but do not assume after-order payment entry points call `validate()`
- expect `finalize()` when `pay()` returns a redirect response
- keep `validate()` fast and deterministic
- keep `finalize()` idempotent
- treat `supports(...)` checks for refunds or recurring flows as version-sensitive and confirm them against the exact core behavior
- create the payment method in `install()`, set `afterOrderEnabled` when needed, and deactivate on uninstall instead of deleting
- keep remote webhook/key provisioning out of generic `activate()` or `install()` side effects; prefer explicit idempotent admin setup actions or commands with recovery on failure

For 6.6, open the archived guide first and verify the exact handler surface before reusing 6.7 assumptions.

## Recommended Architecture

Split responsibilities:

- payment handler
  Thin request-path entry point.
- payment orchestration service
  Intent/session creation, provider calls, retries, state normalization.
- transaction state sync service
  One place for Shopware transaction state transitions.
- webhook controller
  Raw body signature verification and fast acknowledgement.
- async processor
  Heavy webhook and reconciliation work.
- admin maintenance routes
  Webhook setup, diagnostics, manual repair actions.

## Data Collection

Use one of these patterns:

- provider-hosted redirect page
- provider-hosted fields
- provider JS tokenization

Persist only tokens or non-sensitive display metadata when the feature truly needs it.

Example:
- redirect flow
  `pay()` creates or updates the provider intent and returns a redirect, `finalize()` verifies the result, and a signed webhook or server-side verification remains the final authority.
- tokenized direct flow
  storefront JS sends only the provider token, while the backend attaches it to a server-created intent and verifies amount, currency, and merchant context server-side.

Code shape example:

The 6.7 signature is fixed by `AbstractPaymentHandler::pay()`. Do not use `AsyncPaymentTransactionStruct` or `SalesChannelContext` here — the former was removed in 6.7.0.0 and the latter is not passed; a mismatched signature is a PHP fatal, not a soft warning.

```php
// Bad: browser token and request amount become local payment truth
public function pay(
    Request $request,
    PaymentTransactionStruct $transaction,
    Context $context,
    ?Struct $validateStruct
): ?RedirectResponse {
    $this->transactionRepository->update([[
        'id' => $transaction->getOrderTransactionId(),
        'stateId' => 'paid',
        'customFields' => ['provider_token' => $request->request->get('token')],
    ]], $context);

    return new RedirectResponse($request->request->get('successUrl'));
}
```

```php
// Preferred: persist operation intent, verify later, keep local state server-authoritative
public function pay(
    Request $request,
    PaymentTransactionStruct $transaction,
    Context $context,
    ?Struct $validateStruct
): ?RedirectResponse {
    $orderTransactionId = $transaction->getOrderTransactionId();

    $this->paymentOperationService->prepare(
        $orderTransactionId,
        $this->paymentInput->validatedProviderToken($request),
        $context
    );

    return new RedirectResponse(
        $this->paymentOrchestrator->createRedirect($orderTransactionId, $context)
    );
}
```

The input resolver above is plugin-owned: validate the provider's token format without destructive normalization (`getAlnum()` can corrupt valid tokens), and resolve ownership server-side. The handler receives a transaction struct, request data, context, and optional validated struct; load the order detail it needs itself.

## Correctness Rules

- Use `validate()` for prepared-payment invariants that exist **before the order does**: cart currency and amount, server-side prepared references, and merchant-account checks. `validate()` runs before the order is persisted, so there is no `orderTransactionId` and no `order_transaction` row yet — a guard on those either dead-codes or blocks every order placement. Bind transaction-scoped invariants in `pay()`, which receives `PaymentTransactionStruct::getOrderTransactionId()`.
- `validate()` is **not** called on after-order payment flows (`/store-api/handle-payment`, used for retries and payment-method changes when `afterOrderEnabled` is on). Re-assert any security-relevant invariant in `pay()` rather than relying on `validate()` alone.
- Key provider operations by `orderTransactionId` or a provider-side unique reference.
- Persist an operation row before outbound provider calls and back it with unique indexes so retries return the previous result instead of duplicating side effects.
- Only verified payment handlers, verified callbacks, or reconciliation services may create authoritative local transaction rows or mark payment as successful.
- Make capture, refund, and webhook processing idempotent with persisted operation state and unique keys.
- Keep state transitions monotonic. Do not let a later duplicate event regress a final state.
- Correlate provider state to the correct Shopware transaction before changing anything.

## State Sync Service

- Route all transaction-state changes through one internal sync service.
- Apply Shopware transaction state handlers there, not ad hoc in controllers, handlers, or webhook code.
- Keep derived states such as partial refund vs full refund consistent.
- Treat disputes and chargebacks as distinct financial events, not as refunds.

## Webhooks

- accept only the expected method and content type
- verify signatures on the raw request body
- use constant-time comparison and the exact header/body canonicalization required by the provider
- check timestamp freshness or replay window
- allowlist event types
- persist provider event IDs with uniqueness so duplicate deliveries can acknowledge 2xx without reprocessing
- support secret rotation where the provider workflow needs active plus previous webhook secrets
- return quickly after enqueueing or persisting idempotency state
- do not perform slow provider reconciliation inline unless unavoidable
- keep provider verification helpers timeout-bound and audit-logged
- keep webhook management behind Admin API plus ACL; webhook endpoints are not admin endpoints
- build finalize or return URLs from trusted configuration or sales-channel domain data, not raw host headers from the incoming request

## Saved Methods and Refunds

- Enforce token ownership by customer and sales-channel context.
- Use provider tokens, not sensitive account data.
- Store local vault metadata explicitly: customer, sales channel, payment method, provider references, masked display metadata, status, and timestamps.
- Disable or soft-delete local records after provider-side detach where applicable.
- Align refunds with Shopware's order transaction model instead of inventing a parallel state machine.
- Trigger refunds from admin or automation flows, not storefront endpoints.
- Support partial refunds only with explicit idempotency and reconciliation rules.

## Recurring PSP Boundaries

- Load `15-subscriptions-and-recurring-payments.md` when subscription lifecycle, renewal scheduling, or multi-plugin recurring flow is in scope.
- Treat saved-card settings routes, recurring-preference AJAX routes, and subscription payment-method change routes as part of the payment trust boundary.
- Enforce ownership on saved cards, provider-choice records, and subscription-linked payment-method mappings by customer and sales-channel context.
- Keep provider recurring references scoped to the correct order transaction or local vault record and persist them only when the renewal flow truly needs them.
- Make finalize, recurring charge, and webhook flows agree on one authority for marking payment success.
- Keep recurring-operation identifiers idempotent across retries so duplicate task runs or duplicate callbacks cannot create duplicate provider side effects.
- If a subscription plugin persists a provider-specific choice, require the save step to be atomic with the payment-method change or clearly recoverable after failure.
- Review subscription-side helper endpoints with the same rigor as payment handlers, because they often decide which saved method will be charged later.

## Headless and Hosted Payment Contracts

- Load `16-headless-and-composable-frontends.md` when a separate frontend repo, composable checkout, or SDK package participates in the payment flow.
- Payment-link, hosted-checkout, or wallet-init routes must use trusted configured return URLs. Never accept success, failure, or callback targets from browser request bodies as authoritative.
- Do not charge the provider first from browser-authored headless payloads and then let Shopware discover the authoritative order state later. Re-establish server authority before money movement or local paid-state writes.
- Browser-authored transaction IDs, vault IDs, or provider references are hints only until the backend resolves customer ownership and provider state.

## Performance and Observability

- Do not block checkout on slow provider calls that can be verified later.
- Centralize provider HTTP clients with timeouts and safe retry policy.
- Reuse shared HTTP clients; do not instantiate clients per request.
- Add circuit-breaker behavior when provider slowness can exhaust workers or PHP-FPM capacity.
- Log correlation IDs, order transaction IDs, and provider references, not full payloads.
- If support needs recurring diagnostics, expose concise internal audit metadata instead of raw webhook bodies or full PSP responses.
- Store an internal audit trail when the payment domain needs long-lived supportability.
- If the support workflow needs it, expose a concise admin timeline or order detail panel based on audit data, not raw provider payloads.
- Track metrics when scale warrants it: invalid signatures, retries, refund failures, timeout rates, and queue backlog.

## Minimum Validation

- checkout pay/redirect/finalize path
- direct-pay path if present
- `validate()` success and failure for prepared payment invariants
- invalid or replayed webhook rejection
- duplicate webhook idempotency
- refund/capture retry safety
- saved-method ownership enforcement
- recurring charge or subscription payment-method change authority if present
- concurrency between admin refunds and webhook deliveries
- degraded-provider load behavior so timeouts and circuit breakers do not starve checkout workers

Cross-reference example:

```text
If the payment issue is really caused by collector or processor ordering, move the cart behavior into 18-cart-and-checkout-pipeline.md and keep only the payment authority rule here.
```

## 6.7 Payment Handler Contract

`AbstractPaymentHandler` consolidates five legacy interfaces:

- `SynchronousPaymentHandlerInterface`
- `AsynchronousPaymentHandlerInterface`
- `PreparedPaymentHandlerInterface`
- `RecurringPaymentHandlerInterface`
- `RefundPaymentHandlerInterface`

All five were deprecated in 6.6 and **removed in 6.7.0.0**. New payment plugins extend `\Shopware\Core\Checkout\Payment\Cart\PaymentHandler\AbstractPaymentHandler`. Implement the abstract `pay()` and `supports()` methods; override these optional hooks only for supported capabilities:

- `finalize()`
- `validate()`
- `recurring()`
- `refund()`

`supports()` gates recurring / refund / partial-refund flows; do not advertise a capability that its hook does not implement.

Register with a single DI tag: `shopware.payment.method`. Drop `.sync`, `.async`, `.prepared`, `.recurring`, `.refund` tags.

For `pay()`, resolve order details from the transaction struct's ID; the full order is not injected. Other hooks have their own signatures (for example pre-order validation receives cart/context data); inspect the exact base method before implementing it.

Source: release notes 6.7.0; developer.shopware.com/docs/guides/plugins/plugins/checkout/payment/add-payment-plugin.html.

### `technicalName` Discipline

Payment method `technicalName` is non-nullable in 6.7 (auto-migrated). Always set a plugin-prefixed value:

```php
$paymentMethodData = [
    'handlerIdentifier' => MyPaymentHandler::class,
    'technicalName' => 'my_plugin_credit_card',  // required, plugin-prefixed
    // ...
];
```

If a plugin ships without `technicalName`, 6.7 assigns `temporary_<id>` — you lose stable reference for the method.

### SwagPayPal 6.7 Reference Architecture

Model complex payment plugins on the SwagPayPal 6.7 refactor:

- Single `AbstractPaymentMethodHandler` base class.
- One subclass per payment method (Credit Card, PayPal, Pay Later, etc.).
- Three lifecycle methods define the contract: `pay()`, `finalize()`, `executeOrder()`.
- Within that plugin's extension contract, override `executeOrder()` for custom logic rather than copying its shared `pay`/`finalize`. This is SwagPayPal architecture, not a requirement for every PSP.
- Remove any references to deleted `AbstractPaymentBuilder` — replace legacy patch builders with standardized methods.

Source: shopware.com/en/news/optimizing-the-paypal-payment-handler-for-6-7-release/.

### Order `primaryOrderTransaction`

Since 6.7.1, `Order::primaryOrderTransaction` replaces `.transactions.first()`. The migration backfills existing orders. `OrderConverter` still puts the primary first in the collection for BC, but new code should read `order.primaryOrderTransaction`.

Same rule for `Order::primaryOrderDelivery`.

Source: release notes 6.7.1, UPGRADE-6.7.md §6.7.1.0.

## Cart Token vs Context Token

A common failure mode on shipping-quote and cart-preview routes.

- A plugin-defined `sw-cart-token` GET parameter (there is no such platform parameter in core) that overrides the cart token without overriding the context token loads the correct cart items but **evaluates rules against the wrong context**. This surfaces as: only shipping methods available for the calling context are visible, but they are crosschecked against a different cart — producing wrong or missing shipping method options.
- The correct pattern: use the `sw-context-token` HTTP header to override the context. Both cart and context resolve consistently from the same token.
- Never accept cart-token override via query string for state-mutating routes. If a wishlist or shared-cart flow really requires it, document the constraint and gate the route with signed URLs plus expiration.

Source: matching `SalesChannelRequestContextResolver`, `CartService`, and shipping-method route; trace both cart and context resolution for custom token overrides.

## Middleware Retry = Duplicate Orders

When duplicate orders appear, trace browser, middleware, proxy, and backend retries before assigning a cause.

- Verify: what does the middleware do when the Shopware /store-api/checkout/order call returns a 5xx? A 4xx?
- Common wrong: retry on any non-2xx.
- A network timeout or 5xx may occur after persistence or charging. Treat that result as unknown, not as proof the operation failed. Reconcile using a durable operation identity before retrying; retry policy alone cannot prevent duplicates.
- The stock `checkout/order` flow does not provide a general client-key idempotency contract. An adapter that needs retry safety must enforce durable uniqueness, serialize competing attempts, and reconcile completed or unknown operations rather than merely checking then writing.

Related: see `15-subscriptions-and-recurring-payments.md` and `16-headless-and-composable-frontends.md` for the multi-repo triangulation pass on this.

Source: matching `CheckoutOrderRoute`, `CartOrderRoute`, and provider operation contract.

## External API In Cart (Tax, Shipping, Personalization)

Keep remote I/O out of repeatable processors. If a collector requires external tax/shipping data, derive deduplication, freshness, invalidation, key inputs, timeout, and final-order verification from the actual provider contract; see [24](24-external-api-caching-in-cart.md). Never cache a charge or other financial mutation as though it were a read.
