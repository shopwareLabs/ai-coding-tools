# Output Format

Rule IDs and titles come from `mcp__plugin_test-writing_test-rules__get_rules` responses.

## Report Structure

```markdown
# PHPUnit Migration Test Review: [TestClassName]

## Summary
- **File**: `path/to/TestFile.php`
- **Baseline**: pass | fail | unavailable
- **Status**: PASS | NEEDS_ATTENTION | ISSUES_FOUND | FAILED
- **Reason**: {failure text, verbatim — only when Status is FAILED}
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

## Baseline

The Summary reports the supplied `{baseline}` verbatim. A `fail` value adds one line directly under the report title, before `## Summary`:

**Baseline failure**: This file's tests were already failing before this review, independent of the rule catalog below.

and forces `status: ISSUES_FOUND`, regardless of what the rule catalog finds. `unavailable` is recorded in the Summary's `Baseline` field and changes nothing else. `pass` is recorded in the Summary's `Baseline` field.

## Code Fields

`current` and `suggested` describe one change, so a reader (and a fix applier) can see exactly what the finding removes:

- **Current Code** (`current`) — copied verbatim from the file at the cited location, read at review time. Never paraphrased and never reconstructed from a rule's Detection example.
- **Suggested Fix** (`suggested`) — the complete method body after the change, not a fragment and not a diff. The one exception: where the remediation deletes the method entirely, `suggested` is empty and **Deleted Methods** names that method.
- **Issue** — a line present in `current` and absent from `suggested` is a removal, and the Issue names it. This report renders the field as `Issue`; the team-review schema names it `summary`.

## Deletion Accounting

A finding whose fix removes test code says what it removes, so nothing is dropped without a named survivor. Both lines apply to errors, warnings, and informational entries alike, and both are omitted from a finding whose fix removes nothing:

- **Deleted Methods** — the test methods the fix removes entirely, by bare name (`testFoo`, never `testFoo()`).
- **Removed Assertions** — one entry per removed assertion: the assertion, then the surviving test method that still covers it, or `none — coverage lost` when nothing does.

They carry into the structured contract as `deleted_methods` (array of bare method names) and `removed_assertions` (array of `{assertion, covered_by_test}`), both `[]` when the fix removes nothing.

## Source-Change Escalation

A finding whose fix cannot be made in the test file alone — it requires a change under `src/`, for a migration test typically the migration class itself — carries `implies_src_change: true` in the structured contract and one line in the report:

- **Source change**: yes (the fix cannot be made in the test alone)

Every other finding carries `implies_src_change: false` and omits the line. The flag is informational: it never changes `status` and never re-levels a finding.

## Status Values

| Status | Condition |
|--------|-----------|
| PASS | 0 errors, 0 warnings |
| NEEDS_ATTENTION | 0 errors, 1+ warnings |
| ISSUES_FOUND | 1+ errors |
| FAILED | Invalid input (file not found, not a migration test, source not a MigrationStep), or a refusal from the deletion after-state check |

MIGRATION-001..006, MIGRATION-008 and MIGRATION-009 are all must-fix. The composed catalog also includes every convention, design, isolation, and provider rule whose `test-types` declares `migration`, some of which are should-fix or consider. A should-fix finding is a warning and yields `NEEDS_ATTENTION` rather than `ISSUES_FOUND`. Informational entries never change status — consider-level findings and the guard's `UNRESOLVED` entry alike. A `fail` `{baseline}` sets `ISSUES_FOUND` regardless of the above; a guard refusal sets `FAILED`, which outranks both.

## Example

```markdown
# PHPUnit Migration Test Review: Migration1234FooTest

## Summary
- **File**: `tests/migration/Core/V6_7/Migration1234FooTest.php`
- **Baseline**: pass
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
- ✓ testGetCreationTimestamp present (MIGRATION-008)
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
| The deletion after-state check refused | Quote the tool's error text verbatim as the Reason. Report the findings collected as well: the guard establishes what the deletions leave behind, and its refusal means that is unknown, not that the findings are void. |

A guard refusal renders the full report with `Status: FAILED` and the verbatim error text in `reason`, not the bare FAILED block above.
