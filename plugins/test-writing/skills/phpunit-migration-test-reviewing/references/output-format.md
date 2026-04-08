# Output Format

Actual rule IDs and titles come from MCP `mcp__plugin_test-writing_test-rules__get_rules` responses.

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
- ✓ {title} ({rule_id})
- ... (all applicable rules from list_rules that passed)
```

## Status Values

| Status | Condition |
|--------|-----------|
| PASS | 0 errors |
| ISSUES_FOUND | 1+ errors |
| FAILED | Invalid input (file not found, not a migration test, source not a MigrationStep) |

All migration rules are must-fix. There is no NEEDS_ATTENTION status (no warnings).

## PASS Example

```markdown
# PHPUnit Migration Test Review: Migration1718615305AddEuToCountryTableTest

## Summary
- **File**: `tests/migration/Core/V6_6/Migration1718615305AddEuToCountryTableTest.php`
- **Status**: PASS
- **Errors**: 0

## Passed Checks
- ✓ Idempotency — update() called at least twice (MIGRATION-001)
- ✓ testGetCreationTimestamp must exist (MIGRATION-008)
- ✓ assertSame over assertEquals (MIGRATION-007)
- ... (all applicable rules)
```

## ISSUES_FOUND Example

```markdown
# PHPUnit Migration Test Review: Migration1234FooTest

## Summary
- **File**: `tests/migration/Core/V6_7/Migration1234FooTest.php`
- **Status**: ISSUES_FOUND
- **Errors**: 2

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

### [MIGRATION-008] testGetCreationTimestamp must exist
- **Location**: `Migration1234FooTest.php` (class level)
- **Issue**: No `testGetCreationTimestamp` method found
- **Suggested Fix**:
  ```php
  public function testGetCreationTimestamp(): void
  {
      static::assertSame(1234, (new Migration1234Foo())->getCreationTimestamp());
  }
  ```

## Passed Checks
- ✓ Test must not reuse migration helper methods (MIGRATION-003)
- ✓ assertSame over assertEquals (MIGRATION-007)
```

## Error Output (Not a Migration Test)

```markdown
# PHPUnit Migration Test Review: FAILED

**Reason**: Not a migration test
**Input**: `tests/unit/Core/Content/ProductTest.php`
**Suggestion**: This skill reviews migration tests only (tests/migration/). Use test-writing:phpunit-unit-test-reviewing for unit tests.
```

## Error Output (Source Not MigrationStep)

```markdown
# PHPUnit Migration Test Review: FAILED

**Reason**: Source class does not extend MigrationStep
**Input**: `tests/migration/Core/V6_7/SomeOtherTest.php`
**Suggestion**: The #[CoversClass] target must extend Shopware\Core\Framework\Migration\MigrationStep.
```
