# Test Writing

Generate and validate PHPUnit unit tests for Shopware 6. Automatically analyzes source classes, generates category-appropriate tests, reviews for compliance, and fixes issues until tests pass.

## Features

- **Automated Test Generation**: Analyzes source class structure to generate category-appropriate unit tests
- **Review & Fix Loop**: Up to 4 fix iterations with automatic fix application run inline by the orchestrator
- **5 Test Categories**: DTO (A), Service (B), Flow/Event (C), DAL (D), Exception (E)
- **MCP-Driven Test Rules**: Comprehensive validation via MCP-driven rule discovery (must-fix, should-fix, consider — auto-discovered from `rules/` directory)
- **FIRST Principles**: Detects shared state (Independent) and non-deterministic inputs (Repeatable)
- **Test Smell Detection**: Identifies Mystery Guest, unclear AAA structure, unbalanced coverage
- **Oscillation Detection**: Prevents infinite fix loops by detecting recurring issues
- **PHPStan/PHPUnit Validation**: Automatically validates generated tests with MCP tools
- **Shopware Stubs**: Uses StaticEntityRepository, StaticSystemConfigService, Generator
- **MCP Rule Server**: Dynamic rule discovery with `mcp__plugin_test-writing_test-rules__list_rules` and `mcp__plugin_test-writing_test-rules__get_rules` for context-efficient reviews

## Quick Start

### Installation

```bash
/plugin install test-writing@shopware-plugins
```

**Prerequisites:**
- `dev-tooling` plugin must be installed (MCP server reference is bundled)
- `.mcp-php-tooling.json` configuration file in your project root (see Configuration below)
- Restart Claude Code after installation

### Basic Usage

Generate unit tests using natural language:

```
Generate unit tests for src/Core/Content/Product/ProductEntity.php
Write tests for src/Core/Checkout/Cart/CartService.php
```

The `phpunit-unit-test-writing` skill will be automatically invoked.

## Test Categories

Tests are categorized based on source class structure:

| Category | Name | Description | Key Traits |
|----------|------|-------------|------------|
| A | Simple DTO | Value objects, entities, collections | No dependencies, direct instantiation |
| B | Service | Services with constructor dependencies | Business logic, dependency injection |
| C | Flow/Event | Event subscribers, flow actions | Event dispatch, context passing |
| D | DAL | Repository operations | Uses StaticEntityRepository, Criteria |
| E | Exception | Exception classes and handling | Error messages, factory methods |

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

## Workflow

### Phase 1: Test Generation

1. Validates source file (exists, is PHP class, in `src/`)
2. Analyzes class structure to determine category
3. Applies category-specific template
4. Generates test file in `tests/unit/`
5. Validates with PHPStan and PHPUnit

### Phase 2: Review

1. Discovers applicable rules via `mcp__plugin_test-writing_test-rules__list_rules(test_type=unit, test_category={detected})`
2. Loads rule content via `mcp__plugin_test-writing_test-rules__get_rules` and applies detection algorithms
3. Returns structured report with errors (must-fix) and warnings (should-fix)

**Context Efficiency**: Only rules applicable to the detected test category are loaded, reducing context usage compared to static reference file loading.

**Note**: A separate read-only reviewer agent (`test-reviewer`) is available for analysis without modifications.

### Phase 3: Fix Loop (max 4 iterations)

If review finds errors, the orchestrator runs an inline fix loop:

1. Applies fixes from review report errors (Edit tool)
2. Re-validates with ECS, PHPStan, PHPUnit (MCP tools)
3. Re-invokes reviewing skill to check for remaining issues
4. Tracks issue history for oscillation detection
5. Exits on PASS, oscillation, stuck loop, or max iterations

### Phase 4: User Decision

1. If oscillation detected: presents details, asks user to continue or abort
2. If warnings remain: presents warnings, asks for approval to apply fixes
3. Applies fixes if approved

### Phase 5: Final Report

1. Provides comprehensive summary
2. Lists test file, category, iterations used, applied fixes
3. Reports final status

## Test Rules

Rules are organized by group and enforce level. Each rule has a new structured ID and a legacy code for backward compatibility.

### Must-Fix Rules

| Rule ID | Legacy | Issue |
|---------|--------|-------|
| DESIGN-001 | E001 | Test contains conditional logic (if/else/switch/match/ternary) |
| DESIGN-002 | E002 | Test method tests multiple behaviors |
| CONV-001 | E003 | Wrong attribute order (PHPDoc → DataProvider → TestDox) |
| CONV-002 | E004 | Test method identification (missing `test` prefix OR redundant `#[Test]`) |
| UNIT-001 | E005 | Tests implementation details, trivial code, or private members |
| CONV-003 | E006 | Ambiguous or non-descriptive test name (includes BDD-style `testIt...`) |
| DESIGN-003 | E007 | Data provider not used for similar test variations (3+ similar tests) |
| CONV-004 | E008 | Using `$this->` instead of `static::` for assertions |
| DESIGN-004 | E009 | Test redundancy (unjustified cases or methods covering same path) |
| CONV-005 | E010 | Test method ordering doesn't follow pattern |
| CONV-006 | E011 | TestDox phrasing doesn't follow guidelines |
| UNIT-003 | E012 | Over-mocking (should use StaticEntityRepository or real impl) |
| CONV-007 | E013 | Test class structure order incorrect |
| CONV-008 | E014 | Exception expectation set after throwing call |
| UNIT-002 | E015 | Test class covers multiple classes (integration test smell) |
| ISOLATION-001 | E016 | Shared mutable state between tests (FIRST: Independent) |
| ISOLATION-002 | E017 | Non-deterministic inputs without mocking (FIRST: Repeatable) |
| CONV-009 | E018 | Weak exception assertion (type-only `expectException()` without message, code, or object) |
| UNIT-004 | E019 | Call-count over-coupling (`expects(once())` on collaborators whose result is already asserted) |

### Should-Fix Rules

| Rule ID | Legacy | Issue |
|---------|--------|-------|
| CONV-010 | W001 | Test name uses implementation-specific terminology |
| DESIGN-005 | W002 | Assertion scope (multiple assertions testing different behaviors) |
| CONV-011 | W003 | Missing TestDox attribute for complex test |
| PROVIDER-001 | W004 | Data provider key quality (missing OR non-descriptive keys) |
| CONV-012 | W005 | Using assertTrue($x === $y) instead of assertEquals |
| UNIT-006 | W006 | Uses legacy `Generator::createSalesChannelContext()` |
| PROVIDER-002 | W007 | Data provider not using `{action}Provider` naming pattern |
| CONV-013 | W008 | Class-level TestDox used (prefer method-level only) |
| ISOLATION-003 | W009 | Mystery Guest - problematic file dependency |
| DESIGN-006 | W010 | Unbalanced coverage distribution (< 20% edge+error cases) |
| CONV-014 | W011 | Unclear AAA structure (assertions interspersed with setup) |
| UNIT-005 | W012 | `createMock()` used when `createStub()` would suffice (no `expects()` or argument callbacks on the variable) |
| ISOLATION-004 | W013 | Opaque test data identifiers (UUID hex strings instead of descriptive strings like `'product-id'`) |
| CONV-015 | W014 | `#[Package(...)]` attribute on test class (source ownership annotation has no meaning on tests) |
| PROVIDER-003 | W015 | Data provider uses `return []` instead of `yield`/`iterable` |
| CONV-017 | W016 | Single-use test property (assigned in `setUp()`, used in only one test method — inline it) |
| CONV-016 | W017 | `Test` prefix on non-test helper class (reserve `Test` for classes extending `TestCase`; use `Stub*`, `Fake*`) |
| PROVIDER-004 | W018 | Description-only data provider parameter (used only for TestDox interpolation; use `$_dataName` instead) |

### Consider Rules

| Rule ID | Legacy | Issue |
|---------|--------|-------|
| DESIGN-007 | I001 | Test could benefit from data provider consolidation |
| ISOLATION-005 | I002 | Test execution time concern (external dependencies) |
| PROVIDER-005 | I003 | Consider PHPUnit 11.5 features (#[TestWithJson]) |
| CONV-018 | I004 | Consider expectExceptionObject for factory-created exceptions |
| UNIT-007 | I005 | Consider `#[DisabledFeatures]` for legacy behavior tests |
| UNIT-008 | I006 | Consider callable-based StaticEntityRepository for criteria validation |
| DESIGN-008 | I007 | Potential preservation value in redundant test (regression/bug documentation) |
| ISOLATION-006 | I008 | Consider real fixture files for file I/O testing |
| DESIGN-009 | I009 | Duplicated inline Arrange code (identical construction in multiple test methods; extract to setUp() or private helper) |

## Output Contracts

### Generator Output

```yaml
source: src/Path/To/Class.php
test_path: tests/unit/Path/To/ClassTest.php
status: SUCCESS|PARTIAL|SKIPPED|FAILED
category: A|B|C|D|E
reason: null  # explanation if not SUCCESS
```

### Reviewer Output (Read-Only)

```yaml
test_path: tests/unit/Path/To/ClassTest.php
status: PASS|NEEDS_ATTENTION|ISSUES_FOUND|FAILED
category: A|B|C|D|E
errors:
  - rule_id: {rule_id}       # from mcp__plugin_test-writing_test-rules__get_rules response
    legacy: {legacy}          # from mcp__plugin_test-writing_test-rules__get_rules response
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

## Configuration

### Required Plugin

The `dev-tooling` plugin must be installed (this plugin bundles an MCP server reference to it):

```bash
/plugin install dev-tooling@shopware-plugins
```

### Project Configuration

Create `.mcp-php-tooling.json` in your project root. See the [dev-tooling documentation](../dev-tooling/README.md) for configuration options and examples.

The MCP server supports custom config paths via `--config` argument in the bundled `.mcp.json`.

### Bundled MCP Servers

This plugin bundles a `test-rules` MCP server that serves test writing rules. The server starts automatically when the plugin is installed.

**Tools:**
- `mcp__plugin_test-writing_test-rules__list_rules` — Discover applicable rules by test_type, test_category, group, scope, enforce level
- `mcp__plugin_test-writing_test-rules__get_rules` — Get full rule content by ID (supports both new IDs and legacy codes)
- `mcp__plugin_test-writing_test-rules__resolve_legacy` — Map legacy E/W/I codes to current rule IDs

## Documentation

Reference files provide detailed guidance:

- **Test categories**: `skills/phpunit-unit-test-reviewing/references/test-categories.md`
- **Rule summary**: Dynamically served by `mcp__plugin_test-writing_test-rules__list_rules`
- **Shopware stubs**: `rules/unit/UNIT-003.md` (stub patterns), `skills/phpunit-unit-test-generation/references/shopware-stubs.md` (generation reference)
- **Output format**: `skills/phpunit-unit-test-reviewing/references/output-format.md`
- **Report formats**: `skills/phpunit-unit-test-writing/references/report-formats.md`
- **Oscillation handling**: `skills/phpunit-unit-test-writing/references/oscillation-handling.md`

### Rule Files

Individual rule files are in `rules/` organized by group:
- `rules/convention/` — PHPUnit and Shopware coding conventions (CONV-001 through CONV-018)
- `rules/design/` — Test design principles (DESIGN-001 through DESIGN-009)
- `rules/isolation/` — Test independence and isolation (ISOLATION-001 through ISOLATION-006)
- `rules/provider/` — Data provider patterns (PROVIDER-001 through PROVIDER-005)
- `rules/unit/` — Unit test-specific rules (UNIT-001 through UNIT-008)

### Category Templates

Generation templates for each category:
- `skills/phpunit-unit-test-generation/templates/category-a-dto.md`
- `skills/phpunit-unit-test-generation/templates/category-b-service.md`
- `skills/phpunit-unit-test-generation/templates/category-c-flow.md`
- `skills/phpunit-unit-test-generation/templates/category-d-dal.md`
- `skills/phpunit-unit-test-generation/templates/category-e-exception.md`

## Developer Guide

See `AGENTS.md` for plugin architecture and development guidance.

## License

MIT
