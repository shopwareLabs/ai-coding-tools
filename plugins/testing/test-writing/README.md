# Test Writing

Generate and validate PHPUnit unit tests for Shopware 6. Automatically analyzes source classes, generates category-appropriate tests, reviews for compliance, and fixes issues until tests pass.

## Features

- **Automated Test Generation**: Analyzes source class structure to generate category-appropriate unit tests
- **Review & Fix Loop**: Up to 4 review iterations with automatic fix application
- **5 Test Categories**: DTO (A), Service (B), Flow/Event (C), DAL (D), Exception (E)
- **17 Error Codes**: Comprehensive validation against Shopware testing conventions
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
- `php-tooling` plugin must be installed (MCP server reference is bundled)
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

### Phase 2: Review Loop (Up to 4 Iterations)

1. Reviews generated test against 17 error codes
2. If errors found: applies fixes, re-validates, re-reviews
3. Detects oscillation (same issue recurring) and escalates
4. Exits on PASS, max iterations, or stuck loop

### Phase 3: User Decision

1. Presents remaining warnings to user
2. Asks for approval to apply warning fixes
3. Applies fixes if approved

### Phase 4: Final Report

1. Provides comprehensive summary
2. Lists test file, category, iterations, applied fixes
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

### Reviewer Output

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

## Configuration

### Required Plugin

The `php-tooling` plugin must be installed (this plugin bundles an MCP server reference to it):

```bash
/plugin install php-tooling@shopware-plugins
```

### Project Configuration

Create `.mcp-php-tooling.json` in your project root. See the [php-tooling documentation](../../code-quality/php-tooling/README.md) for configuration options and examples.

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
