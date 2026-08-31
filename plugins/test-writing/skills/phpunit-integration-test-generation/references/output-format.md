# Output Format

## Report Structure

```markdown
# PHPUnit Integration Test Generation: [SourceClassName]

## Summary
- **Source**: `path/to/Source.php`
- **Test**: `tests/integration/path/to/SourceTest.php`
- **Status**: SUCCESS | PARTIAL | SKIPPED | FAILED
- **Pattern**: controller | message-handler | indexer | dal-flow | multi-service | —
- **Package**: `{value}` | none — derivation yielded no value (present on SUCCESS and PARTIAL)

## Generation Details
- **Test Methods**: X methods generated
- **Traits Applied**: IntegrationTestBehaviour [, SalesChannelApiTestBehaviour, ...]

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

| Status | Condition | skip_type |
|--------|-----------|-----------|
| SUCCESS | All validations pass | — |
| PARTIAL | Test generated, validation issues remain after 3 iterations | — |
| SKIPPED | Source class is unit-shape (no integration pattern matched) | `unit_test_more_appropriate` |
| FAILED | Invalid input (not a PHP class, file not found, not in `src/`) | — |

## Output Contract

```yaml
source: src/Path/To/Source.php
test_path: tests/integration/Path/To/SourceTest.php
status: SUCCESS|PARTIAL|SKIPPED|FAILED
pattern: controller|message-handler|indexer|dal-flow|multi-service|null
package: framework|null  # null when derivation yielded no value; present on SUCCESS/PARTIAL
skip_type: null  # "unit_test_more_appropriate" when SKIPPED
reason: null     # explanation when SKIPPED or FAILED
```

## SUCCESS Example

```markdown
# PHPUnit Integration Test Generation: ProductIndexer

## Summary
- **Source**: `src/Core/Content/Product/DataAbstractionLayer/ProductIndexer.php`
- **Test**: `tests/integration/Core/Content/Product/DataAbstractionLayer/ProductIndexerTest.php`
- **Status**: SUCCESS
- **Pattern**: indexer
- **Package**: `content`

## Generation Details
- **Test Methods**: 2 methods generated
- **Traits Applied**: IntegrationTestBehaviour

## Validation Results
- PHPStan: ✓ Pass
- PHPUnit: ✓ Pass
- ECS: ✓ Pass
```

## SKIPPED Example (unit-shape SUT)

```markdown
# PHPUnit Integration Test Generation: SKIPPED

- **Input**: `src/Core/Framework/App/Manifest/Xml/CmsExtensions.php`
- **Reason**: Source class fits a unit-shape pattern (XML parser with `__DIR__`-relative fixtures). Use `phpunit-unit-test-generation` instead. See `phpunit-integration-to-unit-migrating/references/refactoring-patterns.md` Pattern 4.
- **skip_type**: unit_test_more_appropriate
```

## FAILED Example

```markdown
# PHPUnit Integration Test Generation: FAILED

- **Input**: `tests/integration/Core/Content/Product/ProductEntityTest.php`
- **Reason**: Input path is not under `src/` — integration test generation requires a source file in `src/`
```

## PARTIAL Example

```markdown
# PHPUnit Integration Test Generation: ProductCloneRoute

## Summary
- **Source**: `src/Core/Content/Product/SalesChannel/ProductCloneRoute.php`
- **Test**: `tests/integration/Core/Content/Product/SalesChannel/ProductCloneRouteTest.php`
- **Status**: PARTIAL
- **Pattern**: controller
- **Package**: `content`

## Validation Results
- PHPStan: ✓ Pass
- PHPUnit: ✗ 1 failure
- ECS: ✓ Pass

## Remaining Issues
| Location | Error | Status |
|----------|-------|--------|
| line 62 | Expected status 200, got 400 — missing required JSON body field `targetSalesChannelId` | Unfixed after 3 attempts; SUT input data needs human review |
```
