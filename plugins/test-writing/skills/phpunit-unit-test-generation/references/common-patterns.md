# Common Test Patterns

Reusable patterns for PHPUnit tests in Shopware.

## Exception Testing

Set expectations BEFORE the throwing call:

```php
// Basic exception
public function testThrowsOnInvalidInput(): void
{
    $this->expectException(InvalidArgumentException::class);
    $this->expectExceptionMessage('Input cannot be empty');

    $this->service->process('');  // Throwing call LAST
}

// With factory exceptions (preferred for Shopware)
public function testThrowsOrderException(): void
{
    $this->expectExceptionObject(OrderException::customerNotLoggedIn());

    $this->route->process($request, $context);
}

// With exception code
public function testThrowsWithCorrectCode(): void
{
    $this->expectException(CartException::class);
    $this->expectExceptionCode(CartException::CART_EMPTY);

    $this->cartService->checkout($emptyCart);
}
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

## Intersection Type Mocks (PHP 8.1+)

Use intersection types for type-safe mocks:

```php
private CartService&MockObject $cartService;
private ProductRepository&MockObject $productRepository;

protected function setUp(): void
{
    $this->cartService = $this->createMock(CartService::class);
    $this->productRepository = $this->createMock(ProductRepository::class);
}
```

## Mock Configuration

```php
// Simple return value
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

// Expect specific call count
$this->cartService
    ->expects(static::once())
    ->method('persist')
    ->with($cart, $context);

// Throw exception
$this->productRepository
    ->method('search')
    ->willThrowException(new ProductNotFoundException($productId));
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
