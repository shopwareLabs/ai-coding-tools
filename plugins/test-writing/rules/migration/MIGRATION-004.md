---
id: MIGRATION-004
title: Test-created tables and data must be cleaned up
group: migration
enforce: must-fix
test-types: migration
test-categories: all
scope: shopware
---

## Test-created tables and data must be cleaned up

**Scope**: all | **Enforce**: Must fix

Tests that create temporary tables, insert data outside transactions, or modify schema must clean up in `tearDown()` or a rollback method.

### Detection Algorithm

1. Check if the test class uses `MigrationTestTrait` or `DatabaseTransactionBehaviour` — if so, auto-rollback satisfies this rule for data changes (but not for DDL like `CREATE TABLE` which is not transactional in MySQL)
2. Scan test methods and setUp for DDL operations: `CREATE TABLE`, `ALTER TABLE ... ADD`
3. For each DDL operation, verify a matching cleanup exists:
   - `CREATE TABLE foo` needs `DROP TABLE ... foo` in tearDown, setUp, or a private rollback method
   - `ALTER TABLE foo ADD COLUMN bar` needs `ALTER TABLE foo DROP COLUMN bar` in cleanup
4. Missing cleanup = violation

```php
// INCORRECT - creates table but never cleans up
public function testMigration(): void
{
    $this->connection->executeStatement('DROP TABLE IF EXISTS `test_table`');

    $migration = new Migration1234CreateTestTable();
    $migration->update($this->connection);
    $migration->update($this->connection);

    static::assertTrue(TableHelper::columnExists($this->connection, 'test_table', 'id'));
    // table left behind after test
}
```

### Fix

```php
// CORRECT - tearDown removes the table
protected function tearDown(): void
{
    $this->connection->executeStatement('DROP TABLE IF EXISTS `test_table`');
}

public function testMigration(): void
{
    $this->connection->executeStatement('DROP TABLE IF EXISTS `test_table`');

    $migration = new Migration1234CreateTestTable();
    $migration->update($this->connection);
    $migration->update($this->connection);

    static::assertTrue(TableHelper::columnExists($this->connection, 'test_table', 'id'));
}
```

### When Auto-Rollback Suffices

Tests using `MigrationTestTrait` or `DatabaseTransactionBehaviour` automatically rollback DML (INSERT, UPDATE, DELETE) — no explicit cleanup needed for data changes. DDL operations (`CREATE TABLE`, `ALTER TABLE`) are NOT rolled back by transactions in MySQL and always require explicit cleanup.
