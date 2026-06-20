---
id: PLACEMENT-007
title: Name-vs-body coherence — does the body assert what the name claims?
group: placement
enforce: consider
test-types: integration
test-categories: all
scope: shopware
review-unit: class-bodies
scoped-review: include
---

## Name-vs-body coherence — does the body assert what the name claims?

**Scope**: all | **Enforce**: Consider (reasoning prompt; loaded only by `phpunit-integration-to-unit-migrating`)

Read each test method's name as a one-sentence claim about behavior. Then read the body and check: does the assertion verify *that* claim, or does it verify a narrower claim the SUT could produce in isolation? Names like `testCalculatesDiscountForGroupedItems` or `testReturnsTrueForValidOrderId` describe in-memory logic, even when the test method runs inside an integration kernel.

### Worked deliberation

For each test method:

1. **State the name as a claim.** Rewrite the method name as one English sentence starting with "The SUT...". Examples:
   - `testCalculatesDiscountForGroupedItems` → "The SUT calculates a discount for grouped items."
   - `testPersistsOrderAndIndexesStock` → "The SUT persists an order and the stock indexer runs."
   - `testReturnsTrueForValidOrderId` → "The SUT returns true for a valid order ID."
2. **Classify the claim:**
   - Pure computation / decision → unit-shape claim
   - Persistence / wiring / dispatch / cross-service interaction → integration-shape claim
3. **Check the body:** is the assertion verifying the claim, or a narrower thing?

### Verdict

| Claim shape | Body verifies | Verdict |
|---|---|---|
| Unit-shape | The claim | Migrate. The name says the test is unit. |
| Integration-shape | The claim | Keep. |
| Integration-shape | A unit-shape narrowing of the claim | Either rename the test to match the narrower claim and migrate, OR expand the assertion to verify the full claim. |
| Unit-shape | An integration-shape thing | The name is misleading — the body actually asserts an integration claim. Rename, keep. |

### Examples

```php
// CLAIM is unit-shape, body verifies it
public function testCalculatesDiscountForGroupedItems(): void
{
    $cart = ...;
    $discount = $this->discountCalculator->calculate($cart);
    static::assertSame(15.0, $discount);
}
// → migrate. Name says unit, body confirms.

// CLAIM is integration-shape, body verifies it
public function testStockIndexerRunsAfterProductWrite(): void
{
    $this->productRepository->create([['id' => $id, 'stock' => 5, ...]], $context);
    $persisted = $this->connection->fetchOne('SELECT available_stock FROM product WHERE id = ?', [Uuid::fromHexToBytes($id)]);
    static::assertSame(5, (int) $persisted);
}
// → keep. Name says integration, body confirms.
```
