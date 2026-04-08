---
id: MIGRATION-006
title: Hardcoded table and column names in SQL
group: migration
enforce: must-fix
test-types: migration
test-categories: all
scope: shopware
---

## Hardcoded table and column names in SQL

**Scope**: all | **Enforce**: Must fix

Use literal table and column names in SQL strings. String interpolation, `sprintf`, and `str_replace` for table/column names reduce readability and introduce injection risk.

### Detection

In arguments to SQL-executing methods (`executeStatement`, `executeQuery`, `fetchOne`, `fetchAssociative`, `fetchAllAssociative`, `fetchFirstColumn`, `fetchAllKeyValue`, `insert`, `update`, `delete`), detect:

1. Variable interpolation in double-quoted SQL: `"SELECT * FROM $tableName"`
2. `sprintf` with table/column format specifiers: `sprintf('SELECT * FROM %s', $table)`
3. `str_replace` for table/column names: `str_replace('#table#', $tableName, $sql)`

```php
// INCORRECT - string interpolation
private string $tableName = 'media';

public function testMigration(): void
{
    $result = $this->connection->fetchOne("SELECT COUNT(*) FROM `{$this->tableName}`");
}
```

### Fix

```php
// CORRECT - hardcoded table name
public function testMigration(): void
{
    $result = $this->connection->fetchOne("SELECT COUNT(*) FROM `media`");
}
```

### When Variable SQL Is Acceptable

Using variables for SQL **values** (parameters) is fine — this rule targets **identifiers** (table names, column names) only:

```php
// OK - parameterized value, not identifier
$this->connection->fetchOne(
    'SELECT id FROM country WHERE iso = :iso',
    ['iso' => 'DE']
);
```
