---
id: UNIT-004
title: Mock Expectation Misuse
group: unit
enforce: must-fix
test-types: unit
test-categories: B,C,D
scope: phpunit
review-unit: method
scoped-review: include
---

## Mock Expectation Misuse

**Scope**: B,C,D | **Enforce**: Must fix

Two anti-patterns covered by this rule:

1. **Over-coupling**: Using `expects($this->once())` on collaborators whose result is already asserted by outcome assertions
2. **Unguaranteed callback**: Using `->with(static::callback(...))` without `expects()`, leaving the default any-invocation matcher in place — it permits zero calls, so the callback may never run

### Anti-Pattern 1: expects(once()) When Result Is Already Asserted

```php
// INCORRECT - call count + willReturn + outcome assertion = redundancy
public function testLoadsProduct(): void
{
    $this->repository
        ->expects($this->once())          // Redundant: result already proves the call
        ->method('search')
        ->willReturn(new ProductCollection([$this->product]));

    $result = $this->service->loadProduct('product-id');

    static::assertSame($this->product, $result);  // Already proves search() was called
}
```

### Fix — Case 1: No with() — remove expects() entirely

Confirm the chain carries no `->with()` before applying this fix. A double carrying `->with()` takes Case 2 — removing `expects()` there leaves the default any-invocation matcher, which permits zero calls and so stops guaranteeing the constraint is evaluated.

```php
public function testLoadsProduct(): void
{
    $this->repository
        ->method('search')
        ->willReturn(new ProductCollection([$this->product]));

    $result = $this->service->loadProduct('product-id');

    static::assertSame($this->product, $result);
}
```

### Fix — Case 2: Has with(callback()) — replace expects(once()) with expects(atLeastOnce())

Use `atLeastOnce()`: it drops the exact-count coupling of `once()` while still guaranteeing the callback fires — an unconstrained matcher permits 0 calls, so an assertion-containing callback could silently never run.

```php
public function testLoadsProductWithCriteriaVerification(): void
{
    $this->repository
        ->expects($this->atLeastOnce())      // Removes exact-count coupling while guaranteeing callback fires
        ->method('search')
        ->with(static::callback(function (Criteria $criteria): bool {
            static::assertContains('translations', $criteria->getAssociations());
            return true;
        }))
        ->willReturn(new ProductCollection([$this->product]));

    $result = $this->service->loadProduct('product-id');

    static::assertSame($this->product, $result);
}
```

### Exception: Shared Mock With Sibling Expectations

A `createMock()` double declared once (typically in `setUp()`) and reused across several test methods, where sibling methods set their own `->expects()` on it, is exempt from the Case 1 remedy (dropping `expects()` entirely). `NoCreateMockWithoutExpectationsRule` requires every method that touches such a double to carry an expectation, but only inside `Shopware\Tests\Unit\` and `Shopware\Tests\DevOps\` — the namespaces listed under `createMockWithoutExpectationsEnabledNamespaces` in Shopware's PHPStan `common.neon`. Applying the Case 1 remedy to one method of a shared double in those namespaces would make that method fail `NoCreateMockWithoutExpectationsRule`, even though this rule's over-coupling anti-pattern still applies to it. This rule's own `test-types: unit` scope means every test it reviews already lives under `Shopware\Tests\Unit\`, one of the two enabled namespaces, so the exception is live wherever UNIT-004 fires; it is documented here for completeness, not because UNIT-004 is ever routed to a migration or integration review.

### Deferral to NoCreateMockWithoutExpectationsRule

Where `NoCreateMockWithoutExpectationsRule` has already reported a double as never expected, UNIT-004 (and UNIT-003) do not re-derive the same stub-or-expectation transform as a separate finding. Suppress the finding and cite the PHPStan rule instead. As above, UNIT-004's `test-types: unit` scope means this deferral is live for every test it reviews.

### Anti-Pattern 2: Missing expects() on with(callback) chain

**Rule**: When `->with(static::callback(...))` is present on a mock chain, `->expects(...)` MUST also be present. `->method()` alone registers `expects(any())` — the default any-invocation matcher, which zero calls satisfy. If the mocked method is never called, the constraint is never evaluated and the callback never runs, so the assertions inside it silently do not execute.

```php
// INCORRECT - callback not guaranteed to run: the default any-invocation matcher permits zero calls
$this->repository
    ->method('search')
    ->with(static::callback(function (Criteria $criteria): bool {
        static::assertContains('translations', $criteria->getAssociations()); // Not guaranteed to execute
        return true;
    }))
    ->willReturn(new ProductCollection([$this->product]));
```

```php
// CORRECT - expects() ensures the callback fires
$this->repository
    ->expects($this->once())
    ->method('search')
    ->with(static::callback(function (Criteria $criteria): bool {
        static::assertContains('translations', $criteria->getAssociations());
        return true;
    }))
    ->willReturn(new ProductCollection([$this->product]));
```

### When expects(once()) IS Legitimate

Use `expects(once())` only for **side-effect-only methods** where the call itself is the observable behavior:

```php
// CORRECT - side-effect method: dispatch() IS the observable behavior
$this->eventDispatcher
    ->expects($this->once())
    ->method('dispatch')
    ->with(static::isInstanceOf(ProductCreatedEvent::class));

// CORRECT - verifying a call is NOT made
$this->emailService
    ->expects($this->never())
    ->method('send');

// CORRECT - file write has no return value
$this->filesystem
    ->expects($this->once())
    ->method('write')
    ->with('output/report.csv', static::isString());
```

Also legitimate: a call-count expectation that forms a **reachability pairing** across two test methods — `never()` on the collaborator in one method's branch, `once()` or `atLeastOnce()` on it in the other branch's method. The expectation is not redundant with an outcome assertion here; it is itself the assertion that pins which branch was reachable. Never apply the over-coupling remedy to either half of such a pairing.

```php
// CORRECT - never()/once() pairing pins which branch ran; neither half is redundant
public function testSkipsNotificationWhenAlreadySent(): void
{
    $this->notifier
        ->expects($this->never())
        ->method('send');

    $this->service->process($this->alreadyNotifiedOrder);
}

public function testSendsNotificationWhenNotYetSent(): void
{
    $this->notifier
        ->expects($this->once())
        ->method('send');

    $this->service->process($this->newOrder);
}
```

### Remediation Notes — Stub Conversion Gotchas

Two API details from Shopware's unit-test guideline matter when a remedy converts a mock to a stub: "Two API details matter when converting: `->with()` exists on mocks only, so a stub asserts its arguments inside `willReturnCallback()` instead, and a fixture helper receiving a stub must type that parameter as `Stub` (`Foo&Stub`) rather than `MockObject`. Both slip past PHPUnit at runtime and only fail in PHPStan." A remedy that drops `->with()` from a mock without moving its assertion into a `willReturnCallback()`, or that leaves a fixture-helper parameter typed `MockObject` after handing it a stub, is incomplete even though the test still runs green under PHPUnit.
