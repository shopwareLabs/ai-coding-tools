---
id: PROVIDER-003
title: Yield vs Return Array
group: provider
enforce: should-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
---

## PROVIDER-003 — Yield vs Return Array

**Scope**: A,B,C,D,E | **Enforce**: Should fix

Data provider methods SHOULD use `iterable` return type with `yield` statements, not `array` return type with `return [...]`.

### Why

- **yield is lazy**: `yield` statements are evaluated one case at a time, reducing memory for large datasets
- **iterable is idiomatic**: PHPUnit data providers conventionally use generators
- **Consistency**: The vast majority of Shopware data providers use `yield`

### Detection

Trigger when:
1. A data provider method has `array` return type annotation, OR
2. A data provider method uses `return [...]` or `return array(...)` syntax

```php
// INCORRECT - array return type with return []
public static function validEmailProvider(): array
{
    return [
        'standard email' => ['user@example.com'],
        'with subdomain' => ['user@mail.example.com'],
    ];
}
```

### Fix

```php
// CORRECT - iterable return type with yield
public static function validEmailProvider(): iterable
{
    yield 'standard email' => ['user@example.com'];
    yield 'with subdomain' => ['user@mail.example.com'];
}
```

### Static Method Requirement

Data providers must be static methods:

```php
// CORRECT - static method
public static function validEmailProvider(): iterable
{
    yield 'standard email' => ['user@example.com'];
}

// INCORRECT - instance method
public function validEmailProvider(): iterable
{
    yield 'standard email' => ['user@example.com'];
}
```
