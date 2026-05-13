# Output Format

The migrating skill produces two reports: an **audit report** before the user confirms execution, and a **migration report** after execution.

## Audit Report (Phase 5)

```markdown
# Integration-to-Unit Migration Audit

## Scope
- **Type**: file | directory | pr | branch
- **Resolved**: N files

## Buckets

### Migrate (M tests across F files)
- `tests/integration/Path/To/SomeTest.php` (all methods)
  - **SUT contract**: The SUT serializes and deserializes date values via encode/decode.
  - **Contract shape**: unit
  - **Verdicts**: PLACEMENT-001 service_locator, PLACEMENT-002 materializer, PLACEMENT-004 all_unit, PLACEMENT-005 r_count_0, PLACEMENT-008 no_veto
  - **Pattern**: Pattern 6 (DAL materializer)
  - **Target**: `tests/unit/Path/To/SomeTest.php`

### Split (M tests across F files)
- `tests/integration/Path/To/MixedTest.php`
  - **SUT contract**: The SUT calculates discounts and persists discount audit rows.
  - **Contract shape**: mixed
  - **Migrate methods**: `testCalculatesDiscount`, `testCalculatesDiscountForEmptyCart`
  - **Keep methods**: `testPersistsDiscountAudit`, `testIndexerUpdatesDiscountTotal`
  - **Pattern**: Pattern 1 (container-fetched service) for migrated methods
  - **Target**: `tests/unit/Path/To/DiscountCalculatorTest.php` (new) + `tests/integration/Path/To/MixedTest.php` (trimmed)

### Keep (M tests across F files)
- `tests/integration/Path/To/PersistTest.php`
  - **SUT contract**: The SUT persists orders and triggers the stock indexer.
  - **Veto**: PLACEMENT-008 veto_persistence — assertion reads back persisted stock value through DAL.

### Delete as duplicate (M tests across F files)
- `tests/integration/Path/To/DuplicateTest.php`
  - **Duplicate of**: `tests/unit/Path/To/SameClassTest.php`
  - **Action**: delete integration file; no replacement needed.

## Refactoring Patterns Required
- Pattern 1: Container-fetched factory or stateless service (M tests)
- Pattern 6: DAL materializer (M tests)

## Confirmation Required
Use `AskUserQuestion` to confirm:
- Proceed with Migrate set? (default: all)
- Proceed with Split set? (default: all)
- Proceed with Delete set? (default: all)
- Keep set requires no action.
```

## Migration Report (Phase 7)

```markdown
# Integration-to-Unit Migration Complete

## Summary
- **Scope**: directory `tests/integration/Core/Framework/App/Cms/`
- **Migrated**: M methods across F files
- **Split**: S methods moved, K methods kept
- **Deleted as duplicate**: D files
- **Kept**: K files

## Files Created
- `tests/unit/Core/Framework/App/Cms/CmsExtensionsTest.php`
- `tests/unit/Core/Framework/App/Cms/Xml/BlockTest.php`
- ...

## Files Modified
- `tests/integration/Core/Framework/App/Cms/CmsExtensionsTest.php` (trimmed; 3 methods moved, 1 method kept)

## Files Deleted
- `tests/integration/Core/Framework/App/Cms/Xml/BlockTest.php` (all methods migrated)
- `tests/integration/Core/Framework/App/CustomFieldTypeTestBehaviour.php` (duplicate of AppLifecycleTest)

## Fixtures Moved
- `tests/integration/.../_fixtures/valid/cmsExtensionsWithBlocks.xml` → `tests/unit/.../_fixtures/Resources/cmsExtensionsWithBlocks.xml`

## Next Steps
- Run PHPUnit on the new unit tests: `phpunit tests/unit/Core/Framework/App/Cms/`
- Run PHPStan/ECS on the migrated files
- Re-invoke `phpunit-unit-test-reviewing` on each new unit test if conformance review is desired
- Review the integration files that were trimmed (not deleted) to confirm the remaining methods still justify integration placement

## Status
MIGRATED
```

## Decline Report (Phase 5 — user declined)

```markdown
# Integration-to-Unit Migration Audit (Declined)

## Scope
[same as audit report]

## Buckets
[same as audit report]

## Status
DECLINED — no changes made. The audit report above is preserved for reference.
```

## Failure Report

```markdown
# Integration-to-Unit Migration: FAILED

**Reason**: {reason}
**Scope**: {scope}
**Suggestion**: {guidance}
```

| Reason | Suggestion |
|--------|------------|
| Scope contains no integration tests | Verify the scope. Use `Glob("tests/integration/**/*Test.php")` to list integration tests. |
| test-rules MCP server not available | Ensure the test-writing plugin is installed and Claude Code was restarted. |
| Scope > 20 files | Narrow scope or proceed in batches by directory. |
| All SUT contracts unclear | Refactor the tests for clarity (one SUT per test class, explicit `#[CoversClass]`) before re-running the audit. |
