# Mocking Patterns

## Stub vs Mock — Choosing the Right Factory

Use `createStub()` when you only need return values. Use `createMock()` only when you need to verify interactions with `expects()`.

```php
use PHPUnit\Framework\MockObject\Stub;

// createStub() — for dependencies where you only configure return values (W012 if you use createMock here)
private CartService&Stub $cartService;
private ProductRepository&Stub $productRepository;

protected function setUp(): void
{
    $this->cartService = $this->createStub(CartService::class);
    $this->productRepository = $this->createStub(ProductRepository::class);
}

// createMock() — ONLY when you need expects() for interaction verification
private EventDispatcherInterface&MockObject $eventDispatcher;

protected function setUp(): void
{
    $this->eventDispatcher = $this->createMock(EventDispatcherInterface::class);
}

public function testDispatchesEvent(): void
{
    $this->eventDispatcher
        ->expects($this->once())  // This is why createMock() is used
        ->method('dispatch')
        ->with(static::isInstanceOf(OrderPlacedEvent::class));

    $this->service->processOrder($order);
}
```

## Intersection Types (PHP 8.1+)

Match the type to the factory method:

| Factory | Intersection type | Use when |
|---------|-------------------|----------|
| `createStub(Foo::class)` | `Foo&Stub` | Return values only |
| `createMock(Foo::class)` | `Foo&MockObject` | Interaction verification with `expects()` |

```php
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\MockObject\Stub;

// Stubs (most common — for collaborators you only configure return values for)
private CartService&Stub $cartService;
private ProductRepository&Stub $productRepository;

// Mocks (for side-effect methods where you need to assert dispatch/write/send happened)
private EventDispatcherInterface&MockObject $eventDispatcher;
private HttpClientInterface&MockObject $httpClient;
```

## Configuration

```php
// Simple return value (use on stubs and mocks)
$this->cartService
    ->method('getCart')
    ->willReturn($cart);

// Return based on arguments
$this->productRepository
    ->method('search')
    ->willReturnCallback(function (Criteria $criteria) {
        if ($criteria->getLimit() === 1) {
            return new EntitySearchResult(...);
        }
        return new EntitySearchResult(...);
    });

// Throw exception
$this->productRepository
    ->method('search')
    ->willThrowException(new ProductNotFoundException($productId));
```

## Side-Effect Verification (use createMock + expects)

Only use `expects($this->once())` for side-effect methods where the call itself is the behavior being tested — not when you can assert the return value instead:

```php
// CORRECT — dispatch() is a side effect; use expects() to verify it fired
$this->eventDispatcher
    ->expects($this->once())
    ->method('dispatch')
    ->with($cart, $context);

// CORRECT — verifying a call does NOT happen
$this->emailService
    ->expects($this->never())
    ->method('send');

// INCORRECT (E019) — result is asserted, so expects() is redundant
// $this->service->expects($this->once())->method('load')->willReturn($data);
// $result = $this->subject->process();
// static::assertSame($data, $result);  // This already proves load() was called
```
