---
id: DESIGN-006
title: Unbalanced Coverage Distribution
group: design
enforce: should-fix
test-types: all
test-categories: A,B,C,D
scope: general
review-unit: class-bodies
scoped-review: exclude
---

## Unbalanced Coverage Distribution

**Scope**: A,B,C,D | **Enforce**: Should fix

Flag when combined edge+error cases < 20% of total tests, and only where the source has conditional logic to cover.

The ratio is computed across the whole class, so evaluate this rule over every test body together, never over one method.

### Classification

| Category | Indicators |
|----------|------------|
| **Error case** | `expectException()`, or name contains: Throws, Fails, Invalid, Error, Exception, Rejects |
| **Edge case** | Name contains: Empty, Null, Zero, Boundary, Max, Min, Negative, Overflow |
| **Happy path** | Default (no indicators above) |

### Detection

```php
// DESIGN-006: 10% edge + 10% error = 20% (at threshold)
class ProductServiceTest extends TestCase
{
    // Happy path (8 tests - 80%)
    public function testCreatesProduct(): void {}
    public function testUpdatesProduct(): void {}
    // ... 6 more happy path tests

    // Edge case (1 test - 10%)
    public function testHandlesEmptyName(): void {}

    // Error case (1 test - 10%)
    public function testThrowsForInvalidId(): void {}
}
```

### Fix

Add edge and error cases to reach > 20% combined coverage.

### Discriminator Requirement

Each added edge or error case names the production code — a guard clause, a validation branch, a thrown exception — whose removal would make the new assertion fail.

A case whose assertions are unaffected by deleting the logic it claims to cover does not count toward the threshold. Padding the ratio with cases that discriminate nothing satisfies the arithmetic and not the rule.

### When This Rule Does NOT Apply

The rule does not apply where the source has no remaining conditional branch, guard clause, or thrown exception. Report it as **not applicable**, never as satisfied by a case with no discriminator.
