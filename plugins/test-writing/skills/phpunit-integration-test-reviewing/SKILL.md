---
name: phpunit-integration-test-reviewing
version: 3.9.0
description: Internal sub-skill. Do not auto-activate. Use only when explicitly invoked by name by another skill or agent.
user-invocable: false
allowed-tools: Glob, Grep, Read, mcp__plugin_test-writing_test-rules__get_rules
---

# PHPUnit Integration Test Review

Reviews a Shopware PHPUnit integration test for compliance with integration testing conventions.

## Overview

Performs MCP-driven review against the integration ruleset (`group: integration`, INTEGRATION-001 through INTEGRATION-008). This skill assumes the test belongs in `tests/integration/` and checks quality within that frame. It does NOT load the placement reasoning rules (`group: placement`) and does NOT decide whether the test should be migrated.

When the assertion-shape smoke check fires (INTEGRATION-008), the report emits a single informational hint pointing at the dedicated migrating skill. The hint never appears as an error or warning.

**Output**: Structured report per references/output-format.md.

## Workflow

### Phase 1: Identify & Validate

1. Locate test file (by path or `Glob("tests/integration/**/*Test.php")`)
2. Verify file is in `tests/integration/` (abort if `tests/unit/` or `tests/migration/`)
3. Read `#[CoversClass(...)]` attribute to identify the SUT
4. Read the full test file content
5. Read any `use IntegrationTestBehaviour;` / base class to understand the lifecycle

### Phase 2: Source Analysis

1. Read the SUT source class identified by `#[CoversClass]` (or each, if multiple)
2. List the SUT's constructor dependencies. INTEGRATION-002 uses this list to distinguish primary collaborators from boundary collaborators.
3. Note whether the SUT has explicit boundary interfaces (HTTP client, mailer, clock, randomness) — these are the allowable mock targets.

### Phase 3: Load Rules

1. Call `mcp__plugin_test-writing_test-rules__get_rules(group=integration, test_type=integration)` to load INTEGRATION-001..008
2. Do NOT call `get_rules(group=placement)`. Placement reasoning is the migrating skill's responsibility.

### Phase 4: Apply Rules

For each rule loaded in Phase 3:

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
