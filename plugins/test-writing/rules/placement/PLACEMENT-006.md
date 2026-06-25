---
id: PLACEMENT-006
title: Setup-vs-assertion symmetry — minimum apparatus from the assertion backward
group: placement
enforce: consider
test-types: integration
test-categories: all
scope: shopware
review-unit: class-bodies
scoped-review: include
---

## Setup-vs-assertion symmetry — minimum apparatus from the assertion backward

**Scope**: all | **Enforce**: Consider (reasoning prompt; loaded only by `phpunit-integration-to-unit-migrating`)

The forward direction (existing setup → existing assertion) makes every apparatus choice look load-bearing because it is already there. Reverse the framing: starting from the assertion, what is the **minimum** apparatus needed to produce its inputs? If `new X(...explicit collaborators...)` plus stubs at boundaries suffices, the integration apparatus was reached for because it was the path of least resistance, not because the test needs it.

### Worked deliberation

For each test method, answer in writing:

1. **Quote the assertion line(s).** Verbatim.
2. **What does the assertion observe?** A return value, an exception, a persisted row, an HTTP response, a queued message, a recorded event.
3. **What minimum apparatus produces that observable?**
   - Return value → `new SUT(...)` + invoke
   - Exception → `new SUT(...)` + invoke + `expectException`
   - Constraint violation list → `Validator` + `new SUT(...)` + invoke
   - Persisted row → DAL or raw SQL — needs integration
   - HTTP response → kernel + client — needs integration
   - Queued message reaching broker → messenger + broker — needs integration
4. **Compare**: is the current apparatus the minimum, or is the minimum strictly smaller?

### Verdict

- Minimum apparatus is strictly smaller than the current apparatus → the current apparatus is ceremony. Migrate.
- Minimum apparatus is the current apparatus → keep.

### Anti-pattern: "I'll use the container because it's already there"

The setup-forward mindset:
> "I already need a kernel for the test runner, so I might as well fetch the service from the container."

is wrong. The kernel boot is **per test class**, not free per test. Reverse the question: would you start a kernel for this test if the suite didn't have one running? If the answer is "no, I'd just `new` the service," the test belongs in `tests/unit/`.
