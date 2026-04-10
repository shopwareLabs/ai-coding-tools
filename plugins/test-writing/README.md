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
- **MCP Rule Server**: Dynamic rule discovery with `mcp__plugin_test-writing_test-rules__list_rules` and `mcp__plugin_test-writing_test-rules__get_rules` for context-efficient reviews
- **Team-Based Consensus Review**: Wave-based Agent Teams orchestration with 3-5 independent reviewers and 1-2 adversaries. 4 waves: independent review, peer-to-peer debate via SendMessage, adversarial red team, defense (see [Team Review](#team-review) below)
- **Migration Test Generation**: Analyzes migration source classes (SQL operations, updateDestructive logic) to generate pattern-appropriate migration tests
- **Migration Test Reviewing**: 8 migration-specific rules covering idempotency, cleanup, assertion patterns, and Shopware conventions

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

Run a consensus-based review with multiple independent reviewers:

```
Review tests in tests/unit/Core/Content/ with a team
Team review the tests changed in this PR
```

Accepts file paths, directories, commits, branches, and PRs as input.

> [!WARNING]
> Team review uses [Agent Teams](https://code.claude.com/docs/en/agent-teams), an experimental Claude Code feature. It requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and consumes significantly more tokens than a standard single-reviewer run due to multiple parallel agents, peer-to-peer debate, and adversarial red team challenges.

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

| Pattern | Detection | Test Structure |
|---------|-----------|----------------|
| Schema-Add | `CREATE TABLE`, `addColumn()` | rollback → migrate twice → assert exists |
| Schema-Remove | `DROP TABLE/COLUMN` in updateDestructive | ensure exists → updateDestructive twice → assert gone |
| Data-Update | `UPDATE`, `INSERT`, `DELETE` | set up state → migrate twice → assert values |
| Config | `system_config` operations | delete/set config → migrate twice → assert value |
| Mail Template | `mail_template` operations | migrate twice → assert no exception |

### Review Rules

| Rule ID | Issue |
|---------|-------|
| MIGRATION-001 | update() not called at least twice (idempotency) |
| MIGRATION-002 | updateDestructive() not called at least twice when source has logic |
| MIGRATION-003 | Test reuses migration helper methods for verification |
| MIGRATION-004 | Test-created tables/data not cleaned up |
| MIGRATION-005 | Multiple SQL in single try/catch in setUp/tearDown, or catching Exception instead of Throwable |
| MIGRATION-006 | String interpolation for table/column names in SQL |
| MIGRATION-007 | assertEquals used instead of assertSame |
| MIGRATION-008 | Missing testGetCreationTimestamp method |

All migration rules are **must-fix** and enforced on new tests.

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

1. Discovers applicable rules via `mcp__plugin_test-writing_test-rules__list_rules(test_type=unit, test_category={detected})`
2. Loads rule content via `mcp__plugin_test-writing_test-rules__get_rules` and applies detection algorithms
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

| Rule ID       | Issue                                                                                          |
|---------------|------------------------------------------------------------------------------------------------|
| DESIGN-001    | Test contains conditional logic (if/else/switch/match/ternary)                                 |
| DESIGN-002    | Test method tests multiple behaviors                                                           |
| CONV-001      | Wrong attribute order (PHPDoc → DataProvider → TestDox)                                        |
| CONV-002      | Test method identification (missing `test` prefix OR redundant `#[Test]`)                      |
| UNIT-001      | Tests implementation details, trivial code, or private members                                 |
| CONV-003      | Ambiguous or non-descriptive test name (includes BDD-style `testIt...`)                        |
| DESIGN-003    | Data provider not used for similar test variations (3+ similar tests)                          |
| CONV-004      | Using `$this->` instead of `static::` for assertions                                           |
| DESIGN-004    | Test redundancy (unjustified cases or methods covering same path)                              |
| CONV-005      | Test method ordering doesn't follow pattern                                                    |
| CONV-006      | TestDox phrasing doesn't follow guidelines                                                     |
| UNIT-003      | Over-mocking (should use StaticEntityRepository or real impl)                                  |
| CONV-007      | Test class structure order incorrect                                                           |
| CONV-008      | Exception expectation set after throwing call                                                  |
| UNIT-002      | Test class covers multiple classes (integration test smell)                                    |
| ISOLATION-001 | Shared mutable state between tests (FIRST: Independent)                                        |
| ISOLATION-002 | Non-deterministic inputs without mocking (FIRST: Repeatable)                                   |
| CONV-009      | Weak exception assertion (type-only `expectException()` without message, code, or object)      |
| UNIT-004      | Call-count over-coupling (`expects(once())` on collaborators whose result is already asserted) |
| UNIT-009      | Dedicated test for abstract class (test concrete implementations instead)                      |
| UNIT-007      | Deprecated API exercised without correct guard (`#[DisabledFeatures]`, `skipTestIfActive/InActive`) |
| UNIT-010      | `@` error suppression operator used on deprecated code (ineffective in Shopware test infra)    |

### Should-Fix Rules

| Rule ID       | Issue                                                                                                          |
|---------------|----------------------------------------------------------------------------------------------------------------|
| CONV-010      | Test name uses implementation-specific terminology                                                             |
| DESIGN-005    | Assertion scope (multiple assertions testing different behaviors)                                              |
| CONV-011      | Missing TestDox attribute for complex test                                                                     |
| PROVIDER-001  | Data provider key quality (missing OR non-descriptive keys)                                                    |
| CONV-012      | Using assertTrue($x === $y) instead of assertEquals                                                            |
| UNIT-006      | Uses legacy `Generator::createSalesChannelContext()`                                                           |
| PROVIDER-002  | Data provider not using `{action}Provider` naming pattern                                                      |
| CONV-013      | Class-level TestDox used (prefer method-level only)                                                            |
| ISOLATION-003 | Mystery Guest - problematic file dependency                                                                    |
| DESIGN-006    | Unbalanced coverage distribution (< 20% edge+error cases)                                                      |
| CONV-014      | Unclear AAA structure (assertions interspersed with setup)                                                     |
| UNIT-005      | `createMock()` used when `createStub()` would suffice (no `expects()` or argument callbacks on the variable)   |
| ISOLATION-004 | Opaque test data identifiers (UUID hex strings instead of descriptive strings like `'product-id'`)             |
| CONV-015      | `#[Package(...)]` attribute on test class (source ownership annotation has no meaning on tests)                |
| PROVIDER-003  | Data provider uses `return []` instead of `yield`/`iterable`                                                   |
| CONV-017      | Single-use test property (assigned in `setUp()`, used in only one test method — inline it)                     |
| CONV-016      | `Test` prefix on non-test helper class (reserve `Test` for classes extending `TestCase`; use `Stub*`, `Fake*`) |
| PROVIDER-004  | Description-only data provider parameter (used only for TestDox interpolation; use `$_dataName` instead)       |

### Consider Rules

| Rule ID       | Issue                                                                                                                  |
|---------------|------------------------------------------------------------------------------------------------------------------------|
| DESIGN-007    | Test could benefit from data provider consolidation                                                                    |
| ISOLATION-005 | Test execution time concern (external dependencies)                                                                    |
| PROVIDER-005  | Consider PHPUnit 11.5 features (#[TestWithJson])                                                                       |
| CONV-018      | Consider expectExceptionObject for factory-created exceptions                                                          |
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
| MIGRATION-005 | Multiple SQL in single try/catch in setUp/tearDown, or catching Exception instead of Throwable |
| MIGRATION-006 | String interpolation for table/column names in SQL                                             |
| MIGRATION-007 | assertEquals used instead of assertSame                                                        |
| MIGRATION-008 | Missing testGetCreationTimestamp method                                                        |

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
- `mcp__plugin_test-writing_test-rules__list_rules` — Discover applicable rules by test_type, test_category, group, scope, enforce level
- `mcp__plugin_test-writing_test-rules__get_rules` — Get full rule content by ID or metadata filters (test_type, test_category, group, scope, enforce)

## 📚 Documentation

Reference files provide detailed guidance:

- **Test categories**: `skills/phpunit-unit-test-reviewing/references/test-categories.md`
- **Rule summary**: Dynamically served by `mcp__plugin_test-writing_test-rules__list_rules`
- **Shopware stubs**: `rules/unit/UNIT-003.md` (stub patterns), `skills/phpunit-unit-test-generation/references/shopware-stubs.md` (generation reference)
- **Output format**: `skills/phpunit-unit-test-reviewing/references/output-format.md`
- **Report formats**: `skills/phpunit-unit-test-writing/references/report-formats.md`
- **Oscillation handling**: `skills/phpunit-unit-test-writing/references/oscillation-handling.md`
- **Team review**: `skills/phpunit-unit-test-team-reviewing/references/` (input-resolution, reviewer-allocation, message-formats, report-format, error-handling, red-team-context)
- **Debate**: `skills/phpunit-unit-test-debating/references/` (debate-rules, output-format)
- **Defense**: `skills/phpunit-unit-test-defending/references/` (defense-rules, output-format)

### Rule Files

Individual rule files are in `rules/` organized by group:
- `rules/convention/` — PHPUnit and Shopware coding conventions (CONV-001 through CONV-018)
- `rules/design/` — Test design principles (DESIGN-001 through DESIGN-009)
- `rules/isolation/` — Test independence and isolation (ISOLATION-001 through ISOLATION-006)
- `rules/provider/` — Data provider patterns (PROVIDER-001 through PROVIDER-005)
- `rules/unit/` — Unit test-specific rules (UNIT-001 through UNIT-010)
- `rules/migration/` — Migration test rules (MIGRATION-001 through MIGRATION-008)

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
