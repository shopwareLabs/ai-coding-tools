---
id: DESIGN-005
title: Assertion Scope
group: design
enforce: should-fix
test-types: all
test-categories: A,B,C,D
scope: general
---

## Assertion Scope

**Scope**: A,B,C,D | **Enforce**: Should fix

Tests should have one logical assertion per test. Multiple assertions are acceptable only when testing a single logical behavior.

### When Multiple Assertions Are OK

- Verifying multiple properties of a single created object
- Checking before/after state of one operation
- Asserting related aspects of one behavior

### Detection — Different Behaviors

```php
// INCORRECT - different behaviors
public function testProductCreation(): void
{
    $product = $this->service->create($data);
    static::assertEquals('Test', $product->getName());    // creation
    static::assertTrue($product->isActive());              // status
    static::assertCount(3, $this->repo->findAll());        // persistence
    static::assertNotEmpty($this->logger->getLogs());      // logging
}
```

### Fix

```php
// CORRECT - single behavior with related assertions
public function testCreatesProductWithProvidedProperties(): void
{
    $product = $this->service->create(['name' => 'Test', 'price' => 10.50]);

    static::assertEquals('Test', $product->getName());
    static::assertEquals(10.50, $product->getPrice());
    static::assertNotNull($product->getId());
}

// Separate test for separate concern
public function testProcessOrderSendsNotificationEmails(): void
{
    $this->service->process($data);
    static::assertCount(5, $this->emailService->getSent());
}
```
