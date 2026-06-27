---
id: DESIGN-007
title: Data Provider Consolidation Opportunity
group: design
enforce: consider
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
review-unit: class-bodies
scoped-review: include
---

## Data Provider Consolidation Opportunity

**Scope**: A,B,C,D,E | **Enforce**: Consider

Test could benefit from consolidating similar variations into a data provider.

**When to mention**: 2 tests are near-identical variations — same call and assertion shape, differing only in input/expected values that a `#[DataProvider]` would collapse — not merely structurally similar. Confirm the shared shape against the test bodies before mentioning; do not raise it from surface similarity alone. 3+ such variations triggers DESIGN-003 (must-fix).
