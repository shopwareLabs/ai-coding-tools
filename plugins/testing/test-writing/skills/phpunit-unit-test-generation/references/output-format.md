# Output Format

## Report Structure

```markdown
# PHPUnit Unit Test Generation: [SourceClassName]

## Summary
- **Source**: `path/to/SourceClass.php`
- **Test**: `tests/unit/path/to/SourceClassTest.php`
- **Status**: SUCCESS | PARTIAL | SKIPPED | FAILED
- **Category**: [A-E] ([Category Name])

## Generation Details
- **Test Methods**: X methods generated
- **Template Used**: category-[a-e]-[name].md

## Validation Results
- PHPStan: ✓ Pass | ✗ X errors
- PHPUnit: ✓ Pass | ✗ X failures
- ECS: ✓ Pass | ✗ X issues

## Remaining Issues (if PARTIAL)
| Location | Error | Status |
|----------|-------|--------|
| line X | description | Unfixed after 3 attempts |
```

## Status Values

| Status | Condition |
|--------|-----------|
| SUCCESS | All validations pass |
| PARTIAL | Test generated, validation issues remain after 3 iterations |
| SKIPPED | No test required (per Test Requirement Rules) |
| FAILED | Invalid input (not a PHP class, file not found) |

## SUCCESS Example

```markdown
# PHPUnit Unit Test Generation: ProductPriceCalculator

## Summary
- **Source**: `src/Core/Content/Product/ProductPriceCalculator.php`
- **Test**: `tests/unit/Core/Content/Product/ProductPriceCalculatorTest.php`
- **Status**: SUCCESS
- **Category**: B (Service)

## Generation Details
- **Test Methods**: 4 methods generated
- **Template Used**: category-b-service.md

## Validation Results
- PHPStan: ✓ Pass
- PHPUnit: ✓ Pass
- ECS: ✓ Pass
```

## PARTIAL Example

```markdown
# PHPUnit Unit Test Generation: ComplexValidator

## Summary
- **Source**: `src/Core/Framework/Validation/ComplexValidator.php`
- **Test**: `tests/unit/Core/Framework/Validation/ComplexValidatorTest.php`
- **Status**: PARTIAL
- **Category**: B (Service)

## Generation Details
- **Test Methods**: 6 methods generated
- **Template Used**: category-b-service.md

## Validation Results
- PHPStan: ✗ 1 error
- PHPUnit: ✓ Pass
- ECS: ✓ Pass

## Remaining Issues
| Location | Error | Status |
|----------|-------|--------|
| line 45 | Parameter $data has no type declaration | Unfixed after 3 attempts |
```

## SKIPPED Example

```markdown
# PHPUnit Unit Test Generation: SKIPPED

- **Source**: `src/Core/Content/Product/ProductEntity.php`
- **Reason**: Pure accessor - no logic to test
```

## FAILED Example

```markdown
# PHPUnit Unit Test Generation: FAILED

- **Input**: `src/Core/Content/NonExistent.php`
- **Reason**: File not found
```
