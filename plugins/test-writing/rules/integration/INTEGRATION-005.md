---
id: INTEGRATION-005
title: No #[Depends] between integration test methods
group: integration
enforce: must-fix
test-types: integration
test-categories: all
scope: phpunit
review-unit: method
scoped-review: include
---

## No `#[Depends]` between integration test methods

**Scope**: all | **Enforce**: Must fix

`#[Depends]` couples test methods into an implicit order and shares state between them, which defeats the per-test transaction rollback that `IntegrationTestBehaviour` provides. Each integration test must be runnable in isolation.

### Detection

1. Scan test methods for `#[Depends(...)]` attributes (or legacy `@depends` PHPDoc).
2. Flag every occurrence.
3. The fix is always: collapse the dependency chain into a single test method, or extract shared setup into `setUp()` / a private helper.

```php
// INCORRECT - depends on prior test's return value
public function testCreatesOrder(): Order
{
    $order = $this->orderService->create(...);
    static::assertNotNull($order->getId());

    return $order;
}

#[Depends('testCreatesOrder')]
public function testTransitionsOrderToPaid(Order $order): void
{
    $this->stateMachine->transition($order, 'pay');
    // ...
}
```

### Fix

```php
// CORRECT - each test is independent
public function testCreatesOrder(): void
{
    $order = $this->orderService->create(...);
    static::assertNotNull($order->getId());
}

public function testTransitionsOrderToPaid(): void
{
    $order = $this->orderService->create(...);  // re-create, transaction rollback will clean up

    $this->stateMachine->transition($order, 'pay');
    // ...
}
```

### Cross-reference

This rule mirrors `ISOLATION-001` for unit tests. Integration tests have the same FIRST-principle requirement; the rollback transaction only protects state, not order-of-execution coupling.
