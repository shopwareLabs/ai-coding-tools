---
id: CONV-005
title: Test Method Ordering
legacy: E010
group: convention
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: general
---

## Test Method Ordering

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Test methods MUST follow a logical progression pattern.

### Required Order

1. **Happy path tests** — core functionality with valid inputs
2. **Standard variations** — common alternative flows
3. **Configuration options** — optional features and flags
4. **Edge cases** — boundary conditions, special values
5. **Error cases** — failure scenarios, exceptions

### Detection

```php
// INCORRECT - error case before happy path
class ProductServiceTest extends TestCase
{
    public function testThrowsExceptionWhenInvalid(): void { ... }  // Error case first
    public function testCreatesProduct(): void { ... }              // Should be first
    public function testCreatesProductWithOptions(): void { ... }   // Should be second
}
```

### Fix

```php
class ProductServiceTest extends TestCase
{
    // 1. Happy path
    public function testCreatesProduct(): void { ... }

    // 2. Standard variations
    public function testCreatesProductWithCustomName(): void { ... }

    // 3. Configuration options
    public function testCreatesProductWithDebugMode(): void { ... }

    // 4. Edge cases
    public function testCreatesProductWithEmptyDescription(): void { ... }
    public function testCreatesProductWithMaxLengthName(): void { ... }

    // 5. Error cases
    public function testThrowsExceptionWhenNameEmpty(): void { ... }
    public function testThrowsExceptionWhenPriceNegative(): void { ... }
}
```

### Category Identification

| Category | Indicators |
|----------|------------|
| Happy path | No "edge", "empty", "null", "invalid", "throws", "exception" in name |
| Variation | Similar to happy path but with "with", "using", "for" modifiers |
| Config | Contains "mode", "option", "flag", "config", "setting" |
| Edge case | Contains "empty", "null", "zero", "max", "min", "boundary" |
| Error case | Contains "throws", "exception", "invalid", "rejects", "fails" |
