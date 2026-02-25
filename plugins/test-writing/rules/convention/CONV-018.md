---
id: CONV-018
title: expectExceptionObject for Factory Exceptions
legacy: I004
group: convention
enforce: consider
test-types: all
test-categories: E
scope: phpunit
---

## expectExceptionObject for Factory Exceptions

**Scope**: E | **Enforce**: Consider

When exceptions are created via factory methods, consider using `expectExceptionObject()` for complete instance matching.

### When to Suggest

Test uses `expectException()` + `expectExceptionMessage()` for an exception that has a factory method.

### Example

```php
// Could be improved
$this->expectException(OrderException::class);
$this->expectExceptionMessage('Customer is not logged in.');

// Better - uses factory method
$this->expectExceptionObject(OrderException::customerNotLoggedIn());
```
