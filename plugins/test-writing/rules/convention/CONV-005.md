---
id: CONV-005
title: Test Method Ordering
group: convention
enforce: consider
test-types: all
test-categories: A,B,C,D,E
scope: general
review-unit: class-structure
scoped-review: exclude
---

## Test Method Ordering

**Scope**: A,B,C,D,E | **Enforce**: Consider

Test methods MUST follow a logical progression pattern.

A finding under this rule states the complete target method order for the file, not only the pair of methods that are out of order.

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

A name can match more than one row. Apply the rows in this precedence and take the first match: Error case, then Edge case, then Config, then Variation, then Happy path. The table's row order is that precedence.

| Category | Indicators |
|----------|------------|
| Error case | Contains "throws", "exception", "invalid", "rejects", "fails" |
| Edge case | Contains "empty", "null", "zero", "max", "min", "boundary" |
| Config | Contains "mode", "option", "flag", "config", "setting" |
| Variation | Similar to happy path but with "with", "using", "for" modifiers |
| Happy path | Default — no row above matched |

`testThrowsWhenNameEmpty` matches both the Error case and the Edge case row; it is an Error case.

### Single-Category Exemption

A test class whose methods all fall into one category is exempt from this rule — it never reports a missing happy-path (or any other missing) category for such a class. A class that deliberately holds one half of a split (for example, all its error-case methods, with the happy-path methods living in a sibling class) has nothing to reorder relative to a category it does not contain.

### Exceptions

A method whose docblock or inline comment records a required adjacency to another method is not reordered.

### Known Gap

This rule orders the five categories relative to one another and defines no order within a category. Two orderings that differ only in the sequence of methods inside one category both satisfy it, and neither is reported as a violation of the other.
