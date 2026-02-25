---
id: UNIT-005
title: createMock vs createStub
legacy: W012
group: unit
enforce: should-fix
test-types: unit
test-categories: B,C,D
scope: phpunit
---

## createMock vs createStub

**Scope**: B,C,D | **Enforce**: Should fix

Using `createMock()` when `createStub()` is sufficient communicates false intent: it implies interaction verification is planned even when none exists.

### Detection

Trigger when ALL of these are true:
1. `createMock(Foo::class)` is called for a property or local variable
2. No `->expects(...)` call appears on that variable anywhere in the test class
3. No `->with(static::callback(...))` containing assertions appears on that variable

```php
// INCORRECT - createMock() used but no expects() and no argument callback
private CartService&MockObject $cartService;

protected function setUp(): void
{
    $this->cartService = $this->createMock(CartService::class);
    $this->cartService->method('getCart')->willReturn($this->cart);  // No expects(), no with(callback())
}
```

### Fix

```php
use PHPUnit\Framework\MockObject\Stub;

// CORRECT - createStub() matches intent
private CartService&Stub $cartService;

protected function setUp(): void
{
    $this->cartService = $this->createStub(CartService::class);
    $this->cartService->method('getCart')->willReturn($this->cart);
}
```

### When createMock() IS Correct

```php
// CORRECT - createMock() justified by expects() call
private EventDispatcherInterface&MockObject $eventDispatcher;

public function testDispatchesEvent(): void
{
    $this->eventDispatcher
        ->expects($this->once())     // Interaction verification: createMock() is correct
        ->method('dispatch')
        ->with(static::isInstanceOf(ProductCreatedEvent::class));

    $this->service->create($data);
}

// CORRECT - createMock() justified by ->with(callback(...)) argument verification
$this->repository
    ->expects($this->atLeastOnce())
    ->method('search')
    ->with(static::callback(function (Criteria $criteria): bool {
        static::assertContains('translations', $criteria->getAssociations());
        return true;
    }))
    ->willReturn($result);
```

### Intersection Type Reference

| PHPUnit method | PHP 8.1+ type | Use when |
|----------------|---------------|----------|
| `createStub(Foo::class)` | `Foo&Stub` | Only return values needed |
| `createMock(Foo::class)` | `Foo&MockObject` | Call-count or argument verification needed |
