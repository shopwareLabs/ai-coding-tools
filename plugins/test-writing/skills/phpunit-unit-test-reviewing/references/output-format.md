# Output Format

Rule IDs and titles come from `mcp__plugin_test-writing_test-rules__get_rules` responses.

## Report Structure

```markdown
# PHPUnit Unit Test Review: [TestClassName]

## Summary
- **File**: `path/to/TestFile.php`
- **Baseline**: pass | fail | unavailable
- **Scope**: [method1, method2] (N methods) | Full class
- **Status**: PASS | NEEDS_ATTENTION | ISSUES_FOUND | FAILED
- **Reason**: {failure text, verbatim — only when Status is FAILED}
- **Errors**: X
- **Warnings**: Y
- **Category**: [A-E] ([Category Name])
- **Base Class**: [TestCase | KernelTestCase | etc.] ✓/✗

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
- **Removed Assertions**: `static::assertSame(3, $result->count())` → covered by `testCountsItems`

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

A finding whose fix cannot be made in the test file alone — it requires a change under `src/` — carries `implies_src_change: true` in the structured contract and one line in the report:

- **Source change**: yes (the fix cannot be made in the test alone)

Every other finding carries `implies_src_change: false` and omits the line. The flag is informational: it never changes `status` and never re-levels a finding.

## Status Values

| Status | Condition |
|--------|-----------|
| PASS | 0 errors, 0 warnings |
| NEEDS_ATTENTION | 0 errors, 1+ warnings |
| ISSUES_FOUND | 1+ errors |
| FAILED | Invalid input, or a refusal from the deletion after-state check |

Informational entries never change status. `PASS` with an informational entry is still `PASS`. A `fail` `{baseline}` sets `ISSUES_FOUND` regardless of the table above; a guard refusal sets `FAILED`, which outranks both.

## Example

```markdown
# PHPUnit Unit Test Review: OrderValidatorTest

## Summary
- **File**: `tests/unit/Core/Checkout/Order/OrderValidatorTest.php`
- **Baseline**: pass
- **Status**: ISSUES_FOUND
- **Errors**: 1
- **Warnings**: 1
- **Category**: B (Service)
- **Base Class**: TestCase ✓

## Errors (Must Fix)

### [{RULE-ID}] {TITLE}
- **Location**: `OrderValidatorTest.php:45`
- **Issue**: `createMock()` registers an unnecessary `expects()` interaction assertion — the test only needs `findById` to return a fixture, not verification of how it was called
- **Current Code**:
  ```php
  public function testValidatesOrderTotalAgainstThreshold(): void
  {
      $repository = $this->createMock(OrderRepository::class);
      $repository->expects(static::once())
          ->method('findById')
          ->with('order-1')
          ->willReturn($this->buildOrder(150.0));

      $result = $this->validator->validate($repository, 'order-1');

      static::assertTrue($result->isValid());
  }
  ```
- **Suggested Fix**:
  ```php
  public function testValidatesOrderTotalAgainstThreshold(): void
  {
      $repository = $this->createStub(OrderRepository::class);
      $repository->method('findById')
          ->willReturn($this->buildOrder(150.0));

      $result = $this->validator->validate($repository, 'order-1');

      static::assertTrue($result->isValid());
  }
  ```

## Warnings (Should Fix)

### [{RULE-ID}] {TITLE}
- **Location**: `OrderValidatorTest.php:92`
- **Issue**: `assertTrue($result === 105.0)` should use `assertSame(105.0, $result)` — a boolean comparison instead of a specific assertion
- **Current Code**:
  ```php
  public function testCalculatesRemainingBalance(): void
  {
      $result = $this->validator->calculateRemainingBalance(150.0, 45.0);

      static::assertTrue($result === 105.0);
  }
  ```
- **Suggested Fix**:
  ```php
  public function testCalculatesRemainingBalance(): void
  {
      $result = $this->validator->calculateRemainingBalance(150.0, 45.0);

      static::assertSame(105.0, $result);
  }
  ```

## Passed Checks
- ✓ {title} ({rule_id})
- ✓ {title} ({rule_id})
```

## Error Outputs

When the review cannot proceed:

```markdown
# PHPUnit Unit Test Review: FAILED

**Reason**: {reason}
**Input**: `{path}`
**Suggestion**: {guidance}
```

| Reason | Suggestion |
|--------|------------|
| File not found | Verify the file path exists. Use `Glob("tests/unit/**/*Test.php")` to find test files. |
| Not a unit test | This skill reviews unit tests only (tests/unit/). Integration tests have different patterns. |
| Not a test class | Provide a test file path (ending in *Test.php) from the tests/unit/ directory. |
| The deletion after-state check refused | Quote the tool's error text verbatim as the Reason. Report the findings collected as well: the guard establishes what the deletions leave behind, and its refusal means that is unknown, not that the findings are void. |

A guard refusal renders the full report with `Status: FAILED` and the verbatim error text in `reason`, not the bare FAILED block above.
