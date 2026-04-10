---
name: phpunit-unit-test-reviewing
version: 3.3.0
description: Reviews PHPUnit unit tests for quality and compliance. Validates test structure, naming conventions, attribute order, mocking strategy, and behavior-focused testing. Accepts optional method scope for focused reviews. Invoked by agents, not directly by users.
user-invocable: false
allowed-tools: Glob, Grep, Read, mcp__plugin_test-writing_test-rules__get_rules
---

# PHPUnit Unit Test Review

Reviews a Shopware PHPUnit unit test for compliance with testing guidelines and best practices.

## Overview

Performs MCP-driven review of PHPUnit unit tests against Shopware testing conventions, organized by rule group (convention → design → unit → isolation → provider).

**Category-aware**: Rules are scoped to test categories (A: DTO, B: Service, C: Flow/Event, D: DAL, E: Exception) via MCP `mcp__plugin_test-writing_test-rules__get_rules` filtering.

**Scope-aware**: Accepts optional method names. When provided, enters scoped review mode — only violations within the named methods are reported. Class-level context (imports, `#[CoversClass]`, base class) is still read for understanding, but findings outside scoped methods are ignored.

**Output**: Structured report with code snippets and suggested fixes per [output-format.md](references/output-format.md).

### Input

- `{test_path}` (required) — Path to the test file
- `{methods}` (optional) — List of test method names to scope the review to. When omitted, the full class is reviewed.

## Workflow

### Phase 1. Identify & Classify

1. Locate test file (by path or `Glob("tests/unit/**/*Test.php")`)
2. Verify in `tests/unit/` directory (abort if `tests/integration/`)
3. Check CoversClass covers exactly one class
4. Determine test category (A-E) per [test-categories.md](references/test-categories.md)
5. Verify class structure order
6. Verify extends `TestCase` or appropriate base class
7. Count test methods (data providers, TestDox, conditionals)
8. Read source class under test (from `#[CoversClass]`) — needed by rules that analyze test-to-code-path coverage
9. If `{methods}` provided: verify each named method exists in the test class. If a method is not found, report it as a warning and continue with the remaining methods. If no methods match, abort with reason "No matching methods found."

### Phase 2. Rule Review Filters

All `mcp__plugin_test-writing_test-rules__get_rules` calls in Phases 3-7 include these shared filters: `test_type=unit, test_category={detected_category}, scoped_review={true if methods provided, omit otherwise}`.

### Scoped Review Filtering (Phases 3-7)

When `{methods}` is provided, apply this constraint to ALL rule detection in Phases 3-7:

- Apply detection logic only to the named methods and their associated data providers (identified by `#[DataProvider]` attributes on scoped methods)
- Skip methods not in the scope
- The rest of the class is available for context (e.g., checking if a data provider is shared, understanding import statements) but violations outside the scoped methods are not reported

### Phases 3-7. Review Rules by Group

For each group in the table below (in phase order), execute:

1. Call `mcp__plugin_test-writing_test-rules__get_rules(group={group})` with Phase 2 filters
2. For each rule:
   a. Read the rule's Detection/Detection Algorithm sections
   b. Apply the detection logic against the test code (and source class when marked below)
   c. If the rule cross-references other rules, follow the cross-reference
   d. Record violations with the rule's ID, title, and enforce level
3. Generate suggested fixes following each rule's Fix section

| Phase | Group | Covers | + Source class |
|-------|-------|--------|----------------|
| 3 | convention | Naming, attributes, TestDox, assertions, class structure, method ordering | |
| 4 | design | Conditionals, single behavior, test redundancy, data provider usage, coverage distribution | ✓ |
| 5 | unit | Behavior vs implementation focus, mocking strategy, call-count coupling | ✓ |
| 6 | isolation | FIRST principles (Independent, Repeatable), shared state, fixtures, feature flags | |
| 7 | provider | Data provider key quality, naming, yield patterns, TestDox parameters | |

### Phase 8. Generate Report

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
scope:
  mode: scoped | full
  methods: [method1, method2]  # only when mode=scoped
errors:
  - rule_id: {from mcp__plugin_test-writing_test-rules__get_rules response}
    title: {from mcp__plugin_test-writing_test-rules__get_rules response}
    enforce: must-fix
    location: ClassTest.php:45
    current: |
      # problematic code
    suggested: |
      # fixed code
warnings:
  - rule_id: {from mcp__plugin_test-writing_test-rules__get_rules response}
    title: {from mcp__plugin_test-writing_test-rules__get_rules response}
    enforce: should-fix
    location: ClassTest.php:78
    current: |
      # code
    suggested: |
      # improved code
```

## Troubleshooting

### Ambiguous Category Detection

When test characteristics match multiple categories:
1. Check primary class under test via `#[CoversClass]`
2. Use most restrictive category (D > C > B > A)
3. Exception tests (E) take precedence when `expectException` present

### Mixed Test Types

When a test class contains both unit and integration patterns:
- Abort with message: "Mixed test types detected - review unit test portions only"
- Flag the applicable rule if the test covers multiple classes

### MCP Tool Unavailability

If `mcp__plugin_test-writing_test-rules__get_rules` is unavailable:
- Report error: "test-rules MCP server not available — ensure the test-writing plugin is installed and Claude Code was restarted"
- Do not fall back to hardcoded checks

## Examples

### Status Values

| Status | Condition |
|--------|-----------|
| PASS | 0 errors, 0 warnings |
| NEEDS_ATTENTION | 0 errors, 1+ warnings |
| ISSUES_FOUND | 1+ errors |

### Output Format

For complete report structure and templates, see [output-format.md](references/output-format.md).
