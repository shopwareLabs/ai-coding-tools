---
name: phpunit-unit-test-reviewing
version: 1.1.0
description: Reviews PHPUnit unit tests for quality and compliance. Validates test structure, naming conventions, attribute order, mocking strategy, and behavior-focused testing. Automatically invoked when reviewing or validating Shopware unit tests.
allowed-tools: Glob, Grep, Read, TodoWrite
---

# PHPUnit Unit Test Review

Reviews a Shopware PHPUnit unit test for compliance with testing guidelines and best practices.

## Overview

Performs comprehensive 14-phase review of PHPUnit unit tests against Shopware testing conventions. Validates:
- Structural compliance (17 error codes: E001-E017)
- Style conventions (11 warnings: W001-W011)
- Best practice opportunities (8 informational: I001-I008)

**Category-aware**: Checks are scoped to test categories (A: DTO, B: Service, C: Flow/Event, D: DAL, E: Exception) per [error-code-summary.md]({baseDir}/references/error-code-summary.md#category-applicability).

**Output**: Structured report with code snippets and suggested fixes per [output-format.md]({baseDir}/references/output-format.md).

## Workflow

### Phase 1. Identify & Classify

1. Locate test file (by path or `Glob("tests/unit/**/*Test.php")`)
2. Verify in `tests/unit/` directory (abort if `tests/integration/`)
3. Check CoversClass covers exactly one class (E015)
4. Determine test category (A-E) per [test-categories.md]({baseDir}/references/test-categories.md)
5. Check class structure order (E013) per [error-code-details-structure.md#e013]({baseDir}/references/error-code-details-structure.md#e013---class-structure-order)
6. Verify extends `TestCase` or appropriate base class
7. Count test methods (data providers, TestDox, conditionals)
8. Read source class under test (from `#[CoversClass]`) to identify distinct code paths for E009 analysis

### Phase 2. Review Test Naming

Check naming conventions per [test-case-justification.md]({baseDir}/references/test-case-justification.md).

**Codes**: E006 (ambiguous/BDD-style names), W001 (implementation-coupled names)

### Phase 3. Review Attribute Order

Check attribute ordering per [phpunit-conventions.md]({baseDir}/references/phpunit-conventions.md).

**Codes**: E003 (order), E004 (identification), E011 (TestDox phrasing), W003 (missing TestDox), W008 (class-level TestDox)

### Phase 4. Review Single Behavior Rule

Check one test = one behavior per [error-code-details-style.md#w011]({baseDir}/references/error-code-details-style.md#w011---unclear-aaa-structure).

**Codes**: E002 (multiple behaviors), W002 (assertion scope), W011 (unclear AAA structure)

### Phase 5. Review Conditionals & Exception Testing

Check for conditionals and exception order per [error-code-details-structure.md]({baseDir}/references/error-code-details-structure.md).

**Codes**: E001 (conditionals in test), E014 (exception expectation order)

### Phase 6. Review Test Independence & Repeatability (FIRST Principles)

Check FIRST principles per [error-code-details-structure.md#e016]({baseDir}/references/error-code-details-structure.md#e016---shared-mutable-state-first-independent).

**Codes**: E016 (shared mutable state), E017 (non-deterministic inputs)

### Phase 7. Review Behavior vs Implementation

Check behavior focus per [error-code-details-style.md#w009]({baseDir}/references/error-code-details-style.md#w009---mystery-guest-file-dependency).

**Codes**: E005 (implementation details/trivial code), E008 (static assertions), W005 (assertion methods), W009 (mystery guest)

### Phase 8. Review Mocking Strategy

Check mocking per [mocking-strategy.md]({baseDir}/references/mocking-strategy.md) and [shopware-stubs.md]({baseDir}/references/shopware-stubs.md).

**Codes**: E012 (over-mocking), W006 (legacy Generator method)

### Phase 9. Review Test Fixture Patterns

**Informational codes**: I001 (data provider consolidation), I003 (PHPUnit 11.5 features), I004 (expectExceptionObject), I006 (callable StaticEntityRepository), I008 (real fixture files for file I/O)

### Phase 10. Review Type Narrowing & Feature Flags

Check feature flags per [feature-flags.md]({baseDir}/references/feature-flags.md).

**Informational codes**: I002 (execution time), I005 (#[DisabledFeatures])

### Phase 11. Review Test Redundancy & Data Providers

#### 11.1 Test Method Redundancy (E009) - MANDATORY

Before checking data providers, analyze test methods for code path redundancy.

**Algorithm:**

1. **Read source class** (from Phase 1 step 8) and identify distinct code paths:
   - List branches/conditions in each public method
   - Note boundary conditions and error paths
   - Example: `extract()` has 3 paths: root-match, child-search, not-found

2. **Build test-to-path mapping table** (REQUIRED OUTPUT):

   | Test Method | Calls | Inputs | Code Path Triggered |
   |-------------|-------|--------|---------------------|
   | testExtractRootElement | extract($root, 'root') | root.id == targetId | PATH 1: Root match |
   | testExtractRootReturnsClone | extract($root, 'root') | root.id == targetId | PATH 1: Root match |
   | testExtractDirectChild | extract($root, 'child') | child in slot | PATH 2: Child search |
   | testReturnsNullWhenNotFound | extract($root, 'missing') | no match | PATH 3: Not found |

3. **Group by code path** and flag groups with 2+ tests:
   - PATH 1: testExtractRootElement, testExtractRootReturnsClone → **E009: 2 tests, same path**
   - PATH 2: testExtractDirectChild → OK (1 test)
   - PATH 3: testReturnsNullWhenNotFound → OK (1 test)

4. **Check preservation indicators** before flagging (see I007):
   - Regression markers: `Regression`, `Bug`, `Issue`, `#\d+`, `SW-`, `JIRA-`
   - If present, report I007 instead of E009

5. **Generate fix** for E009 violations:
   - Merge methods into single test with multiple assertions
   - Or consolidate to data provider if 3+ similar cases

**Codes**: E009 (test method redundancy)

#### 11.2 Data Provider Redundancy (E009)

Check data provider cases for redundancy per [test-case-justification.md]({baseDir}/references/test-case-justification.md).

For each data provider:
- Verify each case covers unique code path
- Check case keys justify existence (not just describe values)

**Codes**: E007 (missing data provider), E009 (data provider redundancy), W004 (key quality), W007 (naming pattern), I007 (preservation value)

### Phase 12. Review Test Method Ordering

Check ordering per [error-code-details-structure.md#e010]({baseDir}/references/error-code-details-structure.md#e010---test-method-ordering).

**Codes**: E010 (happy path → variations → config → edge → error)

### Phase 13. Review Coverage Distribution

Check distribution per [error-code-details-style.md#w010]({baseDir}/references/error-code-details-style.md#w010---unbalanced-coverage-distribution).

**Codes**: W010 (edge+error cases < 20%)

### Phase 14. Generate Report

For output format and examples, see [output-format.md]({baseDir}/references/output-format.md).
For error code reference, see [error-code-summary.md]({baseDir}/references/error-code-summary.md).
For style warnings and informational codes, see [error-code-details-style.md]({baseDir}/references/error-code-details-style.md).

Include for each issue:
- Current code snippet
- Suggested fix code snippet

Include full passed checks list.

## Troubleshooting

### Ambiguous Category Detection

When test characteristics match multiple categories:
1. Check primary class under test via `#[CoversClass]`
2. Use most restrictive category (D > C > B > A)
3. Exception tests (E) take precedence when `expectException` present

### Mixed Test Types

When a test class contains both unit and integration patterns:
- Abort with message: "Mixed test types detected - review unit test portions only"
- Flag E015 (covers multiple classes) if applicable

## Examples

### Status Values

| Status | Condition |
|--------|-----------|
| PASS | 0 errors, 0 warnings |
| NEEDS_ATTENTION | 0 errors, 1+ warnings |
| ISSUES_FOUND | 1+ errors |

### Common Issues Quick Reference

| Pattern Found | Code | Quick Fix |
|---------------|------|-----------|
| `if (` in test body | E001 | Split into separate test methods |
| `testIt...` method name | E006 | Remove BDD-style prefix |
| `$this->assertEquals()` | E008 | Use `static::assertEquals()` |
| Two tests calling same method with same inputs | E009 | Merge into single test with multiple assertions |
| `createMock(EntityRepository::class)` | E012 | Use `StaticEntityRepository` |
| `$this->expectException()` after action | E014 | Move expectation before throwing call |
| Shared `private` property across tests | E016 | Use `setUp()` method instead |

### E009 Method Redundancy Example

For a detailed worked example showing E009 detection and fix, see [test-case-justification.md#worked-example-subtreeextractor]({baseDir}/references/test-case-justification.md#worked-example-subtreeextractor).

### Output Format

For complete report structure and templates, see [output-format.md]({baseDir}/references/output-format.md).
