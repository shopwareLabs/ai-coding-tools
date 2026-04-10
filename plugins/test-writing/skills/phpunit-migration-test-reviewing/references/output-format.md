# Output Format

Rule IDs and titles come from `mcp__plugin_test-writing_test-rules__get_rules` responses.

## Report Structure

```markdown
# PHPUnit Migration Test Review: [TestClassName]

## Summary
- **File**: `path/to/TestFile.php`
- **Status**: PASS | ISSUES_FOUND | FAILED
- **Errors**: X

## Errors (Must Fix)

### [{RULE-ID}] {TITLE}
- **Location**: `TestFile.php:line`
- **Issue**: Description of the problem
- **Current Code**:
  ```php
  // problematic code
  ```
- **Suggested Fix**:
  ```php
  // corrected code
  ```

## Passed Checks
- ✓ {title} ({rule_id})
- ... (all applicable rules that passed)
```

Omit the Errors section when status is PASS.

## Status Values

| Status | Condition |
|--------|-----------|
| PASS | 0 errors |
| ISSUES_FOUND | 1+ errors |
| FAILED | Invalid input (file not found, not a migration test, source not a MigrationStep) |

All migration rules are must-fix. There is no NEEDS_ATTENTION status (no warnings).

## Example

```markdown
# PHPUnit Migration Test Review: Migration1234FooTest

## Summary
- **File**: `tests/migration/Core/V6_7/Migration1234FooTest.php`
- **Status**: ISSUES_FOUND
- **Errors**: 1

## Errors (Must Fix)

### [MIGRATION-001] Idempotency — update() called at least twice
- **Location**: `Migration1234FooTest.php:35`
- **Issue**: `update()` is called only once in `testMigration`
- **Current Code**:
  ```php
  public function testMigration(): void
  {
      $migration = new Migration1234Foo();
      $migration->update($this->connection);
      static::assertTrue(TableHelper::columnExists($this->connection, 'foo', 'bar'));
  }
  ```
- **Suggested Fix**:
  ```php
  public function testMigration(): void
  {
      $migration = new Migration1234Foo();
      $migration->update($this->connection);
      $migration->update($this->connection);
      static::assertTrue(TableHelper::columnExists($this->connection, 'foo', 'bar'));
  }
  ```

## Passed Checks
- ✓ Test must not reuse migration helper methods (MIGRATION-003)
- ✓ assertSame over assertEquals (MIGRATION-007)
```

## Error Outputs

When the review cannot proceed:

```markdown
# PHPUnit Migration Test Review: FAILED

**Reason**: {reason}
**Input**: `{path}`
**Suggestion**: {guidance}
```

| Reason | Suggestion |
|--------|------------|
| Not a migration test | This skill reviews migration tests only (tests/migration/). Use test-writing:phpunit-unit-test-reviewing for unit tests. |
| Source class does not extend MigrationStep | The #[CoversClass] target must extend Shopware\Core\Framework\Migration\MigrationStep. |
