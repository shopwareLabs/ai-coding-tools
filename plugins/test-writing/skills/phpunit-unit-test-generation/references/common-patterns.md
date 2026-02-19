# Common Test Patterns

Reusable patterns for PHPUnit tests in Shopware.

## Exception Testing

Set expectations BEFORE the throwing call. **Never use `expectException(Foo::class)` alone for exceptions that accept parameters or have factory methods** — this is E018. Always include message, code, or the full exception object.

```php
// PRIMARY PATTERN: expectExceptionObject for Shopware factory exceptions (preferred)
public function testThrowsOrderException(): void
{
    // Full object match: verifies type + message + parameters in one call
    $this->expectExceptionObject(OrderException::customerNotLoggedIn());

    $this->route->process($request, $context);
}

// WHEN NO FACTORY METHOD: expectException + expectExceptionMessage (minimum)
public function testThrowsOnInvalidInput(): void
{
    $this->expectException(InvalidArgumentException::class);
    $this->expectExceptionMessage('Input cannot be empty');  // REQUIRED — never omit

    $this->service->process('');  // Throwing call LAST
}

// WITH EXCEPTION CODE: include when the code is part of the contract
public function testThrowsWithCorrectCode(): void
{
    $this->expectException(CartException::class);
    $this->expectExceptionMessage('Cart is empty');
    $this->expectExceptionCode(CartException::CART_EMPTY);

    $this->cartService->checkout($emptyCart);
}

// WEAK PATTERN — DO NOT USE for parameterized exceptions (E018)
// $this->expectException(SomeException::class);  // Missing message/code/object
// $this->service->doSomething();
```

## Data Providers

Use named yields for clarity:

```php
public static function validInputProvider(): iterable
{
    yield 'standard input' => ['value1', 'expected1'];
    yield 'edge case empty' => ['', null];
    yield 'special characters' => ['<script>', '&lt;script&gt;'];
}

#[DataProvider('validInputProvider')]
#[TestDox('processes $input correctly')]
public function testProcessesInput(string $input, ?string $expected): void
{
    $result = $this->service->process($input);
    static::assertSame($expected, $result);
}
```

### Complex Data Provider

```php
public static function orderStateProvider(): iterable
{
    yield 'open order' => [
        'state' => OrderStates::STATE_OPEN,
        'canCancel' => true,
        'canComplete' => true,
    ];
    yield 'completed order' => [
        'state' => OrderStates::STATE_COMPLETED,
        'canCancel' => false,
        'canComplete' => false,
    ];
}

#[DataProvider('orderStateProvider')]
#[TestDox('handles $state order correctly')]
public function testHandlesOrderState(string $state, bool $canCancel, bool $canComplete): void
{
    $order = $this->createOrder($state);

    static::assertSame($canCancel, $this->service->canCancel($order));
    static::assertSame($canComplete, $this->service->canComplete($order));
}
```

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
        ->expects(static::once())  // This is why createMock() is used
        ->method('dispatch')
        ->with(static::isInstanceOf(OrderPlacedEvent::class));

    $this->service->processOrder($order);
}
```

## Intersection Type Mocks (PHP 8.1+)

Use intersection types for type-safe declarations — match the type to the factory method:

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

## Stub/Mock Configuration

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

### Side-Effect Verification (use createMock + expects)

Only use `expects(static::once())` for side-effect methods where the call itself is the behavior being tested — not when you can assert the return value instead:

```php
// CORRECT — dispatch() is a side effect; use expects() to verify it fired
$this->eventDispatcher
    ->expects(static::once())
    ->method('dispatch')
    ->with($cart, $context);

// CORRECT — verifying a call does NOT happen
$this->emailService
    ->expects(static::never())
    ->method('send');

// INCORRECT (E019) — result is asserted, so expects() is redundant
// $this->service->expects(static::once())->method('load')->willReturn($data);
// $result = $this->subject->process();
// static::assertSame($data, $result);  // This already proves load() was called
```

## AAA Structure (Arrange-Act-Assert)

```php
public function testCalculatesTotalPrice(): void
{
    // Arrange
    $lineItem1 = new LineItem('id1', 'product', 'ref1', 2);
    $lineItem1->setPrice(new CalculatedPrice(10.00, 20.00, ...));

    $lineItem2 = new LineItem('id2', 'product', 'ref2', 1);
    $lineItem2->setPrice(new CalculatedPrice(5.00, 5.00, ...));

    $cart = new Cart('test-token');
    $cart->add($lineItem1);
    $cart->add($lineItem2);

    // Act
    $total = $this->calculator->calculateTotal($cart);

    // Assert
    static::assertSame(25.00, $total);
}
```

## Testing Private Methods (via Public Interface)

Never test private methods directly. Test through public interface:

```php
// Wrong: Testing private method
// $result = $this->invokePrivateMethod($service, 'privateMethod', $args);

// Correct: Test through public interface
public function testPublicMethodUsesInternalLogic(): void
{
    // The private method is exercised through the public method
    $result = $this->service->publicMethod($input);

    // Assert the observable behavior
    static::assertSame($expectedOutput, $result);
}
```

## Testing Event Subscribers

```php
public function testSubscribesToCorrectEvents(): void
{
    $events = OrderPlacedSubscriber::getSubscribedEvents();

    static::assertArrayHasKey(OrderPlacedEvent::class, $events);
    static::assertSame('onOrderPlaced', $events[OrderPlacedEvent::class]);
}

public function testHandlesOrderPlacedEvent(): void
{
    $order = $this->createOrder();
    $event = new OrderPlacedEvent($order, $this->context);

    $this->subscriber->onOrderPlaced($event);

    // Assert side effects (email sent, log written, etc.)
    static::assertCount(1, $this->emailService->sentEmails);
}
```

## Decoration Pattern Testing

Shopware uses a decoration pattern where services implement `getDecorated()`. When the class under test is NOT a decorator (it IS the inner service), `getDecorated()` must throw `DecorationPatternException`.

### Test the getDecorated() Contract

```php
#[TestDox('throws DecorationPatternException when getDecorated is called')]
public function testGetDecoratedThrowsDecorationPatternException(): void
{
    $this->expectException(\Shopware\Core\Framework\Plugin\Exception\DecorationPatternException::class);

    $this->service->getDecorated();
}
```

### Creating Test Stubs That Extend Decorated Services

When you create an inline test stub (anonymous class) that extends a service implementing the decoration pattern, the stub **must** throw `DecorationPatternException` from `getDecorated()` — NOT return `$this`:

```php
// INCORRECT — returning $this silently violates the decoration contract
$stub = new class extends AbstractContentLoader {
    public function getDecorated(): AbstractContentLoader
    {
        return $this;  // WRONG: masks errors, hides missing decoration chain
    }
    // ...
};

// CORRECT — throw DecorationPatternException to enforce the contract
$stub = new class extends AbstractContentLoader {
    public function getDecorated(): AbstractContentLoader
    {
        throw new \Shopware\Core\Framework\Plugin\Exception\DecorationPatternException(self::class);
    }
    // ...
};
```

### Why This Matters

- Returning `$this` silently violates Shopware's decoration contract
- Tests using such stubs will pass even when the production code incorrectly calls `getDecorated()` in loops or builds broken decoration chains
- This was a source of subtle test failures in practice that required a full fix sweep
