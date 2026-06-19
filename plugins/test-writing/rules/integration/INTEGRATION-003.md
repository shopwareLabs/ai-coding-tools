---
id: INTEGRATION-003
title: Non-transactional writes are cleaned up
group: integration
enforce: must-fix
test-types: integration
test-categories: all
scope: shopware
review-unit: method
---

## Non-transactional writes are cleaned up

**Scope**: all | **Enforce**: Must fix

`IntegrationTestBehaviour` wraps the test in a DBAL transaction that is rolled back in `tearDown()`. Writes that bypass the transaction (raw `Connection::executeStatement()` with DDL, `TRUNCATE`, manual filesystem writes, cache writes, message queue dispatch to a real broker) leak state across tests. They must be cleaned up explicitly in `tearDown()` or the equivalent attribute.

### Detection

1. Find every `Connection::executeStatement(`, `Connection::executeQuery(`, `$this->connection->...`, `static::getContainer()->get(Connection::class)->...` call in the test class.
2. Check the SQL. DDL (`CREATE`, `ALTER`, `DROP`, `TRUNCATE`) and writes to non-transactional engines/tables fall outside the wrapping transaction.
3. Filesystem writes (`file_put_contents`, `mkdir`, `Filesystem::dumpFile`) and cache writes (`CacheItemPoolInterface::save`) also escape the transaction.
4. For each such write, verify there is a matching teardown that reverses it (drop the table, delete the file, clear the cache key) in `tearDown()`, `tearDownAfterClass()`, or wrapped in a try/finally inside the test.

```php
// INCORRECT - DDL outside transaction, no teardown
public function testTableSchema(): void
{
    $this->connection->executeStatement('CREATE TABLE my_temp_table (id INT)');
    // assertions...
}
```

### Fix

```php
// CORRECT - explicit cleanup
public function testTableSchema(): void
{
    $this->connection->executeStatement('CREATE TABLE my_temp_table (id INT)');
    try {
        // assertions...
    } finally {
        $this->connection->executeStatement('DROP TABLE IF EXISTS my_temp_table');
    }
}
```

Or, when the cleanup applies to the whole class:

```php
protected function tearDown(): void
{
    $this->connection->executeStatement('DROP TABLE IF EXISTS my_temp_table');
    parent::tearDown();
}
```
