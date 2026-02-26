---
id: CONV-012
title: Assertion Method Choice
group: convention
enforce: should-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
---

## Assertion Method Choice

**Scope**: A,B,C,D,E | **Enforce**: Should fix

Use specific assertion methods instead of boolean comparisons.

### Detection

```php
// INCORRECT - assertTrue with comparison
static::assertTrue($result === 5);
static::assertTrue($array === []);
static::assertFalse($string === null);
```

### Fix

```php
// CORRECT - specific assertions
static::assertEquals(5, $result);
static::assertEmpty($array);
static::assertNotNull($string);
```

### Common Assertion Mappings

| Instead of | Use |
|------------|-----|
| `assertTrue($a === $b)` | `assertEquals($b, $a)` |
| `assertTrue($a !== $b)` | `assertNotEquals($b, $a)` |
| `assertTrue($a === null)` | `assertNull($a)` |
| `assertFalse($a === null)` | `assertNotNull($a)` |
| `assertTrue(count($a) === 0)` | `assertEmpty($a)` |
| `assertTrue($a instanceof X)` | `assertInstanceOf(X::class, $a)` |
