---
name: phpunit-migration-test-reviewing
version: 4.2.5
description: Internal sub-skill. Do not auto-activate. Use only when explicitly invoked by name by another skill or agent.
user-invocable: false
allowed-tools: Glob, Grep, Read, mcp__plugin_test-writing_test-rules__get_rules
---

# PHPUnit Migration Test Review

Review a Shopware PHPUnit migration test for compliance with migration testing conventions.

## Overview

Review the test against the Shopware migration testing rules (MIGRATION-001 through MIGRATION-009). All rules are must-fix.

**Source-aware**: Read the source migration class for the rules that need it (MIGRATION-002, MIGRATION-004).

**Scope-aware**: When method names are provided, report only violations within those methods. Still read class-level context (imports, `#[CoversClass]`, base class) for understanding, but ignore findings outside the scoped methods.

**Output**: Structured report per references/output-format.md.

### Input

- `{test_path}` (required) — Path to the migration test file.
- `{methods}` (optional) — List of test method names to scope the review to. When omitted, the full class is reviewed.
- `{review_unit}` (optional) — `method`, `class-structure`, `class-bodies`, or a list of these. When set, only rules whose minimal evaluation unit matches load. When omitted, all rules load. Orthogonal to `{methods}`.
- `{digest}` (optional) — a pre-extracted, body-free structural digest of the test class. When set, review this text and skip reading the test file. Forces `class-structure` rules only. See Digest Mode.
- `{rules}` (optional) — the pre-rendered rule catalog as text, provided in your prompt. When set, enter Inline-Rules Mode: select rules from this text instead of calling `get_rules`. When omitted, rules load via `get_rules`. See Inline-Rules Mode.

## Workflow

### Phase 1: Identify & Validate

If `{digest}` is set, skip this phase and follow Digest Mode below instead.

1. Locate test file (by path or `Glob("tests/migration/**/*Test.php")`)
2. Verify file is in `tests/migration/` directory (abort if `tests/unit/` or `tests/integration/`)
3. Read `#[CoversClass(...)]` attribute to find the source migration class
4. Verify source class extends `Shopware\Core\Framework\Migration\MigrationStep`
5. Read the full test file content
6. If `{methods}` provided: verify each named method exists. If a method is not found, report it as a warning and continue with the rest. If no methods match, abort with reason "No matching methods found."

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

### Phase 3: Rule Review Filters

All `mcp__plugin_test-writing_test-rules__get_rules` calls in Phase 4 carry `test_type=migration` and `group=migration`.

When `{methods}` is provided, also add `scoped_review=true`. When `{review_unit}` is set, also add `review_unit={value}`; the filter is single-valued per call, so for a list (e.g. the fused whole-class track `[class-structure, class-bodies]`) issue one call per value and union the results. Migration rules carry no `test_category` — never pass a category filter.

### Scoped Review Filtering (Phase 4)

When `{methods}` is provided, apply detection only to the named methods and their associated data providers. The rest of the class is available for context, but violations outside the scoped methods are not reported.

### Digest Mode

When `{digest}` is set, the supplied text is the only artifact under review:

- Do NOT `Read` the test file or the source class. The digest is body-free (class declaration, `#[CoversClass]`, member order, method signatures, attribute lines, property declarations) and self-contained for class-structure rules.
- Force `review_unit=class-structure`. In Phase 4, call `get_rules(group=migration, test_type=migration, review_unit=class-structure)` with NO `scoped_review`. Apply whatever rules the filter returns — MIGRATION-008 is the migration group's class-structure rule. When `{rules}` is also set, instead select the class-structure rules from the inline text per Inline-Rules Mode (group match + `Review unit` == `class-structure`).
- Report `location` as a member name or attribute from the digest (line numbers are unavailable without the file body).
- `{methods}` and `{review_unit}` inputs are subsumed: the digest defines the scope and the unit.

### Inline-Rules Mode

When `{rules}` is set, the catalog is provided as text in your prompt: **select** rules from that text instead of calling `get_rules` in Phase 4. Each rule in the text is a metadata header — `# {id} — {title}`, then `Group: … | Enforce: …`, then `Test types: … | Categories: … | Scope: … | Review unit: … | Scoped review: …` — followed by the rule body. Select a rule when ALL hold:

- its `Group` equals `migration`, **and**
- if `{review_unit}` is set: its `Review unit` equals that value (for a list, take the union over the values), **and**
- if `{methods}` is set (scoped review): its `Scoped review` is not `exclude`.

Migration rules carry `Categories: all`; do not filter on category. Apply each selected rule's detection algorithm. While `{rules}` is set, the inline text is the complete rule set: **NEVER** read, open, search, or locate a rule file by any means — no `Read`/`Grep`/`Glob`, no `get_rules`. (Reading the test file and its source class is unaffected.) When `{rules}` is omitted, rules load via `get_rules` with the Phase 3 filters.

### Phase 4: Apply Rules

For each rule obtained (inline selection or `get_rules`):

1. Read the rule's Detection / Detection Algorithm section
2. Apply the detection logic against the test code
3. For rules requiring source context (MIGRATION-002, MIGRATION-004), use Phase 2 results
4. Record violations with rule ID, title, enforce level, location, current code, and suggested fix

### Phase 5: Generate Report

For output format and examples, see references/output-format.md.

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

## Track-Scoped Invocations

The team review decomposes large files into per-track reviews. Each track also receives `{rules}` (the pre-rendered catalog text in its prompt), so rule loading is Inline-Rules Mode selection rather than `get_rules`. Each track sets the inputs below:

- **Method track** — `test_path=…MigrationTest.php`, `methods=[testMigration, testMultipleExecutions]`, `review_unit=method`. Selects `method` migration rules and judges only the named methods.
- **Fused whole-class track** — `test_path=…`, `review_unit=[class-structure, class-bodies]`, plus `methods=[…]` when scoped. Reads full bodies; selects the class-structure and class-bodies rules from the inline text and unions them.
- **Class-structure digest** — `digest="<class shape text>"`, no `test_path` read. Per Digest Mode: select the `class-structure` migration rules from the inline text and judge them against the digest.

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
