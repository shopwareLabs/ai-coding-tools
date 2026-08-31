---
name: phpunit-integration-test-reviewing
version: 4.2.5
description: Internal sub-skill. Do not auto-activate. Use only when explicitly invoked by name by another skill or agent.
user-invocable: false
allowed-tools: Glob, Grep, Read, mcp__plugin_test-writing_test-rules__get_rules
---

# PHPUnit Integration Test Review

Review a Shopware PHPUnit integration test for compliance with integration testing conventions.

## Overview

Review the test against the composed integration catalog — INTEGRATION-001 through INTEGRATION-008 together with every convention, design, isolation, and provider rule whose `test-types` declares `integration` — assuming it belongs in `tests/integration/`. Do NOT load the placement reasoning rules (`group: placement`) and do NOT decide whether the test should be migrated.

When the assertion-shape smoke check fires (INTEGRATION-008), the report emits a single informational hint pointing at the dedicated migrating skill. The hint never appears as an error or warning.

**Scope-aware**: When method names are provided, report only violations within those methods. Still read class-level context (imports, `#[CoversClass]`, base class) for understanding, but ignore findings outside the scoped methods.

**Output**: Structured report per references/output-format.md.

### Input

- `{test_path}` (required) — Path to the integration test file.
- `{methods}` (optional) — List of test method names to scope the review to. When omitted, the full class is reviewed.
- `{review_unit}` (optional) — `method`, `class-structure`, `class-bodies`, or a list of these. When set, only rules whose minimal evaluation unit matches load. When omitted, all rules load. Orthogonal to `{methods}`.
- `{digest}` (optional) — a pre-extracted, body-free structural digest of the test class. When set, review this text and skip reading the test file. Forces `class-structure` rules only. See Digest Mode.
- `{rules}` (optional) — the pre-rendered rule catalog as text, provided in your prompt. When set, enter Inline-Rules Mode: select rules from this text instead of calling `get_rules`. When omitted, rules load via `get_rules`. See Inline-Rules Mode.

## Workflow

### Phase 1: Identify & Validate

If `{digest}` is set, skip this phase and follow Digest Mode below instead.

1. Locate test file (by path or `Glob("tests/integration/**/*Test.php")`)
2. Verify file is in `tests/integration/` (abort if `tests/unit/` or `tests/migration/`)
3. Read `#[CoversClass(...)]` attribute to identify the SUT
4. Read the full test file content
5. Read any `use IntegrationTestBehaviour;` / base class to understand the lifecycle
6. If `{methods}` provided: verify each named method exists. If a method is not found, report it as a warning and continue with the rest. If no methods match, abort with reason "No matching methods found."

### Phase 2: Source Analysis

1. Read the SUT source class identified by `#[CoversClass]` (or each, if multiple)
2. List the SUT's constructor dependencies. INTEGRATION-002 uses this list to distinguish primary collaborators from boundary collaborators.
3. Note whether the SUT has explicit boundary interfaces (HTTP client, mailer, clock, randomness) — these are the allowable mock targets.

### Phase 3: Rule Review Filters

All `mcp__plugin_test-writing_test-rules__get_rules` calls in Phase 4 carry `test_type=integration` and NO `group` — that composes the catalog for this test type. Adding `group=integration` narrows it back to the integration group alone and drops every shared rule.

When `{methods}` is provided, also add `scoped_review=true`. When `{review_unit}` is set, also add `review_unit={value}`; the filter is single-valued per call, so for a list (e.g. the fused whole-class track `[class-structure, class-bodies]`) issue one call per value and union the results. Never pass a `test_category` filter — A–E categories are a unit-review axis.

Do NOT call `get_rules(group=placement)`. Placement reasoning is the migrating skill's responsibility.

### Scoped Review Filtering (Phase 4)

When `{methods}` is provided, apply detection only to the named methods and their associated data providers (identified by `#[DataProvider]` attributes on scoped methods). The rest of the class is available for context, but violations outside the scoped methods are not reported.

### Digest Mode

When `{digest}` is set, the supplied text is the only artifact under review:

- Do NOT `Read` the test file or the source class. The digest is body-free (class declaration, `#[CoversClass]`, member order, method signatures, attribute lines, property declarations) and self-contained for class-structure rules.
- Force `review_unit=class-structure`. In Phase 4, call `get_rules(test_type=integration, review_unit=class-structure)` with NO `scoped_review`. Apply whatever rules the filter returns — the composed catalog's class-structure rules are CONV-005, CONV-007, and CONV-015. When `{rules}` is also set, instead select the class-structure rules from the inline text per Inline-Rules Mode (`Review unit` == `class-structure`).
- Report `location` as a member name or attribute from the digest (line numbers are unavailable without the file body).
- `{methods}` and `{review_unit}` inputs are subsumed: the digest defines the scope and the unit.

### Inline-Rules Mode

When `{rules}` is set, the catalog is provided as text in your prompt: **select** rules from that text instead of calling `get_rules` in Phase 4. Each rule in the text is a metadata header — `# {id} — {title}`, then `Group: … | Enforce: …`, then `Test types: … | Categories: … | Scope: … | Review unit: … | Scoped review: …` — followed by the rule body. The text is already the composed catalog for this test type, so every rule in it applies here: never filter on `Group`. Select a rule when ALL hold:

- if `{review_unit}` is set: its `Review unit` equals that value (for a list, take the union over the values), **and**
- if `{methods}` is set (scoped review): its `Scoped review` is not `exclude`.

Do not filter on `Categories` — A–E is a unit-review axis. Apply each selected rule's detection algorithm. While `{rules}` is set, the inline text is the complete rule set: **NEVER** read, open, search, or locate a rule file by any means — no `Read`/`Grep`/`Glob`, no `get_rules`. (Reading the test file and its source class is unaffected.) When `{rules}` is omitted, rules load via `get_rules` with the Phase 3 filters.

### Phase 4: Apply Rules

For each rule obtained (inline selection or `get_rules`):

1. Read the rule's Detection section
2. Apply the detection logic against the test code (and source class when needed by INTEGRATION-002)
3. Record violations with rule ID, title, enforce level, location, current code, and suggested fix
4. For INTEGRATION-008 specifically: the rule produces a HINT, not an error or warning. Apply once per class, emit at most once in the Informational section. Do not deliberate further — the deep audit lives in the migrating skill.

### Phase 5: Generate Report

For output format and examples, see references/output-format.md.

Report each issue using the rule's ID and title from `mcp__plugin_test-writing_test-rules__get_rules`:

```
### [{rule_id}] {title}
```

Include for each issue:
- Current code snippet
- Suggested fix code snippet

Include the placement hint as a single line in the Informational section when INTEGRATION-008 fires.

Include full passed checks list.

### Output Contract

```yaml
test_path: tests/integration/Path/To/SomeTest.php
status: PASS|NEEDS_ATTENTION|ISSUES_FOUND|FAILED
errors:
  - rule_id: INTEGRATION-001
    title: "Integration test uses Shopware integration base"
    enforce: must-fix
    location: SomeTest.php:25
    current: |
      # problematic code
    suggested: |
      # fixed code
warnings:
  - rule_id: INTEGRATION-007
    title: "Setup-to-assertion ratio is balanced"
    enforce: should-fix
    location: SomeTest.php:60
    current: |
      # code
    suggested: |
      # improved code
informational:
  - rule_id: INTEGRATION-008
    title: "Placement smoke check"
    hint: "Every assertion is unit-shape. Consider invoking phpunit-integration-to-unit-migrating on this file."
reason: null
```

## Status Values

| Status | Condition |
|--------|-----------|
| PASS | 0 errors, 0 warnings (informational hints do not change status) |
| NEEDS_ATTENTION | 0 errors, 1+ warnings |
| ISSUES_FOUND | 1+ errors |
| FAILED | Invalid input (file not found, not in tests/integration/) |

## Track-Scoped Invocations

The team review decomposes large files into per-track reviews. Each track also receives `{rules}` (the pre-rendered catalog text in its prompt), so rule loading is Inline-Rules Mode selection rather than `get_rules`. Each track sets the inputs below:

- **Method track** — `test_path=…SomeTest.php`, `methods=[testCreate, testList]`, `review_unit=method`. Selects the catalog's `method` rules and judges only the named methods.
- **Fused whole-class track** — `test_path=…`, `review_unit=[class-structure, class-bodies]`, plus `methods=[…]` when the review is scoped. Reads full bodies; selects the class-structure and class-bodies rules from the inline text and unions them.
- **Class-structure digest** — `digest="<class shape text>"`, no `test_path` read. Per Digest Mode: select the `class-structure` rules from the inline text and judge them against the digest.

## Troubleshooting

### MCP Tool Unavailability

If `mcp__plugin_test-writing_test-rules__get_rules` is unavailable:
- Report error: "test-rules MCP server not available — ensure the test-writing plugin is installed and Claude Code was restarted"
- Do not fall back to hardcoded checks

### Not an Integration Test

If the file is not in `tests/integration/`:
- Report FAILED: "Not an integration test — this skill reviews tests in tests/integration/ only"
- Suggest `phpunit-unit-test-reviewing` for `tests/unit/` and `phpunit-migration-test-reviewing` for `tests/migration/`

### Source Class Not Found

If the `#[CoversClass]` target cannot be located:
- Continue the review; INTEGRATION-002 falls back to flagging any non-boundary mock without the SUT-collaborator cross-check
- Note in the report that source resolution failed and which rule was affected

### Placement vs. Review Boundary

The placement reasoning rules (`group: placement`, PLACEMENT-001..008) are NOT loaded by this skill. If the smoke check fires (INTEGRATION-008), the report emits a single hint; users must invoke `phpunit-integration-to-unit-migrating` explicitly to run the deliberation. Do not deliberate inline.
