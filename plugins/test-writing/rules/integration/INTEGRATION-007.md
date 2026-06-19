---
id: INTEGRATION-007
title: Setup-to-assertion ratio is balanced
group: integration
enforce: should-fix
test-types: integration
test-categories: all
scope: shopware
review-unit: method
---

## Setup-to-assertion ratio is balanced

**Scope**: all | **Enforce**: Should fix

A test that boots the kernel, fetches services from the container, and writes fixtures across multiple tables to produce a single pure assertion (return value, exception message, scalar equality) is paying integration cost for unit-shape behavior. Either the test is misplaced (most common), or it is missing meaningful integration-level assertions (less common — augment the assertions).

This rule emits a should-fix warning, not an error. Resolution depends on intent: if the SUT genuinely is integration-shaped, add assertions that justify the apparatus (persisted state, dispatched events, container-resolved identity). If the SUT is unit-shaped, see `INTEGRATION-008` and consider the migrating skill.

### Detection

1. Count the lines (or distinct statements) in `setUp()` plus the test method's arrange section.
2. Count assertions in the test method's assert section.
3. Classify each assertion as **unit-shape** or **integration-shape** (see `INTEGRATION-008` for the catalog).
4. Flag if both:
   - Arrange + setUp ≥ 8 statements involving the container, DAL, or fixture creation, AND
   - 100% of assertions are unit-shape AND there are ≤ 2 of them.

### Examples

```php
// FLAGGED - heavy setup, single unit-shape assertion
public function testCalculatesGroupTotal(): void
{
    $context = $this->getSalesChannelContext();
    $product = $this->createProduct('test-product');
    $rule = $this->createRule(['operator' => '>=', 'amount' => 100]);
    $cart = $this->cartService->createNew($context->getToken());
    $lineItem = (new LineItem('id', 'product', $product->getId()))->setPrice(new CalculatedPrice(150, ...));
    $this->cartService->add($cart, $lineItem, $context);

    $group = $this->lineItemGroupBuilder->build([$rule], $cart, $context);

    static::assertSame(150.0, $group->getTotalPrice());  // pure scalar — could be unit
}
```

### Fix paths

1. **If the test is genuinely integration-shaped** — augment the assertions to exercise what the apparatus enables: persisted state after `cartPersister->save()`, events dispatched through the real event bus, services resolved by tag, transactional consistency across collaborators.

2. **If the test is misplaced** — see `INTEGRATION-008`. The full evaluation belongs in the `phpunit-integration-to-unit-migrating` skill; this rule is the warning, not the audit.
