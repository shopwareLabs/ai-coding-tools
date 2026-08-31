# Output Format

Rule IDs and titles come from `mcp__plugin_test-writing_test-rules__get_rules` responses.

## Report Structure

```markdown
# PHPUnit Migration Test Review: [TestClassName]

## Summary
- **File**: `path/to/TestFile.php`
- **Status**: PASS | NEEDS_ATTENTION | ISSUES_FOUND | FAILED
- **Errors**: X
- **Warnings**: Y

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
- **Deleted Methods**: `testFoo`, `testBar`
- **Removed Assertions**: `static::assertTrue(TableHelper::columnExists($this->connection, 'foo', 'bar'))` → covered by `testMigration`

## Warnings (Should Fix)

### [{RULE-ID}] {TITLE}
- **Location**: `TestFile.php:line`
- **Issue**: Description
- **Current Code**:
  ```php
  // current code
  ```
- **Suggested Fix**:
  ```php
  // improved code
  ```

## Informational

### [{RULE-ID}] {TITLE}
- **Location**: `TestFile.php:line`
- **Suggestion**: Optional improvement

## Passed Checks
- ✓ {title} ({rule_id})
- ... (all applicable rules that passed)
```

Omit empty sections (Errors, Warnings, Informational) when no findings exist in that category.

## Deletion Accounting

A finding whose fix removes test code says what it removes, so nothing is dropped without a named survivor. Both lines apply to errors, warnings, and informational entries alike, and both are omitted from a finding whose fix removes nothing:

- **Deleted Methods** — the test methods the fix removes entirely, by bare name (`testFoo`, never `testFoo()`).
- **Removed Assertions** — one entry per removed assertion: the assertion, then the surviving test method that still covers it, or `none — coverage lost` when nothing does.

They carry into the structured contract as `deleted_methods` (array of bare method names) and `removed_assertions` (array of `{assertion, covered_by_test}`), both `[]` when the fix removes nothing. The report's deletion after-state check passes the union of `deleted_methods` to `assert_surviving_tests`, so a name that matches no method in the file becomes an error against the finding that cited it.

## Status Values

| Status | Condition |
|--------|-----------|
| PASS | 0 errors, 0 warnings |
| NEEDS_ATTENTION | 0 errors, 1+ warnings |
| ISSUES_FOUND | 1+ errors |
| FAILED | Invalid input (file not found, not a migration test, source not a MigrationStep) |

MIGRATION-001 through MIGRATION-009 are all must-fix. The composed catalog also includes every convention, design, isolation, and provider rule whose `test-types` declares `migration`, some of which are should-fix or consider. A should-fix finding is a warning and yields `NEEDS_ATTENTION` rather than `ISSUES_FOUND`. A consider-level finding is informational and never changes status.

## Example

```markdown
# PHPUnit Migration Test Review: Migration1234FooTest

## Summary
- **File**: `tests/migration/Core/V6_7/Migration1234FooTest.php`
- **Status**: ISSUES_FOUND
- **Errors**: 1
- **Warnings**: 0

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
