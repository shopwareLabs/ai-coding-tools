# Output Format

## Report Structure

```markdown
# PHPUnit Migration Test Generation: [MigrationClassName]

## Summary
- **Source**: `path/to/Migration.php`
- **Test**: `tests/migration/path/to/MigrationTest.php`
- **Status**: SUCCESS | PARTIAL | FAILED

## Generation Details
- **Test Methods**: X methods generated
- **Source Pattern**: schema-add | schema-remove | data-update | config | mail-template | mixed

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
| FAILED | Invalid input (not a migration class, file not found, not MigrationStep) |

## SUCCESS Example

```markdown
# PHPUnit Migration Test Generation: Migration1718615305AddEuToCountryTable

## Summary
- **Source**: `src/Core/Migration/V6_6/Migration1718615305AddEuToCountryTable.php`
- **Test**: `tests/migration/Core/V6_6/Migration1718615305AddEuToCountryTableTest.php`
- **Status**: SUCCESS

## Generation Details
- **Test Methods**: 3 methods generated
- **Source Pattern**: schema-add

## Validation Results
- PHPStan: ✓ Pass
- PHPUnit: ✓ Pass
- ECS: ✓ Pass
```

## FAILED Example

```markdown
# PHPUnit Migration Test Generation: FAILED

- **Input**: `src/Core/Content/Product/ProductEntity.php`
- **Reason**: Not a migration class — class does not extend MigrationStep
```
