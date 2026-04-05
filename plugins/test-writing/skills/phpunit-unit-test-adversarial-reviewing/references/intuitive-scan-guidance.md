# Intuitive Scan Guidance

Heuristic lenses for the independent code scan. Read the test file and its source class, then evaluate through each lens. No rule IDs, no detection algorithms — form impressions from the code itself.

## Lenses

### Absence Detection

What's NOT tested that you'd expect given the source class?

- Read the source class's public methods. Which ones have no corresponding test?
- Are there error paths (exceptions, early returns, null checks) with no coverage?
- Does the source class have edge cases (empty collections, boundary values, null inputs) that the tests don't exercise?
- Are there conditional branches in the source that the tests don't split into separate cases?

### Consequence Weighting

Which test gaps would cause the most damage in production?

- If this test suite passed but the source class had a bug, where would the bug hide?
- Which methods handle money, permissions, data persistence, or user-facing output?
- Are the highest-risk paths tested with the most rigor, or do trivial getters get the same attention as business logic?

### Dependency Fan-Out

Which assumptions do multiple tests rely on?

- Is there a shared setUp() that many tests depend on? What happens if that setup is wrong?
- Do tests assume a specific constructor signature that could change?
- Are mock configurations reused across tests in a way that could mask bugs if the mock is wrong?
- If one test's assumption is invalid, how many other tests would silently pass while being meaningless?

### Pattern Anomalies

Does anything break the pattern established by similar tests?

- Is the assertion style inconsistent within the file (mixing assertTrue/assertEquals/assertSame)?
- Do some test methods follow AAA (Arrange-Act-Assert) while others don't?
- Is the mocking strategy inconsistent (some tests use stubs, others use mocks, without obvious reason)?
- Are data providers used for some parameterized cases but not others?

### The "Surprised?" Test

Calibrated uncertainty check for each test method:

- "If this test passed but the behavior it claims to verify was actually broken, would I be surprised?"
- If no — the test is likely testing the wrong thing, or testing too little
- If yes — the test is likely meaningful
- Tests that verify mock interactions without checking return values often fail this test

### Pre-Mortem Framing

Imagine the test suite passes in CI, but a production incident occurs in this component:

- What went wrong? What did the tests miss?
- Was there an integration boundary the unit tests couldn't catch?
- Was there a state mutation the tests didn't account for?
- This framing is more generative than "what's wrong?" — it forces you to think about failure modes, not just code patterns
