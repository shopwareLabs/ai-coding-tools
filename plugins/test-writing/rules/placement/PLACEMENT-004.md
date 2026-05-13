---
id: PLACEMENT-004
title: Assertion shape catalog
group: placement
enforce: consider
test-types: integration
test-categories: all
scope: shopware
---

## Assertion shape catalog

**Scope**: all | **Enforce**: Consider (reasoning prompt; loaded only by `phpunit-integration-to-unit-migrating`)

Catalog every assertion in the test and classify each. The shape distribution determines whether the test's *output contract* (what it claims) lives inside the integration suite or outside.

### Unit-shape assertions

The assertion targets a value the SUT can produce in isolation:

- `assertSame` / `assertEquals` on a method return value or a constructed value object
- `expectException(...)`, `expectExceptionMessage(...)`, `expectExceptionObject(...)`
- `assertCount` on a value object's items
- Assertions on a `Symfony\Component\Validator\ConstraintViolationListInterface`
- Assertions on a constructed DTO or entity (without re-reading through DAL)
- Assertions on a mock-recorded call payload (when the mock is at a boundary)
- Assertions on a serializer's output string / array

### Integration-shape assertions

The assertion targets state or behavior that only exists because of the apparatus:

- Re-reading a persisted entity through DAL and asserting a field that was written earlier
- Direct SQL row counts or column values
- Container service tags, parameters, or compiler-pass output
- `$client->getResponse()->getStatusCode()` after `$client->request(...)`
- Events received by a real subscriber wired through the dispatcher (not a stub subscriber)
- A queued message reaching a real broker
- Assertions on transactional consistency across multiple writes
- Assertions on indexer or version effects on persisted state

### Worked deliberation

1. Enumerate every assertion.
2. Classify each.
3. Tally the totals.

### Verdict

| Unit-shape | Integration-shape | Verdict |
|---|---|---|
| 100% | 0% | Test output contract is unit-shape. Combined with PLACEMENT-001..003 verdicts: if apparatus is also incidental, migrate. |
| Majority unit, some integration | | Test is mixed. Consider splitting: the integration-shape assertions stay in integration; the unit-shape ones move to a new unit test. |
| Majority integration | | Test stays in integration. Stop the audit. |

### Note on mocks

If the test uses `createMock(`/`createStub(` on a non-boundary collaborator, the mock-recorded call assertions are themselves a sign of misplacement: real integration tests don't mock their own collaborators. Flag and cross-reference `INTEGRATION-002`.
