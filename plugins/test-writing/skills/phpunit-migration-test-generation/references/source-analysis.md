# Source Analysis

How to analyze a migration source class to determine the test structure.

## SQL Pattern Detection

Read the `update()` and `updateDestructive()` method bodies. Classify operations by pattern matching on SQL strings and method calls.

### Schema-Add Patterns

| Pattern | Indicates |
|---------|-----------|
| `CREATE TABLE` in SQL string | New table creation |
| `->addColumn(` method call | Column addition via MigrationStep helper |
| `ALTER TABLE ... ADD COLUMN` in SQL string | Column addition via raw SQL (note: PHPStan AddColumnRule forbids this in recent migrations) |
| `ALTER TABLE ... ADD INDEX` | Index creation |
| `ALTER TABLE ... ADD FOREIGN KEY` | Foreign key creation |
| `ALTER TABLE ... ADD CONSTRAINT` | Constraint creation |

**Test needs**: rollback method to undo schema change, verify column/table exists after migration.

### Schema-Remove Patterns (updateDestructive)

| Pattern | Indicates |
|---------|-----------|
| `DROP TABLE` | Table removal |
| `DROP COLUMN` | Column removal |
| `->dropColumnIfExists(` | Column removal via helper |
| `->dropTableIfExists(` | Table removal via helper |
| `->dropForeignKeyIfExists(` | FK removal via helper |

**Test needs**: ensure target exists before destructive call, verify removed after.

### Data-Update Patterns

| Pattern | Indicates |
|---------|-----------|
| `UPDATE ... SET` in SQL string | Row modification |
| `INSERT INTO` (not system_config) | Data insertion |
| `DELETE FROM` (not system_config) | Data removal |
| `->update(` on connection (not migration) | Row update via DBAL |
| `->insert(` on connection | Row insert via DBAL |

**Test needs**: set up prerequisite state, verify values after migration.

### Config Patterns

| Pattern | Indicates |
|---------|-----------|
| `system_config` in SQL string | System config change |
| `configuration_key` in SQL string | System config change |
| `configuration_value` in SQL string | System config change |

**Test needs**: delete/set config key before migration, verify correct value after.

### Mail Template Patterns

| Pattern | Indicates |
|---------|-----------|
| `mail_template` in SQL string | Mail template modification |
| `mail_template_type` in SQL string | Mail template type modification |
| File reads with `file_get_contents` for template content | Template content from fixture files |

**Test needs**: minimal — run migration, assert no exception. Content may change in future migrations so detailed assertions are brittle.

## updateDestructive Analysis

Check whether `updateDestructive()` has logic:

1. Find the method in the source class
2. If the class does not override `updateDestructive()`: no logic (inherited empty body from MigrationStep)
3. If overridden: read the body
4. Empty body or only `parent::updateDestructive($connection);`: no logic
5. Any other statement: has logic → test must include `updateDestructive()` coverage

## Helper Method Detection

| Helper | Purpose | Test Implication |
|--------|---------|------------------|
| `$this->addColumn(...)` | ALGORITHM=INSTANT column add | Verify column exists |
| `$this->addAdditionalPrivileges(...)` | ACL privilege addition | Verify privileges in acl_role |
| `$this->registerIndexer(...)` | Queue indexer for next run | Verify indexer registered |
| `$this->createTrigger(...)` | Blue-green trigger | Environment-dependent, may skip |
| `$this->removeTrigger(...)` | Remove trigger | Verify trigger removed |

## Trait Selection

Based on the detected patterns:

| Condition | Traits | Connection Access |
|-----------|--------|-------------------|
| Data update (modifies rows, needs auto-rollback) | `KernelTestBehaviour` + `DatabaseTransactionBehaviour` | `$this->getContainer()->get(Connection::class)` |
| Config migration (system_config, needs auto-rollback) | `MigrationTestTrait` | `KernelLifecycleManager::getConnection()` |
| Schema migration (manual rollback method) | `KernelTestBehaviour` | `$this->getContainer()->get(Connection::class)` or `static::getContainer()->get(Connection::class)` |
| Default | `KernelTestBehaviour` | `$this->getContainer()->get(Connection::class)` |
