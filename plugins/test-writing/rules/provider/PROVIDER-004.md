---
id: PROVIDER-004
title: Description-Only Data Provider Parameter
legacy: W018
group: provider
enforce: should-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
---

## PROVIDER-004 — Description-Only Data Provider Parameter

**Scope**: A,B,C,D,E | **Enforce**: Should fix

A data provider passes a `$description` (or similar) parameter that is only interpolated into `#[TestDox]` and never used in test logic. PHPUnit's `$_dataName` placeholder resolves to the yield key automatically — no extra parameter needed.

### Detection

Flag when a test method parameter:
1. Appears in the `#[TestDox('...$param')]` attribute
2. Is NOT referenced in any assertion, method call, or variable assignment within the test body

```php
// PROVIDER-004 - $description is never used in test logic, only in TestDox
#[DataProvider('distributeProvider')]
#[TestDox('distributes indexed data: $description')]
public function testDistribute(string $description, mixed $data, array $consumers, array $expected): void
{
    $result = $config->distribute($data, $consumers);
    static::assertSame($expected, $result);
}
```

### Fix

Replace the parameter reference with `$_dataName` and remove the parameter from the method signature and data provider yields.

```php
// CORRECT - $_dataName resolves to the yield key automatically
#[DataProvider('distributeProvider')]
#[TestDox('distributes indexed data: $_dataName')]
public function testDistribute(mixed $data, array $consumers, array $expected): void
{
    $result = $config->distribute($data, $consumers);
    static::assertSame($expected, $result);
}
```
