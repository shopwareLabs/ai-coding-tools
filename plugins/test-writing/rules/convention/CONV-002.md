---
id: CONV-002
title: Test Method Identification
group: convention
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit,shopware
---

## Test Method Identification

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Test methods MUST use `test` prefix and MUST NOT use `#[Test]` attribute (Shopware convention).

### Rules

- Method name MUST start with `test` prefix
- Method MUST NOT have `#[Test]` attribute (even with `test` prefix — redundant)

### Detection — Missing Prefix

```php
// INCORRECT - missing prefix, relies on attribute
#[Test]
public function createsUser(): void
```

### Detection — Redundant Attribute

```php
// INCORRECT - redundant attribute with prefix
#[Test]
public function testCreatesUser(): void
```

### Fix

```php
// CORRECT - prefix only, no attribute
public function testCreatesUser(): void
```
