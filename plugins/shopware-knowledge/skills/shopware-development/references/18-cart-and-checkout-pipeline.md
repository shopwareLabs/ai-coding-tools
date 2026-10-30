# Cart and Checkout Pipeline

Index: pipeline model, collectors/processors, ordering, line items, validators, delivery/promotions, order conversion, hot paths, async, review prompts.

## Core Pipeline Mental Model

The stable Shopware core pattern is:

1. collectors enrich `CartDataCollection`
2. the cart amount is calculated
3. processors run in order and the amount is recalculated after each processor
4. validators add cart errors
5. transaction data is built from the processed cart

Treat that order as a correctness boundary, not just an implementation detail.

## Collector vs Processor

- Collectors fetch or precompute data and write it into `CartDataCollection`. Recalculation can invoke them again; check for an existing entry using a key that changes with value-determining inputs rather than assuming one invocation per request.
- Processors read prepared data and mutate the calculated cart.
- Validators add errors or block invalid states; they should not hide heavy I/O or business side effects.
- If you need database or API data for many line items, collect it once, keyed by stable IDs, and let the processor read it.

Example patterns:

```php
// Bad: repository calls inside process() for every line item
public function process(CartDataCollection $data, Cart $original, Cart $toCalculate, SalesChannelContext $context, CartBehavior $behavior): void
{
    foreach ($original->getLineItems() as $lineItem) {
        $product = $this->productRepository->search(
            new Criteria([$lineItem->getReferencedId()]),
            $context->getContext()
        )->first();

        $lineItem->setLabel($product?->getName() ?? $lineItem->getLabel());
        $toCalculate->add($lineItem);
    }
}
```

```php
// Preferred: batch in collect(), read in process()
public function collect(CartDataCollection $data, Cart $original, SalesChannelContext $context, CartBehavior $behavior): void
{
    $ids = array_filter($original->getLineItems()->getReferenceIds());
    if ($ids === []) {
        return;
    }

    $criteria = new Criteria($ids);

    // $ids is the complete bounded set; do not truncate it with an arbitrary limit.
    $products = $this->productRepository->search($criteria, $context->getContext());
    $data->set('my-plugin.products', $products->getEntities());
}

public function process(CartDataCollection $data, Cart $original, Cart $toCalculate, SalesChannelContext $context, CartBehavior $behavior): void
{
    /** @var EntityCollection<ProductEntity> $products */
    $products = $data->get('my-plugin.products') ?? new ProductCollection();

    foreach ($original->getLineItems() as $lineItem) {
        $product = $products->get($lineItem->getReferencedId());
        $lineItem->setLabel($product?->getName() ?? $lineItem->getLabel());
        $toCalculate->add($lineItem);
    }
}
```

Do not add `$criteria->addFields([...])` here. `addFields()` switches the read into partial mode, and the hydrator then returns `PartialEntity` (an `ArrayEntity`) instead of `ProductEntity`. `PartialEntity` has no `__call` and no getters, so `$product?->getName()` throws `Error: Call to undefined method` on every recalculation that finds a product — on the cart hot path.

If you do need partial reads, access values with `$product?->get('name')` and drop the `ProductEntity` type hints.

## Processor Ordering and Recalculation

- Processor order matters because price and delivery totals are recalculated after each processor.
- Do not assume your processor runs last unless you control the tag priority and have verified the interaction.
- Keep shipping, promotion, and custom-fee interactions explicit. If your processor changes line item price definitions, check delivery and promotion fallout.
- If the processor depends on data from another processor, document the priority dependency instead of relying on container order luck.

## Line Item Creation and Enrichment

- Prefer `LineItemFactoryRegistry` or existing line item types over ad hoc line item construction from controllers.
- Use dedicated line item types for plugin-owned fees, credits, bundles, or markers.
- Keep payloads minimal and deterministic. Do not hide operational state in large mutable payload blobs.
- If the storefront creates line items, validate referenced IDs, customer scope, and allowed payload shape before adding them.

Example patterns:

```php
// Bad: ad hoc line item with generic type and mutable blob payload
$lineItem = new LineItem(Uuid::randomHex(), 'custom');
$lineItem->setPayload($request->request->all());
```

```php
// Preferred: dedicated line item type and whitelisted payload
$lineItem = $this->lineItemFactoryRegistry->create([
    'type' => 'my_plugin_fee',
    'id' => 'my-plugin-fee',
    'referencedId' => $feeConfigId,
    'payload' => ['source' => 'checkout-config'],
], $context);
```

## Validators

- Use cart validators for cart-state validation, not as a hidden place for outbound HTTP or database-heavy work.
- Add actionable cart errors and keep them scoped to the exact line item or checkout state that failed.
- Payment, shipping, and recurring-method validators must not widen customer access or trust browser-authored identifiers.

### Cart Errors Must Survive Recalculation And Reach The Page

- **`Error::isPersistent()` defaults to `true`; keep it.** The cart is recalculated several times in one request, and `Processor` carries over only `getErrors()->getPersistent()` from the original cart. A warning that returns `false` disappears on the next recalculation, before the page renders. "Persistent" does not mean stored with the cart; it means it survives recalculation.
- **Controllers must forward the errors.** Core's storefront cart actions (including adding a promotion code) end in `traceErrors()`, which calls `StorefrontController::addCartErrors($cart, …)` to turn cart errors into flash messages. A custom controller that changes the cart and redirects without calling `addCartErrors()` drops every warning its processors raised.

## Delivery, Shipping, and Promotion Interactions

- Delivery calculation and promotion calculation are part of the same checkout truth surface.
- If you add discounts, credits, or fees, verify shipping costs, free-shipping thresholds, promotion stacking, and tax behavior.
- Do not branch shipping or promotion logic on translated labels or storefront-only presentation state.
- Keep shipping-method technical names stable across config and migration changes.
- **Cart-wide promotions only see stackable product line items.** `CartScopeDiscountPackager` filters on `type === product && isStackable()`. A product line item built by hand (tests, fixtures, imports, plugin add-to-cart code) without `setStackable(true)` is skipped silently. The storefront line-item factory sets it.
- **`calculatedCheapestPrice->hasRange()` is not only about tier prices.** `CheapestPriceContainer` sets it when any variant's price differs from the cheapest one **or** a price is tiered. A product family whose variants simply cost different amounts is a "range". Code that treats `hasRange()` as "has advanced prices" skips whole variant families.

Example patterns:

```php
// Bad: remote shipping lookup inside a processor on every recalculation
public function process(CartDataCollection $data, Cart $original, Cart $toCalculate, SalesChannelContext $context, CartBehavior $behavior): void
{
    $quote = $this->carrierClient->fetchQuote($original);
    $this->applyShippingQuote($toCalculate, $quote);
}
```

```php
// Preferred: resolve a bounded local or cached quote, then apply it deterministically
public function process(CartDataCollection $data, Cart $original, Cart $toCalculate, SalesChannelContext $context, CartBehavior $behavior): void
{
    $quote = $data->get('my-plugin.shipping-quote');
    if ($quote !== null) {
        $this->applyShippingQuote($toCalculate, $quote);
    }
}
```

## Order Conversion and Recalculation

- Do not assume a cart snapshot is authoritative forever. Recalculate from the current sales-channel context when payment, shipping, currency, or rules may have changed.
- Keep the boundary between cart calculation and order persistence explicit. Do not mutate finished orders from casual cart helpers.
- When a renewal or post-order edit reconstructs a cart, re-run the real calculation path instead of patching totals manually.
- **Keep `priceDefinition` when rebuilding a cart from stored data** (abandoned-cart restore, cart copy, reorder). `ProductCartProcessor` sets the definition for product line items on every calculation, but custom line items (bundle discounts, fees, credits) often receive theirs only when first added. Stripping it leaves those items without a price, and the owning processor may crash on them.

## Hot-Path Red Lines

- No slow external API calls on the customer checkout path unless the business flow truly requires it and the timeout is tight.
- No repository `search()` inside loops over line items.
- No broad association trees or cart snapshot hydration just to render one badge, label, or fee.
- No writes or recalculations hidden in read routes that only load confirm, cart, or offcanvas pages.
- No queue handoff for correctness-critical cart calculations that must finish before the customer sees the total.

## Async Handoff Boundaries

- Queue post-order side effects such as ERP sync, CRM sync, reporting, or delayed notification work after the order state is safely persisted.
- Keep cart totals, shipping choices, tax decisions, and payment availability synchronous only when they are part of the current checkout truth.
- If a third-party dependency cannot answer within its checkout time budget, use a provider-valid cached value or a domain-approved fallback. Block submission with an actionable error when price, tax, shipping, or payment authority cannot be established; post-order reconciliation is suitable only when the business contract permits it.

Example patterns:

```php
// Preferred: queue post-order side effects instead of blocking checkout
public function onCheckoutCompleted(CheckoutOrderPlacedEvent $event): void
{
    $this->messageBus->dispatch(new ExportOrderMessage($event->getOrderId()));
}
```

## Review Prompts

Minimum questions to answer in cart or checkout reviews:

- Is expensive data fetched once in a collector or repeatedly in a processor?
- Does any processor priority assumption break shipping, promotions, or tax state?
- Are custom line item types explicit and stable?
- Are cart validators cheap and deterministic?
- Does any cart, confirm, or checkout page loader trigger writes, remote I/O, or heavy recalculation?
- If payment is involved, where does payment authority rejoin the cart or order flow?

## 6.7 Cart Pipeline Changes

### `CartBehavior::isRecalculation` → `CheckoutPermissions`

`CartBehavior::isRecalculation` is deprecated. Use granular permission constants from `CheckoutPermissions`.

- Check permissions on `CartBehavior` (or `SalesChannelContext`) instead of `isRecalculation()`.
- For in-memory calculations that must not persist, set `SKIP_CART_PERSISTENCE` and honor it in `CartVerifyPersistEvent::setShouldPersist`.

Source: UPGRADE-6.7.md §6.7.2.0.

### `FilterableInterface` For Filtered Price Definitions

From 6.7.4, price definitions that participate in promotion filtering must implement `\Shopware\Core\Checkout\Cart\Price\Struct\FilterableInterface` and provide `getFilter(): ?Rule`.

The consumers are the promotion calculator and discount packagers, not every cart processor.

Without the interface, custom price definitions are silently excluded from filter operations.

Source: UPGRADE-6.7.md §6.7.4.0.

### Order `primaryOrderDelivery` And `primaryOrderTransaction`

Since 6.7.1, `Order::primaryOrderDelivery` and `Order::primaryOrderTransaction` replace `.deliveries.first()` and `.transactions.first()`. Migration backfills existing orders. `OrderConverter` still puts the primary first in the collection for BC — but new code should use the explicit primary references in Twig and PHP.

Source: release notes 6.7.1, UPGRADE-6.7.md §6.7.1.0.

### Product `states` → `type` Model

`product.states`, `order_line_item.states`, `LineItem::$states`, `StatesUpdater`, `ProductStatesBeforeChangeEvent`, `ProductStatesChangedEvent` are deprecated in 6.7.7 in favor of `product.type` and `order_line_item.payload.productType` / `LineItem::$payload['productType']` (camelCase — the DAL deprecation flag names `payload.productType`).

- Register custom product types via `shopware.product.allowed_types` config.
- Migrate reads from `product.states` to `product.type`.

Source: release notes 6.7.7.

## Cart-Token vs Context-Token Pitfall

A common failure on shipping-quote, cart-preview, and configurator routes.

- A plugin-defined `sw-cart-token` GET parameter (not a Shopware platform feature) that overrides the cart token without overriding the context token loads the correct cart but evaluates rules against the wrong context.
- Symptom: only shipping methods for the calling context are visible, cross-checked against a possibly different cart, producing wrong or missing shipping options.
- Correct pattern: use the `sw-context-token` HTTP header to override the context. Cart and context resolve consistently from the same token.
- If a wishlist / shared-cart flow really requires a separate cart token, gate the route with signed URLs plus expiration; do not accept cart-token override via query string for state-mutating routes.

Full details in `07-payments.md`.

## External API In Cart

For repeated read-only tax/shipping/price lookups, follow [provider-derived cache policy](24-external-api-caching-in-cart.md): value-determining key inputs, provider/business freshness, invalidation, and final-order validation where required. Payment/booking side effects and transient errors are not ordinary quote-cache entries; use idempotency and recovery instead.

Sources: [Processor::process](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Checkout/Cart/Processor.php), [CartCalculator::calculate](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Checkout/Cart/CartCalculator.php), and [CartDataCollection](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Checkout/Cart/LineItem/CartDataCollection.php). Invocation frequency depends on the calling flow and installed extensions, not a universal fixed count.
