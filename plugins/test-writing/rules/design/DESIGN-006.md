---
id: DESIGN-006
title: Unbalanced Coverage Distribution
group: design
enforce: should-fix
test-types: all
test-categories: A,B,C,D
scope: general
---

## Unbalanced Coverage Distribution

**Scope**: A,B,C,D | **Enforce**: Should fix

Flag when combined edge+error cases < 20% of total tests.

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
