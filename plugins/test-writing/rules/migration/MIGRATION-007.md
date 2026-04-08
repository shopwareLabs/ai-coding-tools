---
id: MIGRATION-007
title: assertSame over assertEquals
group: migration
enforce: must-fix
test-types: migration
test-categories: all
scope: shopware
---

## assertSame over assertEquals

**Scope**: all | **Enforce**: Must fix

Use `assertSame()` (strict identity, type-safe) instead of `assertEquals()` (loose comparison, type-coercing).

### Detection

Detect any usage of `assertEquals(` or `static::assertEquals(` in the test file.

```php
// INCORRECT - loose comparison
static::assertEquals(1718615305, $migration->getCreationTimestamp());
static::assertEquals('test', $salutationLetter);
```

### Fix

```php
// CORRECT - strict comparison
static::assertSame(1718615305, $migration->getCreationTimestamp());
static::assertSame('test', $salutationLetter);
```
