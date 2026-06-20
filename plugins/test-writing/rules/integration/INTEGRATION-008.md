---
id: INTEGRATION-008
title: Placement smoke check — assertion shape is entirely unit-shape
group: integration
enforce: consider
test-types: integration
test-categories: all
scope: shopware
review-unit: class-bodies
scoped-review: exclude
---

## Placement smoke check — assertion shape is entirely unit-shape

**Scope**: all | **Enforce**: Consider

Cheap one-pass check that emits a hint when an integration test's assertions are all unit-shape, indicating the test may be misplaced. This rule is informational only — it never produces an error or warning, just a pointer to the dedicated migrating skill where the full placement audit lives.

The reviewing skill runs this check exactly once per file and emits the hint at most once. The reasoning rules in `group: placement` are NOT loaded by the reviewing skill; they belong to the migrating skill.

### Detection

1. Enumerate every assertion in the test class.
2. Classify each as **unit-shape** or **integration-shape**:

| Shape | Examples |
|---|---|
| **Unit-shape** | `assertSame`/`assertEquals` on a method return value; `expectException(...)`; `assertCount` on a value object's items; assertions on a constraint violation list (`Symfony\Component\Validator\ConstraintViolationListInterface`); assertions on a constructed DTO/value object; assertions on a mock-recorded call payload |
| **Integration-shape** | Assertions that re-read a persisted entity through DAL (`$repository->search(...)`); row counts via direct SQL; assertions on container service tags, parameters, or compiler-pass output; assertions on HTTP response status/headers/body after `$client->request(...)`; assertions on events received by a real subscriber wired through the dispatcher; assertions that a queued message reached a real broker |

3. If every assertion in the class is unit-shape AND the class uses `IntegrationTestBehaviour` or equivalent, emit the hint below. Otherwise, the check passes silently.

4. Setup-shape is NOT used here — heavy setup paired with unit-shape assertions is `INTEGRATION-007`'s territory. This rule fires on assertions alone.

### Hint output

When the check fires, append to the review report's `Informational` section exactly once:

> **Placement hint** — every assertion in this test is unit-shape. The integration apparatus may not be load-bearing. To audit, invoke `phpunit-integration-to-unit-migrating` on this file. (Not a violation; this skill does not act on placement.)

### Why this rule does not deliberate

The reviewing skill is per-test, runs on every write, and assumes correct placement. The full placement deliberation — articulating the SUT contract, walking container/persistence/kernel intent, evaluating collaborator graphs and refactoring patterns — lives in `group: placement` rules and is loaded only by the `phpunit-integration-to-unit-migrating` skill on explicit user invocation. Mixing both into the reviewer would either (a) silently auto-trigger migration deliberation on every legitimate integration test, or (b) bloat per-test review cost. Neither is acceptable.
