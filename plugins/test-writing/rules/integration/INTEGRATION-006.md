---
id: INTEGRATION-006
title: Do not skip tests for missing fixtures
group: integration
enforce: should-fix
test-types: integration
test-categories: all
scope: shopware
review-unit: method
---

## Do not skip tests for missing fixtures

**Scope**: all | **Enforce**: Should fix

`static::markTestSkipped()` belongs to environment incompatibility (missing extension, unavailable engine, feature flag off). It is not a substitute for creating required fixtures in `setUp()`. A test that skips itself because the data it needs is absent silently disappears from coverage and hides regressions.

### Detection

1. Find every `static::markTestSkipped(`, `$this->markTestSkipped(` call.
2. Read the preceding condition.
3. Flag if the condition checks for the presence of data the test itself could create:
   - "category does not exist", "no payment method found", "rule set is empty"
   - DAL `search()` returning zero rows
   - Existence checks against tables the test could populate
4. Allow if the condition checks environment incompatibility:
   - PHP extension presence (`extension_loaded`)
   - Feature flag state (`Feature::isActive`) — though prefer `#[DisabledFeatures]`
   - External service availability that the test cannot bring up
   - Database engine version

```php
// INCORRECT - skips when fixture is missing
public function testReindexesAllProducts(): void
{
    $products = $this->productRepository->search(new Criteria(), Context::createDefaultContext());
    if ($products->getTotal() === 0) {
        static::markTestSkipped('No products in database');
    }
    // ...
}
```

### Fix

```php
// CORRECT - create the fixture the test needs
public function testReindexesAllProducts(): void
{
    $this->createProductFixture('test-product-1');
    $this->createProductFixture('test-product-2');

    $products = $this->productRepository->search(new Criteria(), Context::createDefaultContext());
    static::assertGreaterThanOrEqual(2, $products->getTotal());
    // ...
}
```
