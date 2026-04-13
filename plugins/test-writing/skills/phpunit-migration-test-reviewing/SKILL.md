---
name: phpunit-migration-test-reviewing
version: 3.3.2
description: |
  Reviews PHPUnit migration tests for quality and compliance. Validates idempotency, cleanup, assertion patterns, and Shopware migration conventions. Use when user requests "review migration test", "check migration test quality", "validate migration test", or mentions reviewing Shopware migration tests. Should NOT be used for unit tests (tests/unit/) — use phpunit-unit-test-reviewing instead.
user-invocable: true
allowed-tools: Glob, Grep, Read, mcp__plugin_test-writing_test-rules__get_rules
---

# PHPUnit Migration Test Review

Reviews a Shopware PHPUnit migration test for compliance with migration testing conventions.

## Overview

Performs MCP-driven review of PHPUnit migration tests against Shopware migration testing rules (MIGRATION-001 through MIGRATION-008). All rules are must-fix.

**Source-aware**: Rules MIGRATION-002 and MIGRATION-004 require reading the source migration class to determine applicability.

**Output**: Structured report per [output-format.md](references/output-format.md).

## Workflow

### Phase 1: Identify & Validate

1. Locate test file (by path or `Glob("tests/migration/**/*Test.php")`)
2. Verify file is in `tests/migration/` directory (abort if `tests/unit/` or `tests/integration/`)
3. Read `#[CoversClass(...)]` attribute to find the source migration class
4. Verify source class extends `Shopware\Core\Framework\Migration\MigrationStep`
5. Read the full test file content

### Phase 2: Source Analysis

1. Read the source migration class identified by `#[CoversClass]`
2. Determine if `updateDestructive()` has logic:
   - Find the `updateDestructive` method body
   - Empty body (`{}`, `{ }`) or only `parent::updateDestructive($connection);` = no logic
   - Any other statements = has logic
3. Identify SQL operations in `update()` and `updateDestructive()`:
   - DDL: `CREATE TABLE`, `ALTER TABLE ... ADD`, `DROP TABLE`, `DROP COLUMN`
   - DML: `INSERT`, `UPDATE`, `DELETE`
   - system_config operations
4. Store this context for rules that need it (MIGRATION-002, MIGRATION-004)

### Phase 3: Load Rules

1. Call `mcp__plugin_test-writing_test-rules__get_rules(test_type=migration)` to load all applicable migration rules
2. All migration rules are in a single group — no group-by-group iteration needed

### Phase 4: Apply Rules

For each rule loaded in Phase 3:

1. Read the rule's Detection / Detection Algorithm section
2. Apply the detection logic against the test code
3. For rules requiring source context (MIGRATION-002, MIGRATION-004), use Phase 2 results
4. Record violations with rule ID, title, enforce level, location, current code, and suggested fix

### Phase 5: Generate Report

For output format and examples, see [output-format.md](references/output-format.md).

Report each issue using the rule's ID and title from `mcp__plugin_test-writing_test-rules__get_rules`:
```
### [{rule_id}] {title}
```

Include for each issue:
- Current code snippet
- Suggested fix code snippet

Include full passed checks list.

### Output Contract

```yaml
test_path: tests/migration/Path/To/MigrationTest.php
status: PASS|ISSUES_FOUND|FAILED
errors:
  - rule_id: MIGRATION-001
    title: "Idempotency — update() called at least twice"
    enforce: must-fix
    location: MigrationTest.php:35
    current: |
      # problematic code
    suggested: |
      # fixed code
warnings: []
reason: null
```

## Troubleshooting

### MCP Tool Unavailability

If `mcp__plugin_test-writing_test-rules__get_rules` is unavailable:
- Report error: "test-rules MCP server not available — ensure the test-writing plugin is installed and Claude Code was restarted"
- Do not fall back to hardcoded checks

### Source Class Not Found

If the `#[CoversClass]` target cannot be located:
- Report FAILED: "Source migration class not found at expected path"
- Include the expected path based on namespace resolution

### Not a Migration Test

If the file is not in `tests/migration/`:
- Report FAILED: "Not a migration test — this skill reviews tests in tests/migration/ only"
- Suggest using `phpunit-unit-test-reviewing` for unit tests
