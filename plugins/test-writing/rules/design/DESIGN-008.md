---
id: DESIGN-008
title: Preservation Value in Redundant Test
group: design
enforce: consider
test-types: all
test-categories: A,B,C,D,E
scope: general
---

## Preservation Value in Redundant Test

**Scope**: A,B,C,D,E | **Enforce**: Consider

When DESIGN-004 (redundancy) detection finds a potentially redundant test, check for preservation value indicators before flagging.

### Purpose

Some redundant tests have historical value that justifies their existence:
- Regression tests for specific bug fixes
- Documentation of edge cases discovered in production
- Compliance or audit requirements

### Preservation Indicators

| Indicator Type | Pattern | Example |
|----------------|---------|---------|
| Regression marker in name | `Regression`, `Bug`, `Issue`, `#\d+` | `testRegressionBug4521` |
| Issue tracker reference | `JIRA-`, `SW-`, `GH-` | `testJIRA1234UserCreation` |
| Comment with bug reference | `// regression`, `// bug fix`, `// prevents #` | `// Regression test for SW-12345` |
| Data provider key with bug ref | `bug`, `regression`, `issue #` | `'unicode fix (bug #1234)'` |

### When to Preserve vs Remove

| Scenario | Action |
|----------|--------|
| Redundant test with no indicators | Flag DESIGN-004 -- remove/consolidate |
| Redundant test with preservation indicator | Report DESIGN-008 -- keep, suggest documentation |
| Redundant test with explicit comment explaining value | Keep as-is -- no action |

### Example

```php
// DESIGN-004: Redundant - same code path, no preservation indicator
public function testCreatesUserWithValidData(): void { ... }

// DESIGN-008: Preservation value - regression indicator in name
public function testRegressionBug4521EmptyNameHandling(): void { ... }

// KEEP: Explicit documentation comment
/**
 * Regression test for SW-12345: Unicode names were truncated
 * in version 6.4.0 due to UTF-8 encoding bug.
 */
public function testCreatesUserWithUnicodeName(): void { ... }
```

### Recommendation Format

```
DESIGN-008: testRegressionBug4521UserCreation appears to cover the same code path
as testCreatesUser. If this test documents a specific bug fix, consider
adding a comment with the issue reference. Otherwise, consider consolidating.
```
