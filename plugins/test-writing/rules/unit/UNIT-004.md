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
