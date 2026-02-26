---
id: PROVIDER-002
title: Data Provider Naming Convention
group: provider
enforce: should-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit,shopware
---

## PROVIDER-002 — Data Provider Naming Convention

**Scope**: A,B,C,D,E | **Enforce**: Should fix

Data provider methods SHOULD use `{action}Provider` suffix naming pattern.

### Detection

```php
// INCORRECT patterns
public static function provideValidEmails(): iterable     // prefix pattern
public static function dataProviderForValidation(): iterable  // verbose prefix
public static function getTestCases(): iterable           // non-standard
public static function cases(): iterable                  // too generic
```

### Fix

```php
// CORRECT - suffix pattern: {action}Provider
public static function validEmailProvider(): iterable
public static function validationProvider(): iterable
public static function testCaseProvider(): iterable
```

### Naming Convention

Format: `{action}Provider` where `{action}` starts with a **present-tense verb** describing what the test method does.

| Test Method | Provider Name |
|---|---|
| `testAcceptsValidEmail` | `acceptsValidEmailProvider` |
| `testThrowsMissingEntity` | `throwsMissingEntityProvider` |
| `testReturnsNullForMissingKey` | `returnsNullForMissingKeyProvider` |
| `testLoadsConfig` | `loadsConfigProvider` |

Adjective/noun starts are not fixed names (still PROVIDER-002): `missingEntityProvider` ("missing" is adjective), `invalidDepthProvider` ("invalid" is adjective), `emptyAssociationsProvider` ("empty" is adjective).

### Why

- Matches 78% of existing Shopware data providers
- Clearly indicates the method is a data provider via suffix
- Action-based naming mirrors test method naming convention
