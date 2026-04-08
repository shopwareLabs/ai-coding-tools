---
id: MIGRATION-008
title: testGetCreationTimestamp must exist
group: migration
enforce: must-fix
test-types: migration
test-categories: all
scope: shopware
---

## testGetCreationTimestamp must exist

**Scope**: all | **Enforce**: Must fix

Every migration test must include a `testGetCreationTimestamp` method that verifies the timestamp returned by `getCreationTimestamp()` matches the expected integer value using `assertSame`.

### Detection Algorithm

1. Search the test class for a method named `testGetCreationTimestamp`
2. If missing: violation
3. If present: verify it contains a `static::assertSame(` call with an integer literal and `->getCreationTimestamp()`

```php
// INCORRECT - method missing entirely
#[CoversClass(Migration1718615305AddEuToCountryTable::class)]
class Migration1718615305AddEuToCountryTableTest extends TestCase
{
    // no testGetCreationTimestamp method
}
```

### Fix

```php
// CORRECT
public function testGetCreationTimestamp(): void
{
    static::assertSame(1718615305, (new Migration1718615305AddEuToCountryTable())->getCreationTimestamp());
}
```

### Incorrect Patterns

```php
// INCORRECT - uses assertEquals (also triggers MIGRATION-007)
public function testGetCreationTimestamp(): void
{
    static::assertEquals(1718615305, (new Migration1718615305AddEuToCountryTable())->getCreationTimestamp());
}

// INCORRECT - missing assertSame, uses assertTrue
public function testGetCreationTimestamp(): void
{
    $migration = new Migration1718615305AddEuToCountryTable();
    static::assertTrue($migration->getCreationTimestamp() > 0);
}
```
