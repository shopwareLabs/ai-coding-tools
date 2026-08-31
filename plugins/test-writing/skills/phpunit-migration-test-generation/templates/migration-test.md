# Migration Test Template

Single template with conditional sections. The generator selects which sections to include based on source analysis.

## Base Template (always included)

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Migration\{Area}\{Version};

use Doctrine\DBAL\Connection;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;
use Shopware\Core\Framework\Log\Package;
{CONDITIONAL_IMPORTS}
use {MigrationFullClassName};

/**
 * @internal
 */
#[Package('{package}')]
#[CoversClass({MigrationClassName}::class)]
class {MigrationClassName}Test extends TestCase
{
    {CONDITIONAL_TRAITS}

    private Connection $connection;

    protected function setUp(): void
    {
        {CONDITIONAL_SETUP}
    }

    {CONDITIONAL_TEARDOWN}

    public function testGetCreationTimestamp(): void
    {
        static::assertSame({timestamp}, (new {MigrationClassName}())->getCreationTimestamp());
    }

    {CONDITIONAL_TEST_METHODS}

    {CONDITIONAL_HELPER_METHODS}
}
```

## Conditional: Schema-Add Test

Include when source analysis detects `CREATE TABLE`, `addColumn()`, or `ALTER TABLE ... ADD`.

### Additional imports

```php
use Shopware\Core\Framework\Test\TestCaseBase\KernelTestBehaviour;
use Shopware\Core\Framework\Util\Database\TableHelper;
```

### Traits

```php
use KernelTestBehaviour;
```

### setUp

```php
$this->connection = static::getContainer()->get(Connection::class);
```

### Test method

```php
public function testMigration(): void
{
    $this->rollback();

    try {
        $migration = new {MigrationClassName}();
        $migration->update($this->connection);
        $migration->update($this->connection);

        static::assertTrue(TableHelper::columnExists($this->connection, '{table}', '{column}'));
        // Add assertions for each column/table/index added
    } finally {
        // Restore the original schema even if an assertion fails (DDL is not transactional in MySQL).
        // Cleanup lives in the test method, not tearDown — see MIGRATION-009.
        $this->rollback();
    }
}
```

### Helper: rollback

```php
private function rollback(): void
{
    // For added columns:
    if (TableHelper::columnExists($this->connection, '{table}', '{column}')) {
        $this->connection->executeStatement('ALTER TABLE `{table}` DROP COLUMN `{column}`');
    }
    // For created tables:
    // $this->connection->executeStatement('DROP TABLE IF EXISTS `{table}`');
}
```

## Conditional: Schema-Remove Test (updateDestructive)

Include when source `updateDestructive()` has DROP logic.

### Test method

```php
public function testUpdateDestructive(): void
{
    // Ensure target exists before destructive call
    if (!TableHelper::columnExists($this->connection, '{table}', '{column}')) {
        $this->connection->executeStatement('ALTER TABLE `{table}` ADD COLUMN `{column}` {type}');
    }

    try {
        $migration = new {MigrationClassName}();
        $migration->update($this->connection);
        $migration->updateDestructive($this->connection);
        $migration->updateDestructive($this->connection);

        static::assertFalse(TableHelper::columnExists($this->connection, '{table}', '{column}'));
    } finally {
        // Restore column so sibling test classes see the original schema (DDL is not transactional in MySQL).
        // Restore lives in the test method, not tearDown, so testGetCreationTimestamp does not re-add the column. See MIGRATION-009.
        if (!TableHelper::columnExists($this->connection, '{table}', '{column}')) {
            $this->connection->executeStatement('ALTER TABLE `{table}` ADD COLUMN `{column}` {type}');
        }
    }
}
```

## Conditional: Data-Update Test

Include when source analysis detects `UPDATE`, `INSERT`, `DELETE` on non-config tables.

### Additional imports

```php
use Shopware\Core\Framework\Test\TestCaseBase\DatabaseTransactionBehaviour;
use Shopware\Core\Framework\Test\TestCaseBase\KernelTestBehaviour;
```

### Traits

```php
use DatabaseTransactionBehaviour;
use KernelTestBehaviour;
```

### setUp

```php
parent::setUp();
$this->connection = static::getContainer()->get(Connection::class);
```

### Test method

```php
public function testMigration(): void
{
    // Arrange: set up prerequisite state
    {SETUP_SQL}

    $migration = new {MigrationClassName}();
    $migration->update($this->connection);
    $migration->update($this->connection);

    // Assert: verify values changed
    {ASSERTION_SQL_AND_ASSERTS}
}
```

## Conditional: Config Test

Include when source analysis detects `system_config` operations.

### Additional imports

```php
use Shopware\Tests\Migration\MigrationTestTrait;
use Shopware\Core\Framework\Test\TestCaseBase\KernelLifecycleManager;
```

### Traits

```php
use MigrationTestTrait;
```

### setUp

```php
$this->connection = KernelLifecycleManager::getConnection();
```

### Test method

```php
public function testMigrationInsertsConfig(): void
{
    $this->connection->delete('system_config', [
        'configuration_key' => '{config_key}',
    ]);

    $migration = new {MigrationClassName}();
    $migration->update($this->connection);
    $migration->update($this->connection);

    $value = $this->connection->fetchOne(
        'SELECT configuration_value FROM system_config WHERE configuration_key = :key',
        ['key' => '{config_key}']
    );

    static::assertNotFalse($value);
    $decoded = json_decode($value, true, 512, \JSON_THROW_ON_ERROR);
    static::assertSame('{expected_value}', $decoded['_value']);
}

public function testMigrationDoesNotOverwriteModifiedConfig(): void
{
    $this->connection->executeStatement(
        'INSERT INTO system_config (id, configuration_key, configuration_value, created_at)
         VALUES (:id, :key, :value, NOW())
         ON DUPLICATE KEY UPDATE configuration_value = :value',
        [
            'id' => Uuid::randomBytes(),
            'key' => '{config_key}',
            'value' => json_encode(['_value' => 'custom-value']),
        ]
    );

    $migration = new {MigrationClassName}();
    $migration->update($this->connection);
    $migration->update($this->connection);

    $value = $this->connection->fetchOne(
        'SELECT configuration_value FROM system_config WHERE configuration_key = :key',
        ['key' => '{config_key}']
    );
    $decoded = json_decode($value, true, 512, \JSON_THROW_ON_ERROR);
    static::assertSame('custom-value', $decoded['_value']);
}
```

## Conditional: Mail Template Test

Include when source analysis detects `mail_template` operations.

### Additional imports

```php
use Shopware\Core\Framework\Test\TestCaseBase\KernelTestBehaviour;
```

### Traits

```php
use KernelTestBehaviour;
```

### setUp

```php
$this->connection = static::getContainer()->get(Connection::class);
```

### Test method (minimal)

```php
public function testMigrationCreatesMailTemplate(): void
{
    $migration = new {MigrationClassName}();

    // Both update() calls run unguarded so the second genuinely re-executes — that is the idempotency
    // check (MIGRATION-001). A swallowing try/catch would let a first-call failure skip the second call
    // and still pass; PHPUnit already fails the test if either call throws.
    $migration->update($this->connection);
    $migration->update($this->connection);

    // Assert the observable result, not merely "no exception". Adapt table/column to the migration.
    $exists = $this->connection->fetchOne(
        'SELECT 1 FROM mail_template_translation WHERE subject = :subject',
        ['subject' => '{expected_subject}']
    );
    static::assertNotFalse($exists);
}
```

## Placeholder Reference

| Placeholder | Source |
|-------------|--------|
| `{Area}` | From namespace: `Core`, `Administration`, `Storefront`, `Elasticsearch` |
| `{Version}` | From namespace: `V6_6`, `V6_7`, `V6_8` |
| `{MigrationFullClassName}` | Full qualified class name from source |
| `{MigrationClassName}` | Short class name |
| `{package}` | `#[Package]` value from Phase 2 Step 1 |
| `{timestamp}` | Integer from `getCreationTimestamp()` |
| `{table}` | Table name from source SQL analysis |
| `{column}` | Column name from source SQL analysis |
| `{type}` | Column SQL type from source SQL analysis |
| `{config_key}` | Configuration key from source SQL analysis |
| `{expected_value}` | Expected config value from source SQL analysis |
| `{expected_subject}` | Expected mail-template subject from source SQL analysis |
| `{SETUP_SQL}` | SQL statements to set up test state |
| `{ASSERTION_SQL_AND_ASSERTS}` | SQL queries + assertions to verify migration result |
