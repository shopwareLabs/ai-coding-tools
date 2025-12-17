# Error Codes Summary

Quick-reference for error codes and category applicability.

## Table of Contents
- [Category Applicability](#category-applicability)
- [Status Determination](#status-determination)
- [Error Codes (E###)](#errors-e---must-fix)
- [Warning Codes (W###)](#warnings-w---should-fix)
- [Informational (I###)](#informational-i---optional)

## Category Applicability

Single source of truth for which checks apply to which test categories.

**Legend**: ✓ = Apply, - = Skip, ? = Conditional (see notes)

### Test Categories

| Cat | Name | Description |
|-----|------|-------------|
| A | Simple DTO | Tests value objects, entities, simple data structures |
| B | Service | Tests services with dependencies (mocking required) |
| C | Flow/Event | Tests event subscribers, flow actions |
| D | DAL | Tests using StaticEntityRepository |
| E | Exception | Tests exception handling paths |

### Errors by Category

| Check | A | B | C | D | E | Notes |
|-------|---|---|---|---|---|-------|
| E001 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - no conditionals |
| E002 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - single behavior |
| E003 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - attribute order |
| E004 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - test method identification |
| E005 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - behavior not implementation/trivial/private |
| E006 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - descriptive names |
| E007 | ✓ | ✓ | ✓ | ✓ | ✓ | When 3+ similar tests exist |
| E008 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - static assertions |
| E009 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - no redundant coverage |
| E010 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - method ordering |
| E011 | ✓ | ✓ | ✓ | ✓ | ✓ | When TestDox attribute present |
| E012 | - | ✓ | ✓ | ✓ | - | Only when DAL involved |
| E013 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - class structure order |
| E014 | - | - | - | - | ✓ | Exception tests only |
| E015 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - single class coverage |
| E016 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - no shared state |
| E017 | ✓ | ✓ | ✓ | ✓ | - | Exception tests may use time() |

### Warnings by Category

| Check | A | B | C | D | E | Notes |
|-------|---|---|---|---|---|-------|
| W001 | ✓ | ✓ | ✓ | ✓ | - | Not for exception tests |
| W002 | ✓ | ✓ | ✓ | ✓ | - | Assertion scope (exception tests may need multiple) |
| W003 | - | ✓ | ✓ | - | - | Complex services only |
| W004 | ✓ | ✓ | ✓ | ✓ | ✓ | When data providers used |
| W005 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests |
| W006 | - | ✓ | ✓ | ✓ | - | When SalesChannelContext used |
| W007 | ✓ | ✓ | ✓ | ✓ | ✓ | When data providers used |
| W008 | ✓ | ✓ | ✓ | ✓ | ✓ | When class-level TestDox detected |
| W009 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - fixture patterns |
| W010 | ✓ | ✓ | ✓ | ✓ | - | Not exception-focused tests |
| W011 | ✓ | ✓ | ✓ | ✓ | - | Exception tests have different structure |

## Status Determination

| Condition | Status |
|-----------|--------|
| 0 errors, 0 warnings | PASS |
| 0 errors, 1+ warnings | NEEDS_ATTENTION |
| 1+ errors | ISSUES_FOUND |

## Errors (E###) - Must Fix

| Code | Issue |
|------|-------|
| E001 | Test contains conditional logic (if/else/switch/match/ternary) |
| E002 | Test method tests multiple behaviors |
| E003 | Wrong attribute order (PHPDoc -> DataProviders -> TestDox -> method) |
| E004 | Test method identification (missing `test` prefix OR redundant `#[Test]` attribute) |
| E005 | Tests implementation details, trivial code, or private members via reflection |
| E006 | Ambiguous or non-descriptive test name (includes BDD-style `testIt...`) |
| E007 | Data provider not used for similar test variations (3+ similar tests) |
| E008 | Using `$this->` instead of `static::` for assertions |
| E009 | Test redundancy (unjustified cases or methods covering same path) |
| E010 | Test method ordering doesn't follow pattern (happy path → variations → config → edge → error) |
| E011 | TestDox phrasing doesn't follow guidelines (passive voice, BDD-style, etc.) |
| E012 | Over-mocking (should use StaticEntityRepository or real impl) |
| E013 | Test class structure order incorrect |
| E014 | Exception expectation set after throwing call |
| E015 | Test class covers multiple classes (integration test smell) |
| E016 | Shared mutable state between tests |
| E017 | Non-deterministic inputs without mocking |

## Warnings (W###) - Should Fix

| Code | Issue |
|------|-------|
| W001 | Test name uses implementation-specific terminology |
| W002 | Assertion scope (multiple assertions testing different behaviors) |
| W003 | Missing TestDox attribute for complex test |
| W004 | Data provider key quality (missing OR non-descriptive keys) |
| W005 | Using assertTrue($x === $y) instead of assertEquals |
| W006 | Uses legacy `Generator::createSalesChannelContext()` |
| W007 | Data provider not using `{action}Provider` naming pattern |
| W008 | Class-level TestDox used (prefer method-level only) |
| W009 | Mystery Guest - problematic file dependency |
| W010 | Unbalanced coverage distribution (< 20% edge+error cases) |
| W011 | Unclear AAA structure (assertions interspersed with setup) |

## Informational (I###) - Optional

| Code | Issue |
|------|-------|
| I001 | Test could benefit from data provider consolidation |
| I002 | Test execution time concern (external dependencies) |
| I003 | Consider PHPUnit 11.5 features (#[TestWithJson]) |
| I004 | Consider expectExceptionObject for factory-created exceptions |
| I005 | Consider `#[DisabledFeatures]` for legacy behavior tests |
| I006 | Consider callable-based StaticEntityRepository for criteria validation |
| I007 | Potential preservation value in redundant test (regression/bug documentation) |
| I008 | Consider real fixture files for file I/O testing |

### Informational by Category

| Check | A | B | C | D | E | Notes |
|-------|---|---|---|---|---|-------|
| I001 | ✓ | ✓ | ✓ | ✓ | ✓ | When 2 similar tests exist |
| I002 | - | ✓ | ✓ | ✓ | - | When external deps detected |
| I003 | ✓ | ✓ | ✓ | ✓ | ✓ | For simple data provider cases |
| I004 | - | - | - | - | ✓ | Exception tests with factory methods |
| I005 | ✓ | ✓ | ✓ | ✓ | ✓ | When deprecation comments found |
| I006 | - | ✓ | ✓ | ✓ | - | When complex criteria building |
| I007 | ✓ | ✓ | ✓ | ✓ | ✓ | All tests - preservation value |
| I008 | - | ✓ | ✓ | - | - | When file I/O operations tested |
