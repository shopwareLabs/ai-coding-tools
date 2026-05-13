---
id: MIGRATION-005
title: Separate try/catch per cleanup statement — catch Throwable
group: migration
enforce: must-fix
test-types: migration
test-categories: all
scope: shopware
---

## Separate try/catch per cleanup statement — catch Throwable

**Scope**: all | **Enforce**: Must fix

Independent cleanup statements must each have their own `try/catch` block. Catch `\Throwable`, not `\Exception`. This applies to any cleanup site in a migration test — private helper methods invoked from test methods, `try/finally` blocks inside a test, etc. (Per MIGRATION-009 these statements must not live in `setUp()`/`tearDown()`.)

### Detection — Multiple statements in single try

```php
// INCORRECT - if first statement fails, second never executes
private function revertMigration(Connection $connection): void
{
    try {
        $connection->executeStatement('ALTER TABLE `state_machine_history` DROP FOREIGN KEY `fk.state_machine_history.integration_id`');
        $connection->executeStatement('ALTER TABLE `state_machine_history` DROP COLUMN `integration_id`');
    } catch (\Exception $e) {
        // both statements skipped on first failure
    }
}
```

### Fix — Multiple statements in single try

```php
// CORRECT - each statement guarded by its own existence check
private function revertMigration(Connection $connection): void
{
    if (TableHelper::foreignKeyExists($connection, 'state_machine_history', 'fk.state_machine_history.integration_id')) {
        $connection->executeStatement('ALTER TABLE `state_machine_history` DROP FOREIGN KEY `fk.state_machine_history.integration_id`');
    }

    if (TableHelper::columnExists($connection, 'state_machine_history', 'integration_id')) {
        $connection->executeStatement('ALTER TABLE `state_machine_history` DROP COLUMN `integration_id`');
    }
}
```

When existence cannot be cheaply checked, use one `try/catch (\Throwable)` per statement:

```php
private function revertMigration(Connection $connection): void
{
    try {
        $connection->executeStatement('ALTER TABLE `state_machine_history` DROP FOREIGN KEY `fk.state_machine_history.integration_id`');
    } catch (\Throwable) {
    }

    try {
        $connection->executeStatement('ALTER TABLE `state_machine_history` DROP COLUMN `integration_id`');
    } catch (\Throwable) {
    }
}
```

### Detection — Wrong exception type

```php
// INCORRECT - catches Exception instead of Throwable
try {
    $this->connection->executeStatement('ALTER TABLE `foo` DROP COLUMN `bar`');
} catch (\Exception $e) {
}
```

### Fix — Wrong exception type

```php
// CORRECT - catches Throwable
try {
    $this->connection->executeStatement('ALTER TABLE `foo` DROP COLUMN `bar`');
} catch (\Throwable) {
}
```
