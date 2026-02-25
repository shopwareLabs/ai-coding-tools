# Output Format

Actual rule IDs, legacy codes, and titles come from MCP `mcp__plugin_test-writing_test-rules__get_rules` responses.

## Report Structure

```markdown
# PHPUnit Unit Test Review: [TestClassName]

## Summary
- **File**: `path/to/TestFile.php`
- **Status**: PASS | NEEDS_ATTENTION | ISSUES_FOUND
- **Errors**: X
- **Warnings**: Y
- **Category**: [A-E] ([Category Name])
- **Base Class**: [TestCase | KernelTestCase | etc.] ✓/✗

## Errors (Must Fix)

### [{RULE-ID}] {TITLE}
Legacy: {LEGACY}
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
Legacy: {LEGACY}
- **Location**: `TestFile.php:line`
- **Issue**: Description
- **Recommendation**: How to improve
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
Legacy: {LEGACY}
- **Location**: `TestFile.php:line`
- **Suggestion**: Optional improvement

## Passed Checks
- ✓ {title} ({rule_id})
- ✓ {title} ({rule_id})
- ... (all applicable rules from mcp__plugin_test-writing_test-rules__list_rules that passed)
```

## PASS Example

```markdown
# PHPUnit Unit Test Review: ProductServiceTest

## Summary
- **File**: `tests/unit/Core/Content/Product/ProductServiceTest.php`
- **Status**: PASS
- **Errors**: 0
- **Warnings**: 0
- **Category**: B (Service)
- **Base Class**: TestCase ✓

## Passed Checks
- ✓ {title} ({rule_id})
- ✓ {title} ({rule_id})
- ✓ {title} ({rule_id})
- ... (all applicable rules from mcp__plugin_test-writing_test-rules__list_rules that passed)
```

## ISSUES_FOUND Example

```markdown
# PHPUnit Unit Test Review: OrderValidatorTest

## Summary
- **File**: `tests/unit/Core/Checkout/Order/OrderValidatorTest.php`
- **Status**: ISSUES_FOUND
- **Errors**: 2
- **Warnings**: 1
- **Category**: B (Service)
- **Base Class**: TestCase ✓

## Errors (Must Fix)

### [{RULE-ID}] {TITLE}
Legacy: {LEGACY}
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

### [{RULE-ID}] {TITLE}
Legacy: {LEGACY}
- **Location**: `OrderValidatorTest.php:78`
- **Issue**: TestDox appears before DataProvider
- **Current Code**:
  ```php
  #[TestDox('validates with $input')]
  #[DataProvider('inputProvider')]
  public function testInput($input): void
  ```
- **Suggested Fix**:
  ```php
  #[DataProvider('inputProvider')]
  #[TestDox('validates with $input')]
  public function testInput($input): void
  ```

## Warnings (Should Fix)

### [{RULE-ID}] {TITLE}
Legacy: {LEGACY}
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
- ✓ {title} ({rule_id})
- ... (all applicable rules from mcp__plugin_test-writing_test-rules__list_rules that passed)
```

## Error Output (File Not Found)

```markdown
# PHPUnit Unit Test Review: FAILED

**Reason**: File not found
**Input**: `tests/unit/NonExistent/TestFile.php`
**Suggestion**: Verify the file path exists. Use `Glob("tests/unit/**/*Test.php")` to find test files.
```

## Error Output (Not a Unit Test)

```markdown
# PHPUnit Unit Test Review: FAILED

**Reason**: Not a unit test
**Input**: `tests/integration/Core/Checkout/OrderTest.php`
**Suggestion**: This skill reviews unit tests only (tests/unit/). Integration tests have different patterns and requirements.
```

## Error Output (Not a Test Class)

```markdown
# PHPUnit Unit Test Review: FAILED

**Reason**: Not a test class
**Input**: `src/Core/Content/Product/ProductService.php`
**Suggestion**: Provide a test file path (ending in *Test.php) from the tests/unit/ directory.
```
