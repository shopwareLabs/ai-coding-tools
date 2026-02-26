---
id: ISOLATION-005
title: Execution Time Concern
group: isolation
enforce: consider
test-types: all
test-categories: B,C,D
scope: general
---

## Execution Time Concern

**Scope**: B,C,D | **Enforce**: Consider

Test may have performance issues due to:
- External service calls
- Large data sets
- Missing mocks for slow operations

**Suggestion**: Consider mocking external dependencies or using smaller test data.
