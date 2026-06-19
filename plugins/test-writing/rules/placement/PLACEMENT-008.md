---
id: PLACEMENT-008
title: Stay-in-integration indicators — what must not be migrated
group: placement
enforce: consider
test-types: integration
test-categories: all
scope: shopware
review-unit: class-bodies
---

## Stay-in-integration indicators — what must not be migrated

**Scope**: all | **Enforce**: Consider (reasoning prompt; loaded only by `phpunit-integration-to-unit-migrating`)

The reasoning rules (PLACEMENT-001..007) catch misplaced tests by interrogating apparatus and assertions. This rule catches the inverse: tests that *look* migratable on a quick scan but assert something only the integration apparatus can produce. Treat these indicators as veto conditions on a migration decision.

### Veto indicators

If any of the following holds, the test stays in integration regardless of other signals:

1. **Persistence behavior under test.** The assertion is "the write happened" or "the read returns the written data" or "the indexer ran" or "the version was created." DAL is the SUT, not a materializer.

2. **Container wiring under test.** The assertion verifies service tags, compiler-pass output, autowired collaborator identity, scoped service correctness, or DI parameter resolution.

3. **HTTP / controller layer.** The test issues `$client->request(...)` and asserts on the response. Routing + controller dispatch is integration.

4. **Multi-service flow as the SUT.** The assertion only emerges from real interaction of ≥ 2 stateful collaborators (DAL + indexer + event bus + cache). PLACEMENT-005 identifies these — if the R-count is ≥ 2 and the interaction is the subject, do not migrate.

5. **Migration / seed-data dependency.** The test depends on schema state, baseline rows, or seed fixtures that live in MySQL. Cannot run without the database.

6. **Real broker / queue / external SDK exercised end-to-end.** The assertion includes "the message reached RabbitMQ" or "the SDK called the real API."

7. **Compiler pass under test.** The test instantiates a real `ContainerBuilder`, applies the compiler pass, and asserts the resulting definition graph. (Note: this case usually moves to `tests/unit/` with explicit `ContainerBuilder` construction — see PR #16742's `TwigEnvironmentCompilerPassTest`. The veto applies only if the test uses the booted kernel's container.)

### Worked deliberation

For each test method:

1. Walk through indicators 1–7.
2. If any applies, write the indicator down and stop the migration audit for that method.
3. If none applies, the PLACEMENT-001..007 verdicts decide.

### Note on partial migrations

A test class can contain a mix of migratable and non-migratable methods. The migration audit operates per-method, not per-class. When some methods migrate and others stay, the integration class shrinks; the moved methods land in `tests/unit/`. See PR #16704 and #16754 for examples of partial-class migrations.
