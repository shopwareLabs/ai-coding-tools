---
id: CONV-004
title: Expectation Method Call Style
group: convention
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
review-unit: method
scoped-review: include
---

## Expectation Method Call Style

**Scope**: A,B,C,D,E | **Enforce**: Must fix

`expectException*()` and the other `$this->expect*()` setup methods (including `expectNotToPerformAssertions()`) configure PHPUnit state before the throwing call. They MUST use `$this->`. Using `static::` on them is CONV-004.

### Detection

```php
// INCORRECT - expectation setup called statically
static::expectException(ProductNotFoundException::class);   // CONV-004
static::expectNotToPerformAssertions();                     // CONV-004
```

### Fix

```php
// CORRECT - expectation setup on $this
$this->expectException(ProductNotFoundException::class);
$this->expectNotToPerformAssertions();
```

| Wrong | Correct |
|-------|---------|
| `static::expectException(Foo::class)` | `$this->expectException(Foo::class)` |
| `static::expectExceptionObject($e)` | `$this->expectExceptionObject($e)` |
| `static::expectExceptionCode(42)` | `$this->expectExceptionCode(42)` |
| `static::expectNotToPerformAssertions()` | `$this->expectNotToPerformAssertions()` |

### Out of Scope: Assertion Style

Assertion style (`static::assert*`) and expectation style (`$this->expect*`) are **independent families**. A `$this->expect*()` call is correct and is NEVER a deviation from the `static::` assertion convention — do not flag `$this->expect*()` as CONV-004 because the file's assertions use `static::`.

`$this->assert*()` in place of `static::assert*()` is not a review finding at all. php-cs-fixer's `php_unit_test_case_static_method_calls` rewrites every `assert*` call to `static::` mechanically, and its `methods` map pins the invocation matchers (`$this->once()` and its siblings) back to `$this->`. Report neither; ECS settles both.
