---
id: UNIT-004
title: Mock Expectation Misuse
legacy: E019
group: unit
enforce: must-fix
test-types: unit
test-categories: B,C,D
scope: phpunit
---

## Mock Expectation Misuse

**Scope**: B,C,D | **Enforce**: Must fix

Two anti-patterns covered by this rule:

1. **Over-coupling**: Using `expects($this->once())` on collaborators whose result is already asserted by outcome assertions
2. **Silent callback ignorance**: Using `->with(static::callback(...))` without `expects()`, causing the callback to never fire

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

Use `atLeastOnce()`, NOT `any()`: `any()` permits 0 calls, which would let assertion-containing callbacks silently never fire.

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

**Rule**: When `->with(static::callback(...))` is present on a mock chain, `->expects(...)` MUST also be present. Without it, PHPUnit silently ignores the `->with()` constraint and the callback never fires.

```php
// INCORRECT - callback never fires: no expects() means PHPUnit ignores ->with()
$this->repository
    ->method('search')
    ->with(static::callback(function (Criteria $criteria): bool {
        static::assertContains('translations', $criteria->getAssociations()); // Never executes!
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
