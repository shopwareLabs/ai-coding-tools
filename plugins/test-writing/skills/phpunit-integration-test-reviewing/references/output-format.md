# Output Format

Rule IDs and titles come from `mcp__plugin_test-writing_test-rules__get_rules` responses.

## Report Structure

```markdown
# PHPUnit Integration Test Review: [TestClassName]

## Summary
- **File**: `path/to/TestFile.php`
- **Baseline**: pass | fail | unavailable
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
- **Deleted Methods**: `testFoo`, `testBar`
- **Removed Assertions**: `static::assertSame('active', $product->getState())` → covered by `testPersistsState`

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

They carry into the structured contract as `deleted_methods` (array of bare method names) and `removed_assertions` (array of `{assertion, covered_by_test}`), both `[]` when the fix removes nothing. The report's deletion after-state check passes the union of `deleted_methods` to `assert_surviving_tests`, so a name that matches no method in the file becomes an error against the finding that cited it.

## Status Values

| Status | Condition |
|--------|-----------|
| PASS | 0 errors, 0 warnings |
| NEEDS_ATTENTION | 0 errors, 1+ warnings |
| ISSUES_FOUND | 1+ errors |
| FAILED | Invalid input |

Informational hints (INTEGRATION-008) never change status. PASS with a placement hint is still PASS. A `fail` `{baseline}` sets `ISSUES_FOUND` regardless of the table above.

## Example

```markdown
# PHPUnit Integration Test Review: ProductIndexerTest

## Summary
- **File**: `tests/integration/Core/Content/Product/ProductIndexerTest.php`
- **Baseline**: pass
- **Status**: ISSUES_FOUND
- **Errors**: 1
- **Warnings**: 0
- **Informational**: 0

## Errors (Must Fix)

### [INTEGRATION-002] No mocking of the system under test or its primary collaborators
- **Location**: `ProductIndexerTest.php:42`
- **Issue**: `EntityRepository` is a primary collaborator of `ProductIndexer` and must not be mocked in an integration test; the manual `new ProductIndexer(...)` construction is removed in favor of fetching the SUT from the container.
- **Current Code**:
  ```php
  public function testRebuildIndexesAllProducts(): void
  {
      $repository = $this->createMock(EntityRepository::class);
      $indexer = new ProductIndexer($repository, static::getContainer()->get(ProductSearchKeywordUpdater::class));

      $result = $indexer->getIterator();

      static::assertSame('product_indexer', $result->getId());
  }
  ```
- **Suggested Fix**:
  ```php
  public function testRebuildIndexesAllProducts(): void
  {
      $indexer = static::getContainer()->get(ProductIndexer::class);

      $result = $indexer->getIterator();

      static::assertSame('product_indexer', $result->getId());
  }
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
- **Baseline**: pass
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
