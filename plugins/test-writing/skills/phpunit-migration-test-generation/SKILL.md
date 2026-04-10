---
name: phpunit-migration-test-generation
version: 3.2.2
description: |
  Generates PHPUnit migration tests for Shopware 6 migration classes. Analyzes the source migration's SQL operations, selects appropriate test patterns, and validates with PHPStan and PHPUnit. Use when user asks to "generate migration tests", "write migration test", "create migration test", "test this migration", or mentions test generation for Shopware migrations. Should NOT be used for unit tests — use phpunit-unit-test-generation instead.
user-invocable: true
context: fork
agent: test-writing:test-generator
allowed-tools: Read, Grep, Glob, Write, Edit, mcp__plugin_dev-tooling_php-tooling
---

# PHPUnit Migration Test Generation

Generate Shopware-compliant PHPUnit migration tests that pass PHPStan and PHPUnit validation.

## File Write Restrictions

Write ONLY to:
- `tests/migration/**` — Migration test files

NEVER write to:
- `src/**` — Source code (read-only)
- `tests/unit/**` — Unit tests (out of scope)
- `tests/integration/**` — Integration tests (out of scope)
- Any other directory

## Quick Start

1. Read the target migration source class
2. Analyze SQL operations to determine test pattern
3. Apply the migration test template with conditional sections
4. Validate with PHPStan and PHPUnit
5. Fix any errors and repeat
6. Generate completion report

---

## Phase 1: Validate Input

1. Verify single file provided
2. Verify file exists and is a PHP class (not interface/trait)
3. Verify path contains `Migration/V6_`
4. Verify class extends `Shopware\Core\Framework\Migration\MigrationStep`

If validation fails, return FAILED with reason.

## Phase 2: Analyze Source

Read the migration class and extract information needed for test generation. See [source-analysis.md]({baseDir}/references/source-analysis.md) for detection patterns.

### Step 1: Extract Metadata

- Class name, full namespace
- Timestamp from `getCreationTimestamp()` return value
- `#[Package('...')]` attribute value (default to `'framework'` if absent)
- Area from namespace (`Core`, `Administration`, `Storefront`, `Elasticsearch`)
- Version from namespace (`V6_6`, `V6_7`, `V6_8`)

### Step 2: Classify SQL Operations

Read `update()` and `updateDestructive()` method bodies. Classify:
- **Schema-add**: CREATE TABLE, addColumn(), ALTER TABLE ... ADD
- **Schema-remove**: DROP TABLE, DROP COLUMN, dropColumnIfExists(), dropTableIfExists()
- **Data-update**: UPDATE, INSERT, DELETE on non-config tables
- **Config**: system_config operations
- **Mail-template**: mail_template operations

A migration may contain multiple patterns (e.g., schema-add + data-update).

### Step 3: Check updateDestructive

Determine if `updateDestructive()` has logic:
- Not overridden → no logic
- Empty body or only `parent::updateDestructive()` → no logic
- Any other statement → has logic

### Step 4: Select Traits

Based on detected patterns, select traits per [source-analysis.md]({baseDir}/references/source-analysis.md) trait selection table.

## Phase 3: Generate Test

### Step 1: Determine Test Path

Mirror source path:
- `src/Core/Migration/V6_7/Migration1234Foo.php` → `tests/migration/Core/V6_7/Migration1234FooTest.php`
- `src/Administration/Migration/V6_7/Migration1234Bar.php` → `tests/migration/Administration/V6_7/Migration1234BarTest.php`

### Step 2: Apply Template

Use the migration test template at [migration-test.md]({baseDir}/templates/migration-test.md). Include conditional sections based on Phase 2 analysis:

- **Always**: base template, testGetCreationTimestamp, setUp with Connection
- **Schema-add detected**: rollback method, schema verification test
- **updateDestructive has logic**: updateDestructive test method
- **Data-update detected**: state setup, value assertion test
- **Config detected**: config insert/preserve tests
- **Mail-template detected**: minimal no-exception test

Fill all placeholders using Phase 2 metadata.

### Step 3: Write Test File

Write to the path determined in Step 1.

## Phase 4: Validate and Fix

**CRITICAL**: Use ONLY MCP tools for validation. NEVER use shell commands.

**Prerequisite**: The `dev-tooling` plugin must be installed. If unavailable, proceed to Phase 5 with status PARTIAL.

### Validation Loop

```
- [ ] PHPStan passes (0 errors)
- [ ] PHPUnit passes (all tests green)
- [ ] ECS passes (code style)
```

### Step 1: Run PHPStan

```json
{
  "paths": ["tests/migration/Path/To/GeneratedTest.php"],
  "error_format": "json"
}
```

### Step 2: Fix PHPStan Errors

Common migration test errors:
- Missing imports for `TableHelper`, `KernelLifecycleManager`, `Uuid`, `Defaults`
- Type mismatches in assertion arguments
- Unknown method calls on `Connection`

### Step 3: Run PHPUnit

```json
{
  "paths": ["tests/migration/Path/To/GeneratedTest.php"],
  "output_format": "result-only"
}
```

If tests fail, re-run without `output_format` to get failure details.

### Step 4: Fix Test Failures

Common migration test failures:
- Column/table already exists (rollback not working)
- Wrong timestamp value
- Missing test data setup
- Transaction not rolling back (wrong trait)

### Step 5: Run ECS Check and Fix

Check for violations, then apply fixes if needed.

### Repeat Until Pass

Loop Steps 1-5 until all validations pass. Maximum 3 iterations — after that, proceed to Phase 5 with status PARTIAL.

## Phase 5: Generate Report

For output format and examples, see [output-format.md]({baseDir}/references/output-format.md).

### Status Determination

| Condition | Status |
|-----------|--------|
| All validations pass | SUCCESS |
| Test generated, validation issues remain after 3 iterations | PARTIAL |
| Invalid input | FAILED |
