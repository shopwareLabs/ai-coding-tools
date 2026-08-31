# Test Writing

Generate and validate PHPUnit unit tests for Shopware 6. Automatically analyzes source classes, generates category-appropriate tests, reviews for compliance, and fixes issues until tests pass.

## 🧩 Features

- **Automated Test Generation**: Analyzes source class structure to generate category-appropriate unit tests
- **Review & Fix Loop**: Up to 4 fix iterations with automatic fix application run inline by the orchestrator
- **5 Test Categories**: DTO (A), Service (B), Flow/Event (C), DAL (D), Exception (E)
- **MCP-Driven Test Rules**: Comprehensive validation via MCP-driven rule discovery (must-fix, should-fix, consider — auto-discovered from `rules/` directory)
- **FIRST Principles**: Detects shared state (Independent) and non-deterministic inputs (Repeatable)
- **Test Smell Detection**: Identifies Mystery Guest, unclear AAA structure, unbalanced coverage
- **Oscillation Detection**: Prevents infinite fix loops by detecting recurring issues
- **PHPStan/PHPUnit Validation**: Automatically validates generated tests with MCP tools
- **Coverage Exclusion Offer**: When a file is too trivial to test, offers to add it to `phpunit.xml.dist` exclusions to keep coverage reports clean
- **Shopware Stubs**: Uses StaticEntityRepository, StaticSystemConfigService, Generator
- **MCP Rule Server**: Dynamic rule discovery with `mcp__plugin_test-writing_test-rules__get_rules` for context-efficient reviews
- **Team-Based Consensus Review**: The single Workflow-based reviewer for unit, integration, and migration tests over one mixed manifest — `test_type` (resolved by path) routes each file to its rule catalog, per-type reviewing sub-skill, decomposition track, and adversary lenses. 3 independent reviewers per unit and K independent per-file adversaries (one per lens — tautology / weak-assertion / missed-coverage — each reading a single file). Oversized test classes are decomposed by rule track — method-shards plus a whole-class or body-free structural-digest track — so large files no longer overflow the context window, and large changesets are partitioned into review shards that run as a **campaign of sequential workflow launches** with every stage result persisted to disk, so an interrupted campaign resumes from where it stopped. Stages: independent review + peer reconciliation per shard (consensus), a whole-changeset signals run (cross-file consistency, adoption), and a cost-gated adversarial run (red team, defense, hard-capped arbitration). Deterministic cross-cutting SUT-coverage map and informational integration-to-unit placement flags computed at merge. Findings carry a method-primary locator, a per-finding branch-scope flag (`branch_touched`) on diff runs, and a source-change escalation when a fix cannot be made in the test alone. 2-of-3 majority consensus per track. Strictly read-only (see [Team Review](#team-review) below)
- **Migration Test Generation**: Analyzes migration source classes (SQL operations, updateDestructive logic) to generate pattern-appropriate migration tests
- **Migration Test Reviewing**: 9 migration-specific rules covering idempotency, cleanup, assertion patterns, and Shopware conventions
- **Integration Test Generation**: Analyzes source classes to detect supported integration patterns (controller/route, message-handler, indexer, DAL-flow, multi-service) and generates `IntegrationTestBehaviour`-based tests. Defers to unit test generation when the SUT is unit-shape
- **Integration Test Reviewing**: 8 integration-specific rules covering integration-base usage, real-collaborator policy, transactional cleanup, determinism, independence, and a placement smoke check
- **Integration-to-Unit Migration**: User-invoked audit workflow that walks 8 placement-reasoning rules per test, buckets into migrate/split/keep/delete, and applies one of 6 codified refactoring patterns. Separate skill, never auto-invoked

## ⚡ Quick Start

### Installation

```bash
/plugin install test-writing@shopware-ai-coding-tools
```

> [!IMPORTANT]
> - `dev-tooling` plugin must be installed (MCP server reference is bundled)
> - `.mcp-php-tooling.json` configuration file in your project root (see Configuration below)
> - Restart Claude Code after installation

### Basic Usage

Generate unit tests using natural language:

```
Generate unit tests for src/Core/Content/Product/ProductEntity.php
Write tests for src/Core/Checkout/Cart/CartService.php
```

The `phpunit-unit-test-writing` skill will be automatically invoked.

### Team Review

Run a consensus-based review with multiple independent reviewers. The team reviewer is the single Workflow-based reviewer for **unit, integration, and migration** tests — it reviews a mixed selection in one run, routing each file by its test type (`tests/unit/`, `tests/integration/`, `tests/migration/`):

```
Review tests in tests/unit/Core/Content/ with a team
Team review the integration tests changed in this PR
Team review the tests changed in this PR
```

Accepts file paths, directories, commits, branches, and PRs as input — a single PR touching all three test families becomes one campaign. The review is strictly read-only; it never mutates the tests. Beyond per-file findings it produces a cross-cutting **SUT-coverage map** (the same source class covered by more than one test file — across or within test types) and informational **integration-to-unit placement flags** that point at the standalone `phpunit-integration-to-unit-migrating` skill — it never migrates files itself.

> [!WARNING]
> Team review runs multi-agent Claude Code Workflows. It spawns substantially more agents than a single-reviewer pass — 3 reviewers per review unit (a small file, or each method-shard and whole-class set of a decomposed large file), up to 3 adversaries per file (one per active lens, in both the impression and red-team waves; fewer on the `lean` preset), and a cross-file consistency agent — and consumes significantly more tokens. Large changesets run as several sequential review shards (each sized to finish within one usage-limit window) with results persisted between launches, and the opus-priced adversarial stage (red team + arbitration) only runs after an explicit cost-informed confirmation. A run-time **preset** (`deep` / `standard` / `lean`) and **model combo** (`sonnet-opus` / `haiku-opus` / `haiku-sonnet`) trade thoroughness against cost. The skill asks for confirmation before starting and offers the standard single-reviewer pass as an alternative.

### Scoped Review

When reviewing tests from a branch or PR, only violations in changed/added methods are flagged:

```
Review the tests changed in PR #1243
Team review the tests added in this branch
```

The reviewing system automatically resolves which methods were changed from the diff and scopes the review to those methods. Pre-existing issues in untouched methods are ignored.

For explicit method-level review without a diff context, specify methods directly:

```
Review testHandlesEmptyCart in tests/unit/Core/Checkout/Cart/CartServiceTest.php
```

## 🔬 Test Categories

Tests are categorized based on source class structure:

| Category | Name       | Description                            | Key Traits                            |
|----------|------------|----------------------------------------|---------------------------------------|
| A        | Simple DTO | Value objects, entities, collections   | No dependencies, direct instantiation |
| B        | Service    | Services with constructor dependencies | Business logic, dependency injection  |
| C        | Flow/Event | Event subscribers, flow actions        | Event dispatch, context passing       |
| D        | DAL        | Repository operations                  | Uses StaticEntityRepository, Criteria |
| E        | Exception  | Exception classes and handling         | Error messages, factory methods       |

### Category Detection

```
Has constructor dependencies?
├── No → Is it an Exception class?
│   ├── Yes → Category E
│   └── No → Category A (DTO)
└── Yes → Uses EntityRepository?
    ├── Yes → Category D (DAL)
    └── No → Implements EventSubscriberInterface or FlowAction?
        ├── Yes → Category C (Flow/Event)
        └── No → Category B (Service)
```

## 🔬 Migration Tests

Migration tests validate database migrations by running them against a real database. Unlike unit tests, migration tests have no category system — a single rule set applies universally.

### Generation

Generate migration tests using natural language:

```
Generate migration tests for src/Core/Migration/V6_7/Migration1234Foo.php
Write a migration test for this migration
```

The generator analyzes the migration's SQL operations and selects appropriate test patterns:

| Pattern       | Detection                                | Test Structure                                        |
|---------------|------------------------------------------|-------------------------------------------------------|
| Schema-Add    | `CREATE TABLE`, `addColumn()`            | rollback → migrate twice → assert exists              |
| Schema-Remove | `DROP TABLE/COLUMN` in updateDestructive | ensure exists → updateDestructive twice → assert gone |
| Data-Update   | `UPDATE`, `INSERT`, `DELETE`             | set up state → migrate twice → assert values          |
| Config        | `system_config` operations               | delete/set config → migrate twice → assert value      |
| Mail Template | `mail_template` operations               | migrate twice → assert no exception                   |

### Review Rules

| Rule ID       | Issue                                                                                          |
|---------------|------------------------------------------------------------------------------------------------|
| MIGRATION-001 | update() not called at least twice (idempotency)                                               |
| MIGRATION-002 | updateDestructive() not called at least twice when source has logic                            |
| MIGRATION-003 | Test reuses migration helper methods for verification                                          |
| MIGRATION-004 | Test-created tables/data not cleaned up                                                        |
| MIGRATION-005 | Multiple SQL in single try/catch, or catching Exception instead of Throwable                   |
| MIGRATION-006 | String interpolation for table/column names in SQL                                             |
| MIGRATION-007 | assertEquals used instead of assertSame                                                        |
| MIGRATION-008 | Missing testGetCreationTimestamp method                                                        |
| MIGRATION-009 | setUp/tearDown mutates DB state                                                                |

All migration rules are **must-fix** and enforced on new tests.

## 🔬 Integration Tests

Integration tests live in `tests/integration/` and exercise wired-up code: real DAL, real container, real event dispatcher. This plugin supports them through three complementary skills.

### Generation

`phpunit-integration-test-generation` analyzes a source class and generates a Shopware-compliant integration test when the SUT's contract requires wired-up code. It is conservative: classes that fit a unit-shape pattern (factory, compiler pass, single subscriber, parser, constraint-only rule, DAL materializer) are skipped with a pointer to `phpunit-unit-test-generation` rather than producing a placement-violating test.

Trigger phrases:

```
Generate integration tests for src/Core/Content/Product/DataAbstractionLayer/ProductIndexer.php
Write an integration test for this controller
Create an integration test for this message handler
```

Detected patterns:

| Pattern         | When applied                                                                                                  |
|-----------------|---------------------------------------------------------------------------------------------------------------|
| controller      | Extends `AbstractController` or `Abstract*Route`, or has `#[Route]` methods                                   |
| scheduled-task  | Extends `ScheduledTaskHandler`, or `#[AsMessageHandler]` with a `ScheduledTask` parameter                     |
| message-handler | `#[AsMessageHandler]` on `__invoke()` with a non-`ScheduledTask` domain message parameter                     |
| indexer         | Extends `EntityIndexer`                                                                                       |
| dal-flow        | Constructor takes `EntityRepository` AND SUT writes are observed back via DAL                                 |
| multi-service   | ≥ 3 dependencies with ≥ 2 stateful collaborators (DAL, indexer, event bus, system config)                     |

Patterns map to trait choices calibrated against recent Shopware tests: `controller`, `message-handler`, `dal-flow`, and `multi-service` use `IntegrationTestBehaviour`; `scheduled-task` and `indexer` use the lighter `DatabaseTransactionBehaviour + KernelTestBehaviour` pair. Generated tests retrieve the SUT and primary collaborators from the container (no SUT mocking), use `IdsCollection` for ID management, and produce integration-shape assertions (persistence read-back, event observation, HTTP response, indexer message contents) per INTEGRATION-001..008.

### Reviewing

`phpunit-integration-test-reviewing` validates integration tests against 8 integration-specific rules. It assumes the test belongs in the integration suite and checks quality within that frame. The Reviewer agent invokes it the same way it invokes the unit-test reviewer.

When all assertions in a test are unit-shape, the reviewer emits a single informational hint pointing at the migrating skill. The hint never appears as an error and the reviewer never deliberates on placement inline.

```
Review tests/integration/Core/Framework/App/Cms/CmsExtensionsTest.php
```

### Migrating to Unit

`phpunit-integration-to-unit-migrating` is a separate, user-invoked skill. It walks 8 placement-reasoning rules per test (container intent, persistence intent, kernel intent, assertion shape, collaborator graph, setup-vs-assertion symmetry, name-vs-body coherence, stay-in-integration veto), then buckets each test into migrate, split, keep, or delete-as-duplicate, asks for confirmation, and applies one of 6 codified refactoring patterns.

```
Audit integration tests in tests/integration/Core/Framework/App/Cms/
Migrate this integration test to unit if it doesn't need the kernel
Should DateFieldSerializerTest be a unit test instead?
```

Refactoring patterns supported:

| Pattern                              | When to apply                                                                         |
|--------------------------------------|---------------------------------------------------------------------------------------|
| Container-fetched factory or service | SUT is constructable; container is a service locator                                  |
| CompilerPass under test              | Pass operates on definitions; build a real `ContainerBuilder`, assert on `Definition` |
| Event subscriber                     | Invoke handler directly; skip the real dispatcher                                     |
| XML / JSON parser                    | Move fixtures under `tests/unit/.../_fixtures/Resources/`, use `__DIR__` paths        |
| Constraint-only rule validation      | Use `Validation::createValidatorBuilder()`, assert on `ConstraintViolationList`       |
| DAL materializer                     | Construct entities in-memory with setters                                             |

The skill never auto-triggers from the reviewer — placement decisions require explicit user intent.

## 🔄 Workflow

### Phase 1: Test Generation

1. Validates source file (exists, is PHP class, in `src/`)
2. Analyzes class structure to determine category
3. Applies category-specific template
4. Generates test file in `tests/unit/`
5. Validates with PHPStan and PHPUnit

### Phase 2: Coverage Exclusion Offer

When a source file is SKIPPED because it has no testable logic (trivial DTO, pure accessor, etc.):

1. Offers to add the file to `phpunit.xml.dist` `<exclude>` section
2. Keeps coverage reports clean by excluding files that don't need tests
3. In multi-file mode, batches all trivial files into a single prompt

### Phase 3: Review

1. Loads applicable rules via `mcp__plugin_test-writing_test-rules__get_rules(group={group}, test_type=unit, test_category={detected})` per rule group
2. Applies detection algorithms from loaded rules
3. Returns structured report with errors (must-fix) and warnings (should-fix)

### Phase 4: Fix Loop (max 4 iterations)

If review finds errors, the orchestrator runs an inline fix loop:

1. Applies fixes from review report errors (Edit tool)
2. Re-validates with ECS, PHPStan, PHPUnit (MCP tools)
3. Re-invokes reviewing skill to check for remaining issues
4. Tracks issue history for oscillation detection
5. Exits on PASS, oscillation, stuck loop, or max iterations

### Phase 5: User Decision

1. If oscillation detected: presents details, asks user to continue or abort
2. If warnings remain: presents warnings, asks for approval to apply fixes
3. Applies fixes if approved

### Phase 6: Final Report

1. Provides comprehensive summary
2. Lists test file, category, iterations used, applied fixes
3. Reports final status

## 📏 Test Rules

Rules are organized by group and enforce level.

### Must-Fix Rules

| Rule ID       | Issue                                                                                                                 |
|---------------|-----------------------------------------------------------------------------------------------------------------------|
| DESIGN-001    | Test contains conditional logic (if/else/switch/match/ternary)                                                        |
| DESIGN-002    | Test method tests multiple behaviors                                                                                  |
| CONV-001      | Wrong attribute order (PHPDoc → DataProvider → TestDox)                                                               |
| CONV-002      | Test method identification (missing `test` prefix OR redundant `#[Test]`)                                             |
| UNIT-001      | Tests implementation details, trivial code, or private members                                                        |
| CONV-003      | Ambiguous or non-descriptive test name (includes BDD-style `testIt...`)                                               |
| DESIGN-003    | Data provider not used for similar test variations (3+ similar tests)                                                 |
| CONV-004      | Using `static::` instead of `$this->` for `expect*()` setup methods                                                   |
| DESIGN-004    | Test redundancy (unjustified cases or methods covering same path)                                                     |
| CONV-015      | Missing `#[Package(...)]` attribute on test class (routes a failing CI job to the owning domain team)                 |
| CONV-006      | TestDox phrasing doesn't follow guidelines                                                                            |
| UNIT-003      | Over-mocking (should use StaticEntityRepository or real impl)                                                         |
| CONV-007      | Test class structure order incorrect                                                                                  |
| CONV-008      | Exception expectation set after throwing call                                                                         |
| UNIT-002      | Test class covers multiple classes (integration test smell)                                                           |
| ISOLATION-001 | Shared mutable state between tests (FIRST: Independent)                                                               |
| ISOLATION-002 | Non-deterministic inputs without mocking (FIRST: Repeatable)                                                          |
| CONV-009      | Weak exception assertion (type-only `expectException()` without message, code, or object)                             |
| UNIT-004      | Call-count over-coupling (`expects(once())` on collaborators whose result is already asserted)                        |
| UNIT-009      | Dedicated test for abstract class (test concrete implementations instead)                                             |
| UNIT-007      | Deprecated API exercised without `#[DisabledFeatures]`, or with broken `skipTestIfActive`/`skipTestIfInActive` guards |
| UNIT-010      | `@` error suppression operator used on deprecated code (ineffective in Shopware test infra)                           |

### Should-Fix Rules

| Rule ID       | Issue                                                                                                          |
|---------------|----------------------------------------------------------------------------------------------------------------|
| CONV-010      | Test name uses implementation-specific terminology                                                             |
| DESIGN-005    | Assertion scope (multiple assertions testing different behaviors)                                              |
| CONV-011      | Missing TestDox attribute for complex test                                                                     |
| PROVIDER-001  | Data provider key quality (missing OR non-descriptive keys)                                                    |
| CONV-012      | Using assertTrue($x === $y) instead of assertSame                                                              |
| PROVIDER-002  | Data provider not using `{action}Provider` naming pattern                                                      |
| CONV-013      | Class-level TestDox used (prefer method-level only)                                                            |
| ISOLATION-003 | Mystery Guest - problematic file dependency                                                                    |
| DESIGN-006    | Unbalanced coverage distribution (< 20% edge+error cases)                                                      |
| CONV-014      | Unclear AAA structure (assertions interspersed with setup)                                                     |
| ISOLATION-004 | Opaque test data identifiers (UUID hex strings instead of descriptive strings like `'product-id'`)             |
| CONV-005      | Test method ordering doesn't follow pattern                                                                    |
| PROVIDER-003  | Data provider uses `return []` instead of `yield`/`iterable`                                                   |
| CONV-017      | Single-use test property (assigned in `setUp()`, used in only one test method — inline it)                     |
| CONV-016      | `Test` prefix on non-test helper class (reserve `Test` for classes extending `TestCase`; use `Stub*`, `Fake*`) |
| PROVIDER-004  | Description-only data provider parameter (used only for TestDox interpolation; use `$_dataName` instead)       |
| DESIGN-010    | Guard clause isolation in arrange (test may pass by exiting at a different guard than intended)                |

### Consider Rules

| Rule ID       | Issue                                                                                                                  |
|---------------|------------------------------------------------------------------------------------------------------------------------|
| DESIGN-007    | Test could benefit from data provider consolidation                                                                    |
| ISOLATION-005 | Test execution time concern (external dependencies)                                                                    |
| PROVIDER-005  | Consider PHPUnit 11.5 features (#[TestWithJson])                                                                       |
| UNIT-008      | Consider callable-based StaticEntityRepository for criteria validation                                                 |
| DESIGN-008    | Potential preservation value in redundant test (regression/bug documentation)                                          |
| ISOLATION-006 | Consider real fixture files for file I/O testing                                                                       |
| DESIGN-009    | Duplicated inline Arrange code (identical construction in multiple test methods; extract to setUp() or private helper) |

### Migration Rules (Must-Fix)

| Rule ID       | Issue                                                                                          |
|---------------|------------------------------------------------------------------------------------------------|
| MIGRATION-001 | update() not called at least twice (idempotency)                                               |
| MIGRATION-002 | updateDestructive() not called at least twice when source has logic                            |
| MIGRATION-003 | Test reuses migration helper methods for verification                                          |
| MIGRATION-004 | Test-created tables/data not cleaned up                                                        |
| MIGRATION-005 | Multiple SQL in single try/catch, or catching Exception instead of Throwable                   |
| MIGRATION-006 | String interpolation for table/column names in SQL                                             |
| MIGRATION-007 | assertEquals used instead of assertSame                                                        |
| MIGRATION-008 | Missing testGetCreationTimestamp method                                                        |
| MIGRATION-009 | setUp/tearDown mutates DB state                                                                |

### Integration Rules

Applied by `phpunit-integration-test-reviewing` against tests in `tests/integration/`. Assume correct placement; do not deliberate on whether the test should be a unit test.

| Rule ID         | Enforce     | Issue                                                                                                |
|-----------------|-------------|------------------------------------------------------------------------------------------------------|
| INTEGRATION-001 | must-fix    | Integration test must use Shopware integration base (`IntegrationTestBehaviour` or equivalent)       |
| INTEGRATION-002 | must-fix    | No mocking of the system under test or its primary collaborators (boundary mocks OK)                 |
| INTEGRATION-003 | must-fix    | Non-transactional writes (DDL, raw SQL, filesystem, cache) must be cleaned up                        |
| INTEGRATION-004 | should-fix  | Deterministic time, randomness, and identifiers — inject clock or use fixed seeds                    |
| INTEGRATION-005 | must-fix    | No `#[Depends]` between integration test methods                                                     |
| INTEGRATION-006 | should-fix  | Do not skip tests for missing fixtures — create the fixture instead                                  |
| INTEGRATION-007 | should-fix  | Setup-to-assertion ratio must be balanced (heavy setup + unit-shape assertion is a smell)            |
| INTEGRATION-008 | consider    | Placement smoke check — emits an informational hint when all assertions are unit-shape               |

### Placement Rules (Reasoning Prompts)

Loaded ONLY by `phpunit-integration-to-unit-migrating`. These are deliberation prompts, not check rules — they require the reviewer to articulate the SUT contract and walk through structured questions before reaching a verdict.

| Rule ID       | Prompt                                                                               |
|---------------|--------------------------------------------------------------------------------------|
| PLACEMENT-001 | Container intent — service locator or system under test?                             |
| PLACEMENT-002 | Persistence intent — DAL behavior or convenient materializer?                        |
| PLACEMENT-003 | Kernel intent — kernel state under test or paying for getContainer()?                |
| PLACEMENT-004 | Assertion shape catalog (unit-shape vs integration-shape)                            |
| PLACEMENT-005 | Collaborator graph — how many real collaborators does the assertion traverse?        |
| PLACEMENT-006 | Setup-vs-assertion symmetry — minimum apparatus from the assertion backward          |
| PLACEMENT-007 | Name-vs-body coherence — does the body assert what the name claims?                  |
| PLACEMENT-008 | Stay-in-integration veto indicators (persistence, wiring, HTTP, multi-service, etc.) |

## 📋 Output Contracts

### Generator Output

```yaml
source: src/Path/To/Class.php
test_path: tests/unit/Path/To/ClassTest.php
status: SUCCESS|PARTIAL|SKIPPED|FAILED
category: A|B|C|D|E
reason: null       # explanation if not SUCCESS
skip_type: null    # "coverage_excluded" | "no_logic" (only when SKIPPED)
```

### Reviewer Output (Read-Only)

```yaml
test_path: tests/unit/Path/To/ClassTest.php
status: PASS|NEEDS_ATTENTION|ISSUES_FOUND|FAILED
category: A|B|C|D|E
errors:
  - rule_id: {rule_id}       # from mcp__plugin_test-writing_test-rules__get_rules response
    title: {title}            # from mcp__plugin_test-writing_test-rules__get_rules response
    enforce: must-fix
    location: ClassTest.php:45
    current: |
      # problematic code
    suggested: |
      # fixed code
warnings: []
reason: null  # explanation if FAILED
```

### Migration Generator Output

```yaml
source: src/Core/Migration/V6_7/Migration1234Foo.php
test_path: tests/migration/Core/V6_7/Migration1234FooTest.php
status: SUCCESS|PARTIAL|FAILED
reason: null
```

### Migration Reviewer Output

```yaml
test_path: tests/migration/Path/To/MigrationTest.php
status: PASS|ISSUES_FOUND|FAILED
errors:
  - rule_id: MIGRATION-001
    title: "Idempotency — update() called at least twice"
    enforce: must-fix
    location: MigrationTest.php:35
    current: |
      # problematic code
    suggested: |
      # fixed code
warnings: []
reason: null
```

### Integration Reviewer Output

```yaml
test_path: tests/integration/Path/To/SomeTest.php
status: PASS|NEEDS_ATTENTION|ISSUES_FOUND|FAILED
errors: []                # from INTEGRATION-001..006 must-fix rules
warnings: []              # from INTEGRATION-004, 006, 007 should-fix rules
informational:            # from INTEGRATION-008 smoke check (never raises status)
  - rule_id: INTEGRATION-008
    title: "Placement smoke check"
    hint: "Every assertion is unit-shape. Consider invoking phpunit-integration-to-unit-migrating on this file."
reason: null
```

### Integration→Unit Migration Audit Output

```yaml
scope:
  type: file | directory | pr | branch
  resolved_files: [tests/integration/...]
audit:
  - file: tests/integration/Path/To/SomeTest.php
    sut_contract: "The SUT serializes date values via encode/decode."
    contract_shape: unit | integration | mixed
    placement_verdicts:
      PLACEMENT-001: service_locator | sut | n/a
      PLACEMENT-002: materializer | dal_behavior | n/a
      PLACEMENT-003: kernel_under_test | container_only | n/a
      PLACEMENT-004: all_unit | mixed | majority_integration
      PLACEMENT-005: r_count_0 | r_count_1 | r_count_2_plus
      PLACEMENT-006: minimum_smaller | minimum_equal
      PLACEMENT-007: name_body_coherent | name_misleading
      PLACEMENT-008: veto_persistence | veto_wiring | veto_http | veto_multi_service | veto_migration | veto_broker | veto_compiler_pass | no_veto
    bucket: migrate | split | keep | delete
    veto_reason: null  # filled when PLACEMENT-008 vetoes
execution:
  files_created: [tests/unit/...]
  files_modified: [tests/integration/...]
  files_deleted: [tests/integration/...]
  methods_moved: 12
status: AUDITED | MIGRATED | DECLINED | FAILED
```

## 🎛️ Configuration

### Required Plugin

The `dev-tooling` plugin must be installed (this plugin bundles an MCP server reference to it):

```bash
/plugin install dev-tooling@shopware-ai-coding-tools
```

### Project Configuration

Create `.mcp-php-tooling.json` in your project root. See the [dev-tooling documentation](../dev-tooling/README.md) for configuration options and examples.

The MCP server supports custom config paths via `--config` argument in the bundled `.mcp.json`.

### Bundled MCP Servers

This plugin bundles a `test-rules` MCP server that serves test writing rules. The server starts automatically when the plugin is installed.

**Tools:**
- `mcp__plugin_test-writing_test-rules__get_rules` — Get full rule content by ID or metadata filters (test_type, test_category, group, scope, enforce)
- `mcp__plugin_test-writing_test-rules__build_rule_package` — Render a rule catalog to a file in plugin storage and return its path. With no arguments it renders the unit-review catalog (convention, design, unit, isolation, provider); pass `group` with `test_type` to render a single non-unit catalog (integration, migration, placement). Optional scope filters (`review_unit` / `test_category` / `scoped_review`) render a scoped subset under a scope-derived filename. The unified team review builds one catalog per test type present at composition time and passes them to the committed workflow script, which selects each agent's scoped rules from the file's per-type catalog inline, so agents apply only their per-track rules without fetching them per agent.
- `mcp__plugin_test-writing_test-rules__assert_surviving_tests` — Report what a test class contains once a set of deletions is applied. Pass `test_path` and `deleted_methods` (the method names a remediation removes entirely, `[]` to report the current state); returns `{test_path, total, deleted, surviving, status}`. `status` is `OK` (survivors remain), `EMPTY` (the deletions would leave the class with no tests — PHPUnit reports `No tests found in class`), or `UNRESOLVED` (the class is abstract, extends an unrecognized base, or draws test methods from a trait, so its runnable set cannot be derived from this file alone). Used by the three reviewing skills and the team-reviewing workflow as an after-state guard on deletion-carrying findings.

## 📚 Documentation

Reference files provide detailed guidance:

- **Test categories**: `skills/phpunit-unit-test-reviewing/references/test-categories.md`
- **Rule summary**: Dynamically served by `mcp__plugin_test-writing_test-rules__get_rules`
- **Shopware stubs**: `rules/unit/UNIT-003.md` (stub patterns), `skills/phpunit-unit-test-generation/references/shopware-stubs.md` (generation reference)
- **Output format**: `skills/phpunit-unit-test-reviewing/references/output-format.md`
- **Report formats**: `skills/phpunit-unit-test-writing/references/report-formats.md`
- **Oscillation handling**: `skills/phpunit-unit-test-writing/references/oscillation-handling.md`
- **Team review**: `skills/phpunit-test-team-reviewing/references/` (input-resolution, workflow-design, agent-guardrails, reviewer-allocation, red-team-context, consensus-and-verdicts, report-format, error-handling)
- **Reconciling**: `skills/phpunit-test-reconciling/references/` (reconciliation-rules, output-format)

### Rule Files

Individual rule files are in `rules/` organized by group:
- `rules/convention/` — PHPUnit and Shopware coding conventions (CONV-001 through CONV-017)
- `rules/design/` — Test design principles (DESIGN-001 through DESIGN-010)
- `rules/isolation/` — Test independence and isolation (ISOLATION-001 through ISOLATION-006)
- `rules/provider/` — Data provider patterns (PROVIDER-001 through PROVIDER-005)
- `rules/unit/` — Unit test-specific rules (UNIT-001 through UNIT-010)
- `rules/migration/` — Migration test rules (MIGRATION-001 through MIGRATION-009)
- `rules/integration/` — Integration test rules (INTEGRATION-001 through INTEGRATION-008)
- `rules/placement/` — Placement reasoning prompts (PLACEMENT-001 through PLACEMENT-008)

### Category Templates

Generation templates for each category:
- `skills/phpunit-unit-test-generation/templates/category-a-dto.md`
- `skills/phpunit-unit-test-generation/templates/category-b-service.md`
- `skills/phpunit-unit-test-generation/templates/category-c-flow.md`
- `skills/phpunit-unit-test-generation/templates/category-d-dal.md`
- `skills/phpunit-unit-test-generation/templates/category-e-exception.md`

## 🏗️ Developer Guide

See `AGENTS.md` for plugin architecture and development guidance.

## ⚖️ License

MIT
