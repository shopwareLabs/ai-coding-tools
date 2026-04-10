# Output Format

## Report Structure

```markdown
# PHPUnit Unit Test Generation: [SourceClassName]

## Summary
- **Source**: `path/to/SourceClass.php`
- **Test**: `tests/unit/path/to/SourceClassTest.php`
- **Status**: SUCCESS | PARTIAL | SKIPPED | FAILED
- **Skip Type**: coverage_excluded | no_logic (only when SKIPPED)
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

Omit Generation Details, Validation Results, and Remaining Issues for SKIPPED and FAILED.

## Status Values

| Status | Condition | skip_type |
|--------|-----------|-----------|
| SUCCESS | All validations pass | — |
| PARTIAL | Test generated, validation issues remain after 3 iterations | — |
| SKIPPED | File excluded from coverage in phpunit.xml.dist | `coverage_excluded` |
| SKIPPED | No testable logic (per Test Requirement Rules) | `no_logic` |
| FAILED | Invalid input (not a PHP class, file not found) | — |

### skip_type Field

Only present when status is SKIPPED. Distinguishes the reason so the orchestrator can offer to add trivial files to phpunit.xml.dist coverage exclusions.

- `coverage_excluded` — file already excluded in phpunit.xml.dist, no action needed
- `no_logic` — file has no testable logic, orchestrator may offer to add it to exclusions

## Example

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

## Short-Form Outputs

For SKIPPED and FAILED, use this compact format:

```markdown
# PHPUnit Unit Test Generation: SKIPPED

- **Source**: `{path}`
- **Reason**: {reason}
- **Skip Type**: {no_logic | coverage_excluded}
```

```markdown
# PHPUnit Unit Test Generation: FAILED

- **Input**: `{path}`
- **Reason**: {reason}
```
