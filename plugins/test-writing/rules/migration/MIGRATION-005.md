---
id: MIGRATION-005
title: Separate try/catch in setUp/tearDown — catch Throwable
group: migration
enforce: must-fix
test-types: migration
test-categories: all
scope: shopware
---

## Separate try/catch in setUp/tearDown — catch Throwable

**Scope**: all | **Enforce**: Must fix

In setUp and tearDown methods, independent SQL statements must each have their own try/catch block. Catch `\Throwable`, not `\Exception`.

### Detection — Multiple statements in single try

```php
// INCORRECT - if first statement fails, second never executes
protected function setUp(): void
{
    try {
        $this->connection->executeStatement('ALTER TABLE `language` DROP COLUMN `active`');
        $this->connection->executeStatement('DROP TABLE `pack_language`');
    } catch (\Exception $e) {
        // both statements skipped on first failure
    }
}
```

### Fix — Multiple statements in single try

```php
// CORRECT - each statement independent
protected function setUp(): void
{
    try {
        $this->connection->executeStatement('ALTER TABLE `language` DROP COLUMN `active`');
    } catch (\Throwable) {
    }

    try {
        $this->connection->executeStatement('DROP TABLE `pack_language`');
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
