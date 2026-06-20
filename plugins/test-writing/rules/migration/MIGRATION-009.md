---
id: MIGRATION-009
title: setUp/tearDown must not mutate DB state
group: migration
enforce: must-fix
test-types: migration
test-categories: all
scope: shopware
review-unit: method
scoped-review: include
---

## setUp/tearDown must not mutate DB state

**Scope**: all | **Enforce**: Must fix

`setUp()` and `tearDown()` must not contain DDL or DML statements that mutate the database. Per-test cleanup belongs inside the test method that needs it — as a private helper invoked from the test, or wrapped in `try/finally`.

### Rationale

Every migration test class contains `testGetCreationTimestamp` (MIGRATION-008), which never touches the database. Mutations in lifecycle hooks therefore run around a test that doesn't need them and leaves global state the test methods don't account for. Concrete failure modes observed in `shopware/shopware` PR #16799:

- A `DROP COLUMN` in `setUp()` runs before `testGetCreationTimestamp` (alphabetical order), drops a schema element, and never gets restored — sibling test classes that share the non-transactional database then fail.
- A `DELETE FROM ... WHERE id = :id` in `tearDown()` with `assertSame(1, $deletedRowCount)` fails for `testGetCreationTimestamp`, which never inserted the row.

DDL is not transactional in MySQL, so `DatabaseTransactionBehaviour` / `MigrationTestTrait` do not undo `ALTER TABLE` / `CREATE TABLE` / `DROP TABLE` from a hook either.

### Detection Algorithm

1. Read the bodies of `setUp()` and `tearDown()`.
2. Permit (non-mutating):
   - Connection acquisition: `KernelLifecycleManager::getConnection()`, `$this->getContainer()->get(Connection::class)`
   - PHP-side state: assignments to properties, `Uuid::randomBytes()`, scalar setup
   - Read-only fetches: `fetchOne`, `fetchAll`, `fetchAssociative` *only when the result is stored, not when used to gate a mutation in the same hook*
3. Flag (mutating) — also inside `try/catch` wrappers:
   - `executeStatement(...)` with `ALTER`, `CREATE`, `DROP`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REPLACE`
   - `$connection->insert(...)`, `$connection->update(...)`, `$connection->delete(...)`
   - `createSchemaManager()->...` calls that mutate schema
4. Each flagged statement is one violation.

### Incorrect Patterns

```php
// INCORRECT - mutating schema in setUp
protected function setUp(): void
{
    $this->connection = KernelLifecycleManager::getConnection();

    try {
        $this->connection->executeStatement('ALTER TABLE `app` DROP COLUMN `self_managed`');
    } catch (\Throwable) {
    }
}
```

```php
// INCORRECT - per-test cleanup + assertion in tearDown
protected function tearDown(): void
{
    $deletedRowCount = $this->connection->executeStatement(
        'DELETE FROM `order_delivery_position` WHERE id = :id',
        ['id' => $this->deliveryId]
    );

    static::assertSame(1, (int) $deletedRowCount);
}
```

### Fix — Private helper called from the test method

```php
// CORRECT - cleanup scoped to the test that needs it
protected function setUp(): void
{
    $this->connection = KernelLifecycleManager::getConnection();
}

public function testMigration(): void
{
    $this->dropSelfManagedColumn();

    $migration = new Migration1713345551AddAppManagedColumn();
    $migration->update($this->connection);
    $migration->update($this->connection);

    static::assertTrue(TableHelper::columnExists($this->connection, 'app', 'self_managed'));
}

private function dropSelfManagedColumn(): void
{
    try {
        $this->connection->executeStatement('ALTER TABLE `app` DROP COLUMN `self_managed`');
    } catch (\Throwable) {
    }
}
```

### Fix — `try/finally` for restore-after-mutation

When a test method must restore state regardless of assertion outcome, wrap the test body in `try/finally` instead of moving the restore into `tearDown()`:

```php
// CORRECT - finally runs only for this test method
public function testUpdate(): void
{
    $this->createDeliveryPosition();

    try {
        $migration = new Migration1767604966UpdateTotalPriceOrderDeliveryPosition();
        $migration->update($this->connection);
        $migration->update($this->connection);

        $value = (float) $this->connection->fetchOne(
            'SELECT total_price FROM order_delivery_position WHERE id = :id',
            ['id' => $this->deliveryId]
        );

        static::assertSame(12.12, $value);
    } finally {
        $this->connection->executeStatement(
            'DELETE FROM `order_delivery_position` WHERE id = :id',
            ['id' => $this->deliveryId]
        );
    }
}
```

### Interaction with Other Rules

- **MIGRATION-004** still applies: cleanup must exist somewhere. This rule only constrains *where* it lives.
- **MIGRATION-005** still applies to the try/catch shape inside the private helper (one statement per try, catch `\Throwable`).
