---
id: INTEGRATION-004
title: Deterministic time, randomness, and identifiers
group: integration
enforce: should-fix
test-types: integration
test-categories: all
scope: shopware
review-unit: method
---

## Deterministic time, randomness, and identifiers

**Scope**: all | **Enforce**: Should fix

Integration tests that depend on the current wall-clock time, `random_*`, or unsourced UUID generation produce flaky failures and assertions that drift across time zones, daylight-savings boundaries, and CI runs. Inject the clock, supply explicit seeds, or use Shopware-provided ID helpers with deterministic input.

### Detection

1. Scan for direct calls to non-deterministic sources in the test body:
   - `new \DateTime()` / `new \DateTimeImmutable()` without an explicit time string
   - `time()`, `microtime()`, `date('...')`
   - `random_int()`, `random_bytes()`, `mt_rand()`, `uniqid()`
   - `Uuid::randomHex()`, `Uuid::randomBytes()` when used inside assertions (not just to seed unrelated test data)
2. For each, ask: does the assertion depend on the value? If yes — flag.
3. Acceptable patterns:
   - `Uuid::randomHex()` for IDs that are then asserted via referential lookup (the assertion does not depend on the literal value)
   - Clock injection via `ClockInterface` from the container
   - Fixed seeds: `mt_srand(42)` in `setUp()` for tests that need controlled randomness

```php
// INCORRECT - assertion depends on wall-clock time
public function testOrderCreatedAtIsRecent(): void
{
    $order = $this->createOrder();
    $diff = (new \DateTime())->getTimestamp() - $order->getCreatedAt()->getTimestamp();
    static::assertLessThan(2, $diff);  // flaky under CI load
}
```

### Fix

```php
// CORRECT - assert against an injected/fixed reference time
public function testOrderCreatedAtMatchesInjectedClock(): void
{
    $clock = new MockClock(new \DateTimeImmutable('2025-06-01T12:00:00Z'));
    static::getContainer()->set(ClockInterface::class, $clock);

    $order = $this->createOrder();
    static::assertEquals($clock->now(), $order->getCreatedAt());
}
```
