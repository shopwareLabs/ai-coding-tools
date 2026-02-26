---
id: CONV-008
title: Exception Expectation Order
group: convention
enforce: must-fix
test-types: all
test-categories: E
scope: phpunit
---

## Exception Expectation Order

**Scope**: E | **Enforce**: Must fix

Exception expectations MUST be set BEFORE the throwing call. Setting expectations after the throwing call is a functional bug — PHPUnit can only catch exceptions if it knows to expect them before they're thrown.

### Detection

```php
// INCORRECT - throwing call before expectations
public function testThrowsOnInvalidData(): void
{
    $this->service->validate(['name' => '']);  // Throws BEFORE expectations set!

    $this->expectException(InvalidProductException::class);
    $this->expectExceptionMessage('Product name cannot be empty');
}
```

### Fix

```php
// CORRECT - expectations BEFORE throwing call
public function testThrowsOnInvalidData(): void
{
    $this->expectException(InvalidProductException::class);
    $this->expectExceptionMessage('Product name cannot be empty');

    $this->service->validate(['name' => '']);  // Throwing call LAST
}
```

### Complete Exception Testing Pattern

```php
public function testThrowsExceptionForInvalidProduct(): void
{
    // 1. Set up expectations FIRST
    $this->expectException(ProductNotFoundException::class);
    $this->expectExceptionMessage('Product with ID "invalid-id" not found');

    // 2. Set up test data
    $repo = new StaticEntityRepository([
        new ProductCollection([])  // Empty - product not found
    ]);
    $service = new ProductService($repo);

    // 3. Call throwing method LAST
    $service->getById('invalid-id');
}
```

### Using expectExceptionObject

For exceptions created via factory methods:

```php
public function testThrowsCustomerNotLoggedInException(): void
{
    $this->expectExceptionObject(OrderException::customerNotLoggedIn());

    $this->orderService->placeOrder($cart, $context);
}
```
