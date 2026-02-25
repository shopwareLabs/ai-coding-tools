---
id: PROVIDER-001
title: Data Provider Key Quality
legacy: W004
group: provider
enforce: should-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
---

## PROVIDER-001 — Data Provider Key Quality

**Scope**: A,B,C,D,E | **Enforce**: Should fix

Data provider yield keys must be present AND descriptive. Triggers when:
- Keys are missing entirely (implicit numeric indices)
- Keys are present but non-descriptive (e.g., `'case1'`, `'test_1'`, `'a'`)

### Detection — Missing Keys

```php
// INCORRECT - no keys (implicit numeric indices 0, 1, 2...)
public static function dataProvider(): iterable
{
    yield ['valid@email.com', true];
    yield ['invalid', false];
}
```

### Detection — Non-Descriptive Keys

```php
// INCORRECT - keys exist but are not descriptive
public static function configProvider(): iterable
{
    yield 'case1' => [new StaticSystemConfigService([]), 'default'];
    yield 'case2' => [new StaticSystemConfigService(['key' => 'val']), 'val'];
}
```

### Fix

```php
// CORRECT - descriptive keys explain the test case
public static function configProvider(): iterable
{
    yield 'empty config uses default' => [
        new StaticSystemConfigService([]),
        'default',
    ];
    yield 'custom config overrides default' => [
        new StaticSystemConfigService(['key' => 'val']),
        'val',
    ];
}
```

### Relationship to DESIGN-004

| Rule | Checks | Fails On |
|------|--------|----------|
| PROVIDER-001 | Key is descriptive (not `case1`) | `yield 'case1' => [...]` |
| DESIGN-004 | Key justifies existence | `yield 'another valid email' => [...]` |

A test case can pass PROVIDER-001 (descriptive key) but fail DESIGN-004 (no justification):

```php
// Passes PROVIDER-001, FAILS DESIGN-004
yield 'small positive number' => [1];
yield 'large positive number' => [1000];

// Passes BOTH
yield 'positive triggers success' => [1];
yield 'negative triggers error' => [-1];
```
