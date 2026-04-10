# Exception Testing Patterns

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
