---
name: phpunit-unit-test-reviewing
version: 3.2.1
description: Reviews PHPUnit unit tests for quality and compliance. Validates test structure, naming conventions, attribute order, mocking strategy, and behavior-focused testing. Invoked by agents, not directly by orchestrators.
allowed-tools: Glob, Grep, Read, mcp__plugin_test-writing_test-rules__list_rules, mcp__plugin_test-writing_test-rules__get_rules
---

# PHPUnit Unit Test Review

Reviews a Shopware PHPUnit unit test for compliance with testing guidelines and best practices.

## Overview

Performs MCP-driven review of PHPUnit unit tests against Shopware testing conventions, organized by rule group (convention → design → unit → isolation → provider).

**Category-aware**: Rules are scoped to test categories (A: DTO, B: Service, C: Flow/Event, D: DAL, E: Exception) via MCP `mcp__plugin_test-writing_test-rules__list_rules` filtering.

**Output**: Structured report with code snippets and suggested fixes per [output-format.md]({baseDir}/references/output-format.md).

## Workflow

### Phase 1. Identify & Classify

1. Locate test file (by path or `Glob("tests/unit/**/*Test.php")`)
2. Verify in `tests/unit/` directory (abort if `tests/integration/`)
3. Check CoversClass covers exactly one class
4. Determine test category (A-E) per [test-categories.md]({baseDir}/references/test-categories.md)
5. Verify class structure order
6. Verify extends `TestCase` or appropriate base class
7. Count test methods (data providers, TestDox, conditionals)
8. Read source class under test (from `#[CoversClass]`) — needed by rules that analyze test-to-code-path coverage

### Phase 2. Discover Applicable Rules

1. Call `mcp__plugin_test-writing_test-rules__list_rules(test_type=unit, test_category={detected_category})` to get all applicable rule IDs
2. Group results by `group`: convention, design, unit, isolation, provider
3. This determines which rules to check — skip rules not in the result set

### Phase 3. Review Convention Rules

Covers naming, attributes, TestDox, assertions, class structure, and method ordering.

1. Filter Phase 2 results to `group=convention`
2. Call `mcp__plugin_test-writing_test-rules__get_rules(ids={comma-separated convention IDs})`
3. For each rule:
   a. Read the rule's Detection/Detection Algorithm sections
   b. Apply the detection logic against the test code
   c. If the rule cross-references other rules, follow the cross-reference
   d. Record violations with the rule's ID, title, and enforce level
4. Generate suggested fixes following each rule's Fix section

### Phase 4. Review Design Rules

Covers conditionals, single behavior, test redundancy, data provider usage, and coverage distribution.

1. Filter Phase 2 results to `group=design`
2. Call `mcp__plugin_test-writing_test-rules__get_rules(ids={comma-separated design IDs})`
3. For each rule:
   a. Read the rule's Detection/Detection Algorithm sections
   b. Apply the detection logic against the test code and source class
   c. If the rule cross-references other rules, follow the cross-reference
   d. Record violations with the rule's ID, title, and enforce level
4. Generate suggested fixes following each rule's Fix section

### Phase 5. Review Unit Rules

Covers behavior vs implementation focus, mocking strategy, and call-count coupling.

1. Filter Phase 2 results to `group=unit`
2. Call `mcp__plugin_test-writing_test-rules__get_rules(ids={comma-separated unit IDs})`
3. For each rule:
   a. Read the rule's Detection/Detection Algorithm sections
   b. Apply the detection logic against the test code and source class
   c. If the rule cross-references other rules, follow the cross-reference
   d. Record violations with the rule's ID, title, and enforce level
4. Generate suggested fixes following each rule's Fix section

### Phase 6. Review Isolation Rules

Covers FIRST principles (Independent, Repeatable), shared state, fixtures, and feature flags.

1. Filter Phase 2 results to `group=isolation`
2. Call `mcp__plugin_test-writing_test-rules__get_rules(ids={comma-separated isolation IDs})`
3. For each rule:
   a. Read the rule's Detection/Detection Algorithm sections
   b. Apply the detection logic against the test code
   c. If the rule cross-references other rules, follow the cross-reference
   d. Record violations with the rule's ID, title, and enforce level
4. Generate suggested fixes following each rule's Fix section

### Phase 7. Review Provider Rules

Covers data provider key quality, naming, yield patterns, and TestDox parameters.

1. Filter Phase 2 results to `group=provider`
2. Call `mcp__plugin_test-writing_test-rules__get_rules(ids={comma-separated provider IDs})`
3. For each rule:
   a. Read the rule's Detection/Detection Algorithm sections
   b. Apply the detection logic against the test code
   c. If the rule cross-references other rules, follow the cross-reference
   d. Record violations with the rule's ID, title, and enforce level
4. Generate suggested fixes following each rule's Fix section

### Phase 8. Generate Report

For output format and examples, see [output-format.md]({baseDir}/references/output-format.md).

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

If `mcp__plugin_test-writing_test-rules__list_rules` or `mcp__plugin_test-writing_test-rules__get_rules` tools are unavailable:
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

For complete report structure and templates, see [output-format.md]({baseDir}/references/output-format.md).
