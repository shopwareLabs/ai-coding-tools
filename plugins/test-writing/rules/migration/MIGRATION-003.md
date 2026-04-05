---
id: MIGRATION-003
title: Test must not reuse migration helper methods
group: migration
enforce: must-fix
test-types: migration
test-categories: all
scope: shopware
---

## Test must not reuse migration helper methods

**Scope**: all | **Enforce**: Must fix

Tests must verify results independently. Calling migration instance methods other than `update()`, `updateDestructive()`, and `getCreationTimestamp()` couples the test to the implementation.

### Detection Algorithm

1. Identify the migration instance variable (typically `$migration`)
2. Find all method calls on that variable: `$migration->methodName(`
3. Allowed methods: `update`, `updateDestructive`, `getCreationTimestamp`
4. Any other method call = violation

```php
// INCORRECT - reuses migration's helper method for verification
public function testMigration(): void
{
    $migration = new Migration1234AddEuCountries();
    $migration->update($this->connection);
    $migration->update($this->connection);

    $euCodes = $migration->getEuCountryCodes(); // MIGRATION-003: reuses helper
    static::assertCount(27, $euCodes);
}
```

### Fix

```php
// CORRECT - verifies independently via database query
public function testMigration(): void
{
    $migration = new Migration1234AddEuCountries();
    $migration->update($this->connection);
    $migration->update($this->connection);

    $euCodes = $this->connection->fetchFirstColumn(
        'SELECT iso FROM country WHERE is_eu = 1'
    );
    static::assertCount(27, $euCodes);
}
```
