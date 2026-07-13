# Exception Testing Patterns

Set expectations BEFORE the throwing call. **Never use `expectException(Foo::class)` alone for exceptions that accept parameters or have factory methods** — this is CONV-009. Assert the message and code via the full exception object.

Do NOT use `expectExceptionMessage()` — it is banned by Shopware's PHPStan (`NoExpectExceptionMessage`; soft-deprecated in PHPUnit 13.2, removed in 15.0). Use `expectExceptionObject()` so the class, message, and code are asserted from one source of truth.

```php
// PRIMARY PATTERN: expectExceptionObject for Shopware factory exceptions (preferred)
public function testThrowsOrderException(): void
{
    // Full object match: verifies type + message + code in one call
    $this->expectExceptionObject(OrderException::customerNotLoggedIn());

    $this->route->process($request, $context);
}

// WHEN NO FACTORY METHOD: construct the exception directly and pass it to expectExceptionObject
public function testThrowsOnInvalidInput(): void
{
    // expectExceptionObject asserts the type, message, and code of the constructed exception
    $this->expectExceptionObject(new \InvalidArgumentException('Input cannot be empty'));

    $this->service->process('');  // Throwing call LAST
}

// WEAK PATTERN — DO NOT USE for parameterized exceptions (CONV-009)
// $this->expectException(SomeException::class);  // Missing message/code/object
// $this->service->doSomething();
```
