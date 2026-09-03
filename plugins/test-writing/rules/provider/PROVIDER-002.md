---
id: PROVIDER-002
title: Data Provider Naming Convention
group: provider
enforce: should-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit,shopware
review-unit: method
scoped-review: include
---

## PROVIDER-002 — Data Provider Naming Convention

**Scope**: A,B,C,D,E | **Enforce**: Should fix

Data provider methods SHOULD end in the suffix `Provider`, prefixed by a descriptor of the cases the provider yields.

The rule constrains the SUFFIX only. Any descriptor that identifies the cases is acceptable — noun phrase, adjective phrase, or verb phrase alike. Do NOT flag a name for its first word's part of speech.

### Detection

Flag a data provider method whose name does not end in `Provider`.

```php
// INCORRECT patterns
public static function provideValidEmails(): iterable         // Provider as prefix, not suffix
public static function dataProviderForValidation(): iterable  // Provider as prefix, not suffix
public static function getTestCases(): iterable               // no suffix
public static function cases(): iterable                      // no suffix, and too generic
```

### Fix

```php
// CORRECT - suffix pattern: {descriptor}Provider
public static function validEmailProvider(): iterable         // adjective phrase
public static function validationProvider(): iterable         // noun
public static function referencePriceCalculationProvider(): iterable  // noun phrase
public static function throwsOnMissingContextProvider(): iterable     // verb phrase
```

### Naming Convention

Format: `{descriptor}Provider`. Pick the descriptor that most directly names the set of cases yielded, and keep it specific enough that two providers on the same test class do not read alike.

| Test Method | Acceptable Provider Names |
|---|---|
| `testAcceptsValidEmail` | `validEmailProvider`, `acceptsValidEmailProvider` |
| `testThrowsMissingEntity` | `missingEntityProvider`, `throwsMissingEntityProvider` |
| `testLoadsConfig` | `configProvider`, `loadsConfigProvider` |

`DataProvider` is an accepted spelling of the suffix (`compareDataProvider`).

### Why

- The suffix makes the method's role readable at its declaration, where the `#[DataProvider(...)]` reference is not in view
- Shopware trunk uses the suffix form across its unit suite — e.g. `referencePriceCalculationProvider` in `tests/unit/Core/Checkout/Cart/Price/GrossPriceCalculatorTest.php`, `compareDataProvider` in `tests/unit/Core/Framework/Util/FloatComparatorTest.php`, `throwsOnMissingContextProvider` in `tests/unit/Core/Framework/Routing/ApiRouteScopeTest.php`
- Constraining the descriptor's part of speech would flag nearly every existing Shopware provider, which is why this rule does not
