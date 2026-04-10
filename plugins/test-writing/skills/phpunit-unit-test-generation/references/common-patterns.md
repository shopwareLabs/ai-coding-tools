# Common Test Patterns

General-purpose patterns for PHPUnit tests in Shopware.

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
    $this->expectExceptionObject(
        new \Shopware\Core\Framework\Plugin\Exception\DecorationPatternException(self::class)
    );

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
