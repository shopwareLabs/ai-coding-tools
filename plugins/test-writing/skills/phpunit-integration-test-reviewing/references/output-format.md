# Output Format

Rule IDs and titles come from `mcp__plugin_test-writing_test-rules__get_rules` responses.

## Report Structure

```markdown
# PHPUnit Integration Test Review: [TestClassName]

## Summary
- **File**: `path/to/TestFile.php`
- **Status**: PASS | NEEDS_ATTENTION | ISSUES_FOUND | FAILED
- **Errors**: X
- **Warnings**: Y
- **Informational**: Z

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

### [INTEGRATION-008] Placement smoke check
- **Hint**: Every assertion in this test is unit-shape. The integration apparatus may not be load-bearing. To audit placement, invoke `phpunit-integration-to-unit-migrating` on this file. Not a violation; this skill does not act on placement.

## Passed Checks
- ✓ {title} ({rule_id})
- ... (all applicable rules that passed)
```

Omit empty sections (Errors, Warnings, Informational) when no findings exist in that category.

## Status Values

| Status | Condition |
|--------|-----------|
| PASS | 0 errors, 0 warnings |
| NEEDS_ATTENTION | 0 errors, 1+ warnings |
| ISSUES_FOUND | 1+ errors |
| FAILED | Invalid input |

Informational hints (INTEGRATION-008) never change status. PASS with a placement hint is still PASS.

## Example

```markdown
# PHPUnit Integration Test Review: ProductIndexerTest

## Summary
- **File**: `tests/integration/Core/Content/Product/ProductIndexerTest.php`
- **Status**: ISSUES_FOUND
- **Errors**: 1
- **Warnings**: 0
- **Informational**: 0

## Errors (Must Fix)

### [INTEGRATION-002] No mocking of the system under test or its primary collaborators
- **Location**: `ProductIndexerTest.php:42`
- **Issue**: `EntityRepository` is a primary collaborator of `ProductIndexer` and must not be mocked in an integration test.
- **Current Code**:
  ```php
  $repository = $this->createMock(EntityRepository::class);
  $indexer = new ProductIndexer($repository);
  ```
- **Suggested Fix**:
  ```php
  $indexer = static::getContainer()->get(ProductIndexer::class);
  ```

## Passed Checks
- ✓ Integration test uses Shopware integration base (INTEGRATION-001)
- ✓ Non-transactional writes are cleaned up (INTEGRATION-003)
- ✓ Deterministic time, randomness, and identifiers (INTEGRATION-004)
- ✓ No #[Depends] between integration test methods (INTEGRATION-005)
- ✓ Do not skip tests for missing fixtures (INTEGRATION-006)
- ✓ Setup-to-assertion ratio is balanced (INTEGRATION-007)
- ✓ Placement smoke check (INTEGRATION-008)
```

## Example with placement hint

```markdown
# PHPUnit Integration Test Review: DateFieldSerializerTest

## Summary
- **File**: `tests/integration/Core/Framework/DataAbstractionLayer/FieldSerializer/DateFieldSerializerTest.php`
- **Status**: PASS
- **Errors**: 0
- **Warnings**: 0
- **Informational**: 1

## Informational

### [INTEGRATION-008] Placement smoke check
- **Hint**: Every assertion in this test is unit-shape (assertions on return values only, no persisted state or container-wired behavior verified). The integration apparatus may not be load-bearing. To audit placement, invoke `phpunit-integration-to-unit-migrating` on this file. Not a violation; this skill does not act on placement.

## Passed Checks
- ✓ Integration test uses Shopware integration base (INTEGRATION-001)
- ✓ No mocking of the system under test or its primary collaborators (INTEGRATION-002)
- ✓ Non-transactional writes are cleaned up (INTEGRATION-003)
- ✓ Deterministic time, randomness, and identifiers (INTEGRATION-004)
- ✓ No #[Depends] between integration test methods (INTEGRATION-005)
- ✓ Do not skip tests for missing fixtures (INTEGRATION-006)
- ✓ Setup-to-assertion ratio is balanced (INTEGRATION-007)
```

## Error Outputs

When the review cannot proceed:

```markdown
# PHPUnit Integration Test Review: FAILED

**Reason**: {reason}
**Input**: `{path}`
**Suggestion**: {guidance}
```

| Reason | Suggestion |
|--------|------------|
| Not an integration test | This skill reviews integration tests only (tests/integration/). Use test-writing:phpunit-unit-test-reviewing for unit tests and test-writing:phpunit-migration-test-reviewing for migration tests. |
| File not found | Verify the file path exists. Use `Glob("tests/integration/**/*Test.php")` to locate test files. |
