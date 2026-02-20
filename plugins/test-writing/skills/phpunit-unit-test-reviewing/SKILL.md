---
name: phpunit-unit-test-reviewing
version: 1.2.6
description: Reviews PHPUnit unit tests for quality and compliance. Validates test structure, naming conventions, attribute order, mocking strategy, and behavior-focused testing. Use when user requests "review test", "check test quality", "validate test", "analyze test compliance", or mentions reviewing Shopware unit tests.
allowed-tools: Glob, Grep, Read, TodoWrite
---

# PHPUnit Unit Test Review

Reviews a Shopware PHPUnit unit test for compliance with testing guidelines and best practices.

## Overview

Performs comprehensive 14-phase review of PHPUnit unit tests against Shopware testing conventions. Validates:
- Structural compliance (19 error codes: E001-E019)
- Style conventions (14 warnings: W001-W014)
- Best practice opportunities (9 informational: I001-I009)

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

**Codes**: E003 (order), E004 (identification), E008 (setup-method misuse), E011 (TestDox phrasing), W003 (missing TestDox), W008 (class-level TestDox), W014 (#[Package] on test class)

Also check for `static::expectException*()` — these must use `$this->` (E008).

### Phase 4. Review Single Behavior Rule

Check one test = one behavior per [error-code-details-style.md#w011]({baseDir}/references/error-code-details-style.md#w011---unclear-aaa-structure).

**Codes**: E002 (multiple behaviors), W002 (assertion scope), W011 (unclear AAA structure)

### Phase 5. Review Conditionals & Exception Testing

Check for conditionals and exception order per [error-code-details-structure.md]({baseDir}/references/error-code-details-structure.md).

**E018 check**: For every `expectException(SomeClass::class)` call, verify that at least one of `expectExceptionMessage()`, `expectExceptionCode()`, or `expectExceptionObject()` also appears in the same test method. If not, read the exception class to determine if it has parameters or a message template. If it does, flag E018. Skip if the exception is a bare wrapper with no parameters (e.g. a trivial internal guard).

**Codes**: E001 (conditionals in test), E014 (exception expectation order), E018 (weak exception assertion)

### Phase 6. Review Test Independence & Repeatability (FIRST Principles)

Check FIRST principles per [error-code-details-structure.md#e016]({baseDir}/references/error-code-details-structure.md#e016---shared-mutable-state-first-independent).

**Codes**: E016 (shared mutable state), E017 (non-deterministic inputs)

### Phase 7. Review Behavior vs Implementation

Check behavior focus per [error-code-details-style.md#w009]({baseDir}/references/error-code-details-style.md#w009---mystery-guest-file-dependency) and [error-code-details-structure.md#e019]({baseDir}/references/error-code-details-structure.md#e019---call-count-over-coupling).

**E019 check**: For each `->expects($this->once())->method('foo')` chain, check: (1) does the same mock variable also have `->willReturn(...)`? (2) does the test later assert the returned/computed value? If both are true, the call-count is redundant — flag E019. Skip if the method is a side-effect-only call (returns `void` or the return value is never asserted): `dispatch()`, `write()`, `send()`, `persist()`.

**E019 fix branching**: When the chain also includes `->with(static::callback(...))`, the fix is `expects($this->atLeastOnce())` — NOT full removal. Never use `expects($this->any())` here — it allows 0 invocations, which causes callbacks with assertions inside to silently never fire. PHPUnit silently ignores `->with()` constraints without `expects()`, so removing `expects()` entirely would discard the argument verification. Changing to `expects($this->atLeastOnce())` removes exact-count coupling while guaranteeing the callback fires at least once.

**E019 Scenario B**: For each mock variable that has `->with(static::callback(...))`, verify `->expects(...)` also appears on that same chain. If absent, flag E019. Fix: add `->expects($this->once())` before `->method(...)`.

**Codes**: E005 (implementation details/trivial code/call-count over-coupling), E008 (static assertions), E019 (call-count over-coupling), W005 (assertion methods), W009 (mystery guest)

### Phase 8. Review Mocking Strategy

Check mocking per [mocking-strategy.md]({baseDir}/references/mocking-strategy.md) and [shopware-stubs.md]({baseDir}/references/shopware-stubs.md).

**W012 check**: For each `createMock(Foo::class)` call, search the entire test class for (1) any `->expects(...)` call on that variable, and (2) any `->with(static::callback(...))` argument verification on that variable. If NEITHER exists — only `->method()->willReturn()` chains — flag W012. Suggest replacing with `createStub()` and updating the intersection type to `Foo&Stub`.

**Codes**: E012 (over-mocking), W006 (legacy Generator method), W012 (createMock when createStub suffices), W013 (opaque test data identifiers)

### Phase 9. Review Test Fixture Patterns

**Informational codes**: I001 (data provider consolidation), I003 (PHPUnit 11.5 features), I004 (expectExceptionObject), I006 (callable StaticEntityRepository), I008 (real fixture files for file I/O), I009 (duplicated inline Arrange code)

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
   - **NEVER delete** a test method that is the sole coverage of any code path, even if it appears similar to another test
   - **NEVER collapse** a data provider test into a single parameterless test — when data provider cases are redundant, reduce the case count but preserve the data provider structure

**Codes**: E009 (test method redundancy)

#### 11.2 Data Provider Redundancy (E009)

Check data provider cases for redundancy per [test-case-justification.md]({baseDir}/references/test-case-justification.md).

For each data provider:
- Verify each case covers unique code path
- Check case keys justify existence (not just describe values)

For each data provider method, check if it declares `array` return type or uses `return [` syntax. If so, flag W015.

**Codes**: E007 (missing data provider), E009 (data provider redundancy), W004 (key quality), W007 (naming pattern), W015 (return array instead of yield), I007 (preservation value)

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
| `expectException(Foo::class)` alone (no message/code/object) | E018 | Add `expectExceptionObject()` or `expectExceptionMessage()` |
| `expects($this->once())->method()->willReturn()` + result asserted | E019 | Remove `expects(once())`; if `->with(callback(...))` present, use `expects($this->atLeastOnce())` instead |
| `createMock()` with no `expects()` or argument callbacks on that variable | W012 | Replace with `createStub()`, use `Foo&Stub` type |
| `'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'` as test ID | W013 | Replace with `'product-id'` or other descriptive string |
| `#[Package(...)]` on test class declaration | W014 | Remove the `#[Package]` attribute |

### E009 Method Redundancy Example

For a detailed worked example showing E009 detection and fix, see [test-case-justification.md#worked-example-subtreeextractor]({baseDir}/references/test-case-justification.md#worked-example-subtreeextractor).

### Output Format

For complete report structure and templates, see [output-format.md]({baseDir}/references/output-format.md).
