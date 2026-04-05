---
id: MIGRATION-002
title: Idempotency — updateDestructive() called at least twice
group: migration
enforce: must-fix
test-types: migration
test-categories: all
scope: shopware
---

## Idempotency — updateDestructive() called at least twice

**Scope**: all | **Enforce**: Must fix

When the source migration's `updateDestructive()` method contains logic (not an empty body or only `parent::updateDestructive()`), the test must call it at least twice.

### Detection Algorithm

1. Read the source migration class (from `#[CoversClass]`)
2. Find the `updateDestructive()` method body
3. If the body contains statements beyond `{}`, `{ }`, or only `parent::updateDestructive($connection);`, the method has logic
4. If it has logic: verify the test calls `->updateDestructive(` at least twice in at least one test method
5. If it has no logic: this rule does not apply — skip

```php
// INCORRECT - source has updateDestructive logic but test only calls once
public function testMigrationUpdateDestructive(): void
{
    $migration = new Migration1234RemoveFoo();
    $migration->update($this->connection);
    $migration->updateDestructive($this->connection);

    static::assertFalse(TableHelper::columnExists($this->connection, 'foo', 'bar'));
}
```

### Fix

```php
// CORRECT - called twice
public function testMigrationUpdateDestructive(): void
{
    $migration = new Migration1234RemoveFoo();
    $migration->update($this->connection);
    $migration->updateDestructive($this->connection);
    $migration->updateDestructive($this->connection);

    static::assertFalse(TableHelper::columnExists($this->connection, 'foo', 'bar'));
}
```
