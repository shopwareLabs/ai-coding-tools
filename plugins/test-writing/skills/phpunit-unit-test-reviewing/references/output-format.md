# Output Format

Rule IDs and titles come from `mcp__plugin_test-writing_test-rules__get_rules` responses.

## Report Structure

```markdown
# PHPUnit Unit Test Review: [TestClassName]

## Summary
- **File**: `path/to/TestFile.php`
- **Scope**: [method1, method2] (N methods) | Full class
- **Status**: PASS | NEEDS_ATTENTION | ISSUES_FOUND
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

## Example

```markdown
# PHPUnit Unit Test Review: OrderValidatorTest

## Summary
- **File**: `tests/unit/Core/Checkout/Order/OrderValidatorTest.php`
- **Status**: ISSUES_FOUND
- **Errors**: 1
- **Warnings**: 1
- **Category**: B (Service)
- **Base Class**: TestCase ✓

## Errors (Must Fix)

### [{RULE-ID}] {TITLE}
- **Location**: `OrderValidatorTest.php:45`
- **Issue**: Test method `testValidation` contains if/else conditional
- **Current Code**:
  ```php
  public function testValidation($value, $shouldPass): void
  {
      $result = $this->validator->validate($value);
      if ($shouldPass) {
          static::assertTrue($result->isValid());
      } else {
          static::assertFalse($result->isValid());
      }
  }
  ```
- **Suggested Fix**:
  ```php
  #[TestWithJson('["valid-order-123"]')]
  #[TestDox('accepts valid order ID: $value')]
  public function testAcceptsValidOrderId(string $value): void
  {
      $result = $this->validator->validate($value);
      static::assertTrue($result->isValid());
  }

  #[TestWithJson('["invalid"]')]
  #[TestDox('rejects invalid order ID: $value')]
  public function testRejectsInvalidOrderId(string $value): void
  {
      $result = $this->validator->validate($value);
      static::assertFalse($result->isValid());
  }
  ```

## Warnings (Should Fix)

### [{RULE-ID}] {TITLE}
- **Location**: `OrderValidatorTest.php:92`
- **Issue**: `assertTrue($result === 5)` should use assertEquals
- **Current Code**:
  ```php
  static::assertTrue($result === 5);
  ```
- **Suggested Fix**:
  ```php
  static::assertEquals(5, $result);
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
