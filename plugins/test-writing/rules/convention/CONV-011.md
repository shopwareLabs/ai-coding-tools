---
id: CONV-011
title: Missing TestDox for Complex Test
legacy: W003
group: convention
enforce: should-fix
test-types: all
test-categories: B,C
scope: phpunit
---

## Missing TestDox for Complex Test

**Scope**: B,C | **Enforce**: Should fix

Complex tests benefit from TestDox documentation.

### When to Require TestDox

- Data provider tests
- Tests with complex setup
- Tests with non-obvious assertions

### Detection

```php
// INCORRECT - data provider without TestDox
#[DataProvider('priceProvider')]
public function testCalculatesPrice(float $gross, float $net, float $tax): void
```

### Fix

```php
// CORRECT - with TestDox
#[DataProvider('priceProvider')]
#[TestDox('calculates price: gross=$gross, net=$net, tax=$tax')]
public function testCalculatesPrice(float $gross, float $net, float $tax): void
```
