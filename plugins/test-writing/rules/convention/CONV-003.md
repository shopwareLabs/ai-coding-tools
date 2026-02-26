---
id: CONV-003
title: Ambiguous or Non-Descriptive Test Name
group: convention
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: general,shopware
---

## Ambiguous or Non-Descriptive Test Name

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Test names MUST be descriptive and follow the naming convention: `test` + `Action` + `Condition` + `ExpectedResult`.

### Ambiguous Names (Flag)

- `testEdgeCases()`
- `testValidation()`
- `testItWorks()`
- `testHelper()`

### BDD-Style Names (Flag)

- `testItLoadsProducts()`
- `testItCreatesOrder()`
- Any `testIt...` pattern

Shopware convention uses action-based naming (98% of existing tests). BDD-style adds redundant "It" without semantic value.

### Detection — BDD to Action-Based

```php
// INCORRECT - BDD-style
public function testItLoadsProducts(): void
public function testItCreatesOrderSuccessfully(): void

// CORRECT - Action-based
public function testLoadsProducts(): void
public function testCreatesOrderSuccessfully(): void
```

### Implementation-Coupled Names (see also CONV-010)

```php
// Flag as CONV-010 instead
public function testSymfonyValidatorIntegration(): void
public function testDoctrineQueryBuilderUsage(): void
```

### Good Names

```php
public function testCreatesOrderWhenPaymentSucceeds(): void
public function testRejectsLoginWithInvalidCredentials(): void
public function testThrowsExceptionWhenProductNotFound(): void
public function testAcceptsUnicodeCharactersInUsername(): void
```
