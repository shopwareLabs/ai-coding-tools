# Test Writing

Generate and validate PHPUnit unit tests for Shopware 6. Automatically analyzes source classes, generates category-appropriate tests, reviews for compliance, and fixes issues until tests pass.

## Features

- **Automated Test Generation**: Analyzes source class structure to generate category-appropriate unit tests
- **Review & Fix Loop**: Up to 4 review iterations with automatic fix application
- **5 Test Categories**: DTO (A), Service (B), Flow/Event (C), DAL (D), Exception (E)
- **19 Error Codes**: Comprehensive validation against Shopware testing conventions
- **FIRST Principles**: Detects shared state (Independent) and non-deterministic inputs (Repeatable)
- **Test Smell Detection**: Identifies Mystery Guest, unclear AAA structure, unbalanced coverage
- **Oscillation Detection**: Prevents infinite fix loops by detecting recurring issues
- **PHPStan/PHPUnit Validation**: Automatically validates generated tests with MCP tools
- **Shopware Stubs**: Uses StaticEntityRepository, StaticSystemConfigService, Generator

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

### Phase 2: Review and Fix (Internal Loop)

The fixer agent (`phpunit-unit-test-reviewer-fixer`) handles fix iterations internally (up to 4):

1. Reviews generated test against 19 error codes
2. If errors found: applies fixes, re-validates with PHPStan/PHPUnit, re-reviews
3. Detects oscillation (same issue recurring) and stuck loops
4. Returns final status with `fixes_applied`, `iterations_used`, `oscillation_detected`

**Context Efficiency**: Fix iterations run in isolated agent context, significantly reducing main context tool calls.

**Note**: A separate read-only reviewer agent (`phpunit-unit-test-reviewer`) is available for analysis without modifications.

### Phase 3: User Decision

1. If oscillation detected: presents details, asks user to continue or abort
2. If warnings remain: presents warnings, asks for approval to apply fixes
3. Applies fixes if approved

### Phase 4: Final Report

1. Provides comprehensive summary
2. Lists test file, category, iterations used, applied fixes
3. Reports final status

## Error Codes

### Errors (E###) - Must Fix

| Code | Issue |
|------|-------|
| E001 | Test contains conditional logic (if/else/switch/match/ternary) |
| E002 | Test method tests multiple behaviors |
| E003 | Wrong attribute order (PHPDoc → DataProvider → TestDox) |
| E004 | Test method identification (missing `test` prefix OR redundant `#[Test]`) |
| E005 | Tests implementation details, trivial code, or private members |
| E006 | Ambiguous or non-descriptive test name (includes BDD-style `testIt...`) |
| E007 | Data provider not used for similar test variations (3+ similar tests) |
| E008 | Using `$this->` instead of `static::` for assertions |
| E009 | Test redundancy (unjustified cases or methods covering same path) |
| E010 | Test method ordering doesn't follow pattern |
| E011 | TestDox phrasing doesn't follow guidelines |
| E012 | Over-mocking (should use StaticEntityRepository or real impl) |
| E013 | Test class structure order incorrect |
| E014 | Exception expectation set after throwing call |
| E015 | Test class covers multiple classes (integration test smell) |
| E016 | Shared mutable state between tests (FIRST: Independent) |
| E017 | Non-deterministic inputs without mocking (FIRST: Repeatable) |
| E018 | Weak exception assertion (type-only `expectException()` without message, code, or object) |
| E019 | Call-count over-coupling (`expects(once())` on collaborators whose result is already asserted) |

### Warnings (W###) - Should Fix

| Code | Issue |
|------|-------|
| W001 | Test name uses implementation-specific terminology |
| W002 | Assertion scope (multiple assertions testing different behaviors) |
| W003 | Missing TestDox attribute for complex test |
| W004 | Data provider key quality (missing OR non-descriptive keys) |
| W005 | Using assertTrue($x === $y) instead of assertEquals |
| W006 | Uses legacy `Generator::createSalesChannelContext()` |
| W007 | Data provider not using `{action}Provider` naming pattern |
| W008 | Class-level TestDox used (prefer method-level only) |
| W009 | Mystery Guest - problematic file dependency |
| W010 | Unbalanced coverage distribution (< 20% edge+error cases) |
| W011 | Unclear AAA structure (assertions interspersed with setup) |
| W012 | `createMock()` used when `createStub()` would suffice (no `expects()` calls on the variable) |
| W013 | Opaque test data identifiers (UUID hex strings instead of descriptive strings like `'product-id'`) |

### Informational (I###) - Optional

| Code | Issue |
|------|-------|
| I001 | Test could benefit from data provider consolidation |
| I002 | Test execution time concern (external dependencies) |
| I003 | Consider PHPUnit 11.5 features (#[TestWithJson]) |
| I004 | Consider expectExceptionObject for factory-created exceptions |
| I005 | Consider `#[DisabledFeatures]` for legacy behavior tests |
| I006 | Consider callable-based StaticEntityRepository for criteria validation |
| I007 | Potential preservation value in redundant test (regression/bug documentation) |
| I008 | Consider real fixture files for file I/O testing |

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
  - code: E001
    title: Issue title
    location: ClassTest.php:45
    current: |
      # problematic code
    suggested: |
      # fixed code
warnings: []
reason: null  # explanation if FAILED
```

### Fixer Agent Output

```yaml
test_path: tests/unit/Path/To/ClassTest.php
status: PASS|NEEDS_ATTENTION|ISSUES_FOUND|FAILED
category: A|B|C|D|E
iterations_used: 2
fix_attempts:
  - code: E001
    location: line 45
    attempted: true
    applied: true
    reason: null
  - code: E009
    location: line 89
    attempted: true
    applied: false
    reason: "Fix would break other tests"
oscillation_detected: false
issue_history:
  - iteration: 1
    issues: ["E001:45", "E009:89"]
  - iteration: 2
    issues: ["E009:89"]
errors: []
warnings: []
reason: null
```

**fix_attempts fields:**
- `attempted`: true if fix was tried, false if skipped
- `applied`: true if fix succeeded, false if failed
- `reason`: explanation if not attempted or not applied

## Configuration

### Required Plugin

The `dev-tooling` plugin must be installed (this plugin bundles an MCP server reference to it):

```bash
/plugin install dev-tooling@shopware-plugins
```

### Project Configuration

Create `.mcp-php-tooling.json` in your project root. See the [dev-tooling documentation](../dev-tooling/README.md) for configuration options and examples.

The MCP server supports custom config paths via `--config` argument in the bundled `.mcp.json`.

## Documentation

Reference files provide detailed guidance:

- **Test categories**: `skills/phpunit-unit-test-reviewing/references/test-categories.md`
- **Error codes**: `skills/phpunit-unit-test-reviewing/references/error-code-summary.md`
- **Mocking strategy**: `skills/phpunit-unit-test-reviewing/references/mocking-strategy.md`
- **Shopware stubs**: `skills/phpunit-unit-test-reviewing/references/shopware-stubs.md`
- **Feature flags**: `skills/phpunit-unit-test-reviewing/references/feature-flags.md`
- **PHPUnit conventions**: `skills/phpunit-unit-test-reviewing/references/phpunit-conventions.md`
- **Report formats**: `skills/phpunit-unit-test-writing/references/report-formats.md`
- **Oscillation handling**: `skills/phpunit-unit-test-writing/references/oscillation-handling.md`

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
