---
id: CONV-001
title: Attribute Order
group: convention
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
---

## Attribute Order

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Attributes MUST follow strict ordering: PHPDoc first, then DataProviders, then TestDox last.

### Required Order

```
1. PHPDoc (/** */)           <- FIRST if present
2. DataProvider attributes   <- SECOND
3. TestDox                   <- ALWAYS LAST
4. Method declaration        <- with test prefix
```

### Detection

```php
// INCORRECT - TestDox before DataProvider
#[TestDox('validates with $input')]
#[DataProvider('inputProvider')]
public function testInput($input): void
```

### Fix

```php
// CORRECT - proper order
/**
 * @param array<string, mixed> $config
 */
#[DataProvider('inputProvider')]
#[TestDox('validates with $input')]
public function testInput($input): void
```

### TestWithJson Example

```php
// CORRECT - TestWithJson with TestDox
#[TestWithJson('["",{"required":true},"Value cannot be empty"]')]
#[TestWithJson('[null,{"required":true},"Value cannot be null"]')]
#[TestDox('validates required field with $value')]
public function testRequiredFieldValidation($value, $config, $expectedError): void
```

### Valid Examples

```php
// Minimal - just test prefix
public function testCreatesProduct(): void

// With TestDox
#[TestDox('creates product with valid data')]
public function testCreatesProduct(): void

// With DataProvider and TestDox
#[DataProvider('productDataProvider')]
#[TestDox('creates product with $name')]
public function testCreatesProduct(string $name): void

// Full with PHPDoc
/**
 * @param array<string, mixed> $data
 */
#[DataProvider('productDataProvider')]
#[TestDox('creates product with $name')]
public function testCreatesProduct(string $name, array $data): void
```
