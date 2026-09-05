---
id: CONV-011
title: Missing TestDox for Complex Test
group: convention
enforce: should-fix
test-types: all
test-categories: B,C
scope: phpunit
review-unit: method
scoped-review: include
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

### Suppression: Mechanical Expansion of the Method Name

Suppress the finding when the proposed `TestDox` text is a mechanical expansion of the method name — camelCase-split the method name (minus its `test` prefix), normalize it (lowercase, join with spaces), and compare it against the proposed TestDox text normalized the same way. An exact match after normalization means the annotation would say nothing the method name did not already say, so no finding is emitted. This is a deterministic string comparison, not a judgment call: run it before emitting the finding, not after.

```php
// SUPPRESSED - TestDox is the mechanical expansion of the method name, adds nothing
#[DataProvider('priceProvider')]
#[TestDox('calculates price')]
public function testCalculatesPrice(float $gross, float $net, float $tax): void
```
