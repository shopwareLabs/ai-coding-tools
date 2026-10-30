# Subscriptions and Recurring Payments

Index: review boundaries, lifecycle, recurring orders, saved methods, provider truth, data exposure, multi-plugin triangulation, validation prompts.

## Core Review Boundaries

Establish these boundaries before judging code quality:

- who owns the subscription, saved method, address, line item, or provider-choice record
- which route or handler is allowed to mutate it
- whether the mutation is read-only or state-changing
- which system is authoritative for amount, currency, payment state, and recurring references
- what happens on retries, duplicate events, partial failures, or deleted saved methods

If any of those answers are unclear, keep exploring before recommending fixes.

## Subscription Lifecycle Rules

- Customer-facing lifecycle changes such as cancel, pause, reactivate, skip, or schedule changes require authentication, ownership checks, and an appropriate state-changing method (`POST`, `PATCH`, or `DELETE`), never `GET`.
- Do not load subscriptions by raw UUID alone on storefront or Store API mutations. Filter by the current customer and, when relevant, by sales channel.
- Public detail or helper routes must not widen subscription discovery if the same identifier can later be used to mutate lifecycle state.
- Validate interval changes against the current plan. Do not accept an interval ID just because it exists.
- When a route forwards to a state handler or service, keep the ownership check at the entry point instead of assuming downstream services will enforce it.

## Recurring Order Correctness

- Recalculate renewal totals from the active sales-channel context. Do not blindly reuse the original order transaction amount when shipping, discounts, quantities, payment method, or currency may have changed.
- Do not advance `nextSchedule` before the renewal is allowed and the new order or transaction is actually created.
- Make retries and duplicate task runs idempotent with persisted operation state or other durable uniqueness.
- If renewal creation can partially fail, explain exactly which fields move first and how the code avoids skipping a cycle or creating duplicate orders.
- Use technical names or immutable state identifiers in renewal logic, reminders, and schedulers. Do not branch on translated labels.

## Saved Payment Methods and Provider Choice

- Enforce ownership on saved cards, vaulted tokens, provider-specific card-choice records, and subscription payment-method updates.
- Scope saved methods by customer and sales channel when the business model supports multiple storefronts or PSP accounts.
- Treat sidecar storefront or AJAX routes for saved-method changes as part of the payment trust boundary, not as low-risk UI helpers.
- If a subscription plugin persists a provider-specific choice, verify that the save step is atomic with the payment-method change or clearly recoverable after failure.
- When a saved method is deleted or detached, make the failure path explicit for future renewals.

Example patterns:

```php
// Bad: storefront mutation by raw subscription UUID
$subscription = $this->subscriptionRepository->search(new Criteria([$subscriptionId]), $context)->first();
$subscription->setPaymentMethodId($newPaymentMethodId);
```

```php
// Preferred: customer- and channel-scoped lookup before mutation
// Precondition: the route requires an authenticated customer.
$criteria = new Criteria();
$criteria->addFilter(new EqualsFilter('id', $subscriptionId));
$criteria->addFilter(new EqualsFilter('customerId', $salesChannelContext->getCustomerId()));
$criteria->addFilter(new EqualsFilter('salesChannelId', $salesChannelContext->getSalesChannelId()));
```

Persist through the repository/service, not by mutating a hydrated entity alone; the bad example does not itself perform a DAL write.

## Provider Truth and Event Authority

- Client-reported payment success, transaction IDs, card IDs, or recurring references are hints only.
- Renewal and finalize flows must confirm provider state server-side or through a valid signed webhook before marking payment as successful.
- Webhook, finalize, and callback flows must be idempotent and bound to the correct Shopware transaction before any state change.
- Persist only the provider metadata needed for support or reconciliation. Avoid storing raw PSP payloads, duplicate tokens, or sensitive card metadata in plugin tables unless the feature truly requires it.

## Data Exposure and Snapshot Retention

- Treat `convertedOrder`, cart snapshots, and custom-field blobs as review surfaces. Check whether they duplicate payment metadata, tokens, addresses, or line-item data more broadly than needed.
- Review `ApiAware` on large or sensitive fields carefully. A broad snapshot field should not become storefront or Admin API output by accident.
- If the code logs provider responses, webhook bodies, or subscription snapshots, reduce the log shape to identifiers and redacted metadata.

## Multi-Plugin Triangulation

When the review spans a subscription plugin plus one or more payment plugins, add a dedicated cross-flow pass:

- map how `paymentMethodId`, saved-method IDs, provider references, and recurring flags move across repos
- verify that webhook or finalize handlers can still correlate back to the correct subscription renewal
- verify that saved-method replacement or deletion does not silently break later renewals
- verify that payment failure, retry, and manual recovery paths keep subscription and transaction state in sync
- separate per-plugin findings from cross-plugin contract drift instead of mixing them together

## Validation Prompts

Minimum questions to answer in a review:

- Can one customer mutate another customer's subscription, saved card, line item, or address by UUID?
- Does any customer-facing mutation still allow `GET`?
- Is any admin `_action` route protected only by frontend UI permissions?
- Does recurring order creation reuse stale order totals or stale transaction amounts?
- Can duplicate scheduler runs or duplicate webhooks create duplicate charges or skip a renewal cycle?
- Are provider payloads, signatures, tokens, or customer identifiers logged or stored more broadly than necessary?

## 6.7 Recurring Payment Notes

### `AbstractPaymentHandler::recurring()` And `supports()`

The single 6.7 payment handler exposes `recurring()` for the renewal charge and `supports()` to gate whether recurring is available for a given transaction. `RecurringPaymentHandlerInterface` was **removed in 6.7.0.0** — code referencing it will not load. Migrate to `AbstractPaymentHandler` with a `supports()` capability check.

Full contract in `07-payments.md`.

Source: release notes 6.7.0.

## Middleware Retry Loops Cause Duplicate Renewals

Same failure mode as duplicate orders: a middleware retry loop against the Shopware renewal endpoint creates duplicate charges when the response is lost but the renewal actually succeeded.

- Verify retry policy for status errors and network failures. Either can conceal a completed charge; reconcile unknown outcomes before retrying.
- Persist a stable cycle/operation identity with durable uniqueness and concurrency control. A check-then-create lookup alone is race-prone.
- On the plugin side, the renewal endpoint should be safe under duplicate calls with the same idempotency key.

Related: `07-payments.md` middleware retry section; `16-headless-and-composable-frontends.md` composable frontend contract.
