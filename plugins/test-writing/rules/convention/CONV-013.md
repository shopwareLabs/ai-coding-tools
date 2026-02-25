---
id: CONV-013
title: Class-Level TestDox
legacy: W008
group: convention
enforce: should-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
---

## Class-Level TestDox

**Scope**: A,B,C,D,E | **Enforce**: Should fix

Class-level `#[TestDox]` attribute is discouraged. Use method-level TestDox only.

### Detection

```php
// INCORRECT - class-level TestDox
#[TestDox('A product service')]
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase
```

### Fix

```php
// CORRECT - no class-level TestDox
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase
{
    #[TestDox('creates product with valid data')]
    public function testCreatesProduct(): void {}
}
```

### Why

- Class-level creates incomplete sentences requiring method continuation
- Method-level sentences are self-contained and clearer
- Avoids dependency between class and method documentation
