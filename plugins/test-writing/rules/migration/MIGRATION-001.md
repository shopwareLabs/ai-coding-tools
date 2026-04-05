---
id: MIGRATION-001
title: Idempotency — update() called at least twice
group: migration
enforce: must-fix
test-types: migration
test-categories: all
scope: shopware
---

## Idempotency — update() called at least twice

**Scope**: all | **Enforce**: Must fix

The migration's `update()` method must be called at least twice in sequence to verify re-execution safety.

### Detection

Count calls to `->update(` on the migration instance variable within each test method (excluding `testGetCreationTimestamp`). At least one test method must call `update()` >= 2 times.

```php
// INCORRECT - single call
public function testMigration(): void
{
    $migration = new Migration1234AddFoo();
    $migration->update($this->connection);

    static::assertTrue(TableHelper::columnExists($this->connection, 'foo', 'bar'));
}
```

### Fix

```php
// CORRECT - called twice
public function testMigration(): void
{
    $migration = new Migration1234AddFoo();
    $migration->update($this->connection);
    $migration->update($this->connection);

    static::assertTrue(TableHelper::columnExists($this->connection, 'foo', 'bar'));
}
```
