# Output Format

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

### [E001] [Issue Title]
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

### [W001] [Issue Title]
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

### [I001] [Opportunity]
- **Location**: `TestFile.php:line`
- **Suggestion**: Optional improvement

## Passed Checks
- ✓ [Check name] (line X)
- ✓ [Check name] (line Y)
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
- ✓ Covers single class (E015)
- ✓ No conditional logic in tests (E001)
- ✓ Single behavior per test method (E002)
- ✓ Correct attribute order (PHPDoc -> DataProvider -> TestDox) (E003)
- ✓ Test method identification correct (E004)
- ✓ Tests behavior, not implementation/trivial/private (E005)
- ✓ Descriptive test names following convention (E006)
- ✓ Data providers used appropriately (E007)
- ✓ Uses static:: for assertions (E008)
- ✓ No redundant test coverage (E009)
- ✓ Test methods follow ordering pattern (E010)
- ✓ TestDox phrasing follows guidelines (E011)
- ✓ Uses StaticEntityRepository for DAL mocking (E012)
- ✓ Class structure follows convention (E013)
- ✓ Exception expectations set before throwing call (E014)
- ✓ Data providers have descriptive keys (W004)
- ✓ Appropriate assertion methods used (W005)
- ✓ Uses Generator::generateSalesChannelContext() instead of legacy method (W006)
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

### [E001] Test contains conditional logic
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

### [E003] Wrong attribute order
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

### [W005] Using assertTrue with comparison
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
- ✓ Covers single class (E015)
- ✓ Test class extends TestCase
- ✓ Class structure order correct (E013)
- ✓ Tests behavior, not implementation/private (E005)
- ✓ Descriptive test names (E006)
- ✓ Uses static:: for assertions (E008)
- ✓ Uses StaticEntityRepository for DAL (E012)
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
