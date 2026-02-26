---
name: phpunit-unit-test-generation
version: 2.0.3
description: Internal sub-skill of phpunit-unit-test-writing orchestrator. Not user-facing — invoked only via Skill(test-writing:phpunit-unit-test-generation) from the orchestrator.
user-invocable: false
context: fork
agent: test-writing:test-generator
allowed-tools: Read, Grep, Glob, Write, Edit, mcp__plugin_dev-tooling_php-tooling__phpunit_run, mcp__plugin_dev-tooling_php-tooling__phpstan_analyze, mcp__plugin_dev-tooling_php-tooling__ecs_check, mcp__plugin_dev-tooling_php-tooling__ecs_fix
---

# PHPUnit Test Generation

Generate Shopware-compliant PHPUnit unit tests that pass PHPStan and PHPUnit validation.

## File Write Restrictions

Write ONLY to:
- `tests/unit/**` - Unit test files

NEVER write to:
- `src/**` - Source code (read-only)
- `tests/integration/**` - Out of scope
- Any other directory

## Tool Usage Policy

Use ONLY MCP tools for PHP validation (NEVER Bash commands):

| Instead of (Bash) | Use (MCP) |
|-------------------|-----------|
| `vendor/bin/phpstan` | `mcp__plugin_dev-tooling_php-tooling__phpstan_analyze` |
| `vendor/bin/phpunit` | `mcp__plugin_dev-tooling_php-tooling__phpunit_run` |
| `vendor/bin/ecs` | `mcp__plugin_dev-tooling_php-tooling__ecs_check` / `ecs_fix` |
| `composer phpstan:*` | MCP equivalent |

MCP tools handle environment detection (native/docker/vagrant/ddev) automatically.

## Quick Start

1. Read the target source class
2. **Check if test is required** (see Phase 1)
3. Determine test category (A-E)
4. Apply the matching template
5. Validate with PHPStan and PHPUnit
6. Fix any errors and repeat
7. Generate completion report

---

## Phase 1: Analyze Source Class

### Step 1: Check Coverage Exclusions

Before analyzing the source class, check if the project's `phpunit.xml.dist` (or `phpunit.xml`) excludes it from coverage. Files excluded from coverage do not need unit tests.

1. **Read** `phpunit.xml.dist` from the project root
2. **Find** `<exclude>` rules inside the `<coverage>` or `<source>` section
3. **Match** the source file path against each rule:
   - `<directory suffix="X">path</directory>` — excluded if file is under `path` AND filename ends with `X`
   - `<file>path/to/File.php</file>` — excluded if relative path matches exactly
4. **If excluded** → Return SKIPPED with reason: "Source file excluded from coverage by phpunit.xml.dist (`<matched-rule>`)"

If `phpunit.xml.dist` is not found, skip this step.

### Step 2: Determine If Test Is Required

Before generating any test, evaluate if the class/method requires one.

**Quick check**: Does the method body contain ONLY `return <literal|constant|property|passthrough-new>`?
- **Yes** -> NO TEST NEEDED (no logic)
- **No** (has conditionals/loops/transformations) -> Continue to Step 3

For detailed rules on what to test vs skip, see [test-requirement-rules.md](references/test-requirement-rules.md).

### Step 3: Analyze Source Structure

Read the target class to determine:
1. **Public methods** - What behaviors to test
2. **Constructor dependencies** - What to mock/stub
3. **Return types** - Expected outcomes
4. **Exception scenarios** - Error paths

### Step 4: Detect Category

Use the decision tree to select the appropriate category:

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

For detailed category criteria, see [category-detection.md](references/category-detection.md).

---

## Phase 2: Essential Rules

Apply these mandatory conventions when generating tests.

### Quick Reference

| Rule | Requirement |
|------|-------------|
| File location | `tests/unit/` mirroring `src/` path |
| Class attribute | `#[CoversClass(TargetClass::class)]` required |
| Assertions | Use `static::` not `$this->` |
| Base class | Extend `PHPUnit\Framework\TestCase` |
| Method naming | `test` + `Action` + `Condition` + `ExpectedResult` |
| Attribute order | PHPDoc -> DataProvider -> TestDox -> method |
| One behavior | NO conditionals in tests |

### TestDox Phrasing

TestDox MUST be a **predicate phrase** starting with an action verb:
- **Good**: "creates product", "returns null", "throws exception"
- **Bad**: "It creates...", "Should return...", "Tests that..."

### Mocking Priority

1. **Real implementation** - Use actual objects when simple
2. **Shopware stubs** - `StaticEntityRepository`, `StaticSystemConfigService`, `Generator`
3. **PHPUnit mocks** - Only for external/IO dependencies

For complete rules, see [essential-rules.md](references/essential-rules.md).

---

## Phase 3: Generate Test

### Step 1: Select Template

Based on category from Phase 1:

| Category | Template |
|----------|----------|
| A (DTO) | [category-a-dto.md](templates/category-a-dto.md) |
| B (Service) | [category-b-service.md](templates/category-b-service.md) |
| C (Flow/Event) | [category-c-flow.md](templates/category-c-flow.md) |
| D (DAL) | [category-d-dal.md](templates/category-d-dal.md) |
| E (Exception) | [category-e-exception.md](templates/category-e-exception.md) |

### Step 2: Replace Placeholders

- `{Module}` - Core module (e.g., `Content`, `Checkout`, `System`)
- `{Submodule}` - Submodule path (e.g., `Product`, `Cart\LineItem`)
- `{TargetClass}` - Class name being tested
- `{Entity}` - Entity name for DAL tests
- `{Method}` - Method name being tested
- `{Expected}` - Expected outcome description
- `{Condition}` - Condition description
- `{Exception}` - Exception class name

### Step 3: Write Test File

Write to correct location: `tests/unit/{path matching src}/{ClassName}Test.php`

---

## Phase 4: Validate and Fix

**CRITICAL**: Use ONLY MCP tools for validation. NEVER use shell commands.

**Prerequisite**: The `dev-tooling` plugin must be installed (provides `php-tooling` MCP server). If unavailable, proceed to Phase 5 with status PARTIAL.

### Validation Loop

```
- [ ] PHPStan passes (0 errors)
- [ ] PHPUnit passes (all tests green)
- [ ] ECS passes (code style)
```

### Step 1: Run PHPStan

```json
{
  "paths": ["tests/unit/Path/To/GeneratedTest.php"],
  "error_format": "json"
}
```

Zero errors = pass.

### Step 2: Fix PHPStan Errors

Apply fixes for common errors. See [validation-error-mapping.md](references/validation-error-mapping.md).

### Step 3: Run PHPUnit

```json
{
  "paths": ["tests/unit/Path/To/GeneratedTest.php"],
  "output_format": "testdox"
}
```

All tests passing = success.

### Step 4: Fix Test Failures

Apply fixes for common failures. See [validation-error-mapping.md](references/validation-error-mapping.md).

### Step 5: Run ECS Check and Fix

Check for violations, then apply fixes if needed.

### Repeat Until Pass

Loop through Steps 1-5 until all validations pass.

**Maximum iterations**: Stop after 3 failed attempts and proceed to Phase 5.

---

## Phase 5: Generate Report

For output format and examples, see [output-format.md](references/output-format.md).

### Status Determination

| Condition | Status |
|-----------|--------|
| All validations pass | SUCCESS |
| Test generated, validation issues remain after 3 iterations | PARTIAL |
| No test required (per Test Requirement Rules) | SKIPPED |
| Invalid input (not a PHP class, file not found) | FAILED |

### Report Contents

1. **Summary**: Source path, test path, status, category
2. **Generation Details**: Test method count, template used
3. **Validation Results**: PHPStan/PHPUnit/ECS pass/fail counts
4. **Remaining Issues** (if PARTIAL): Location, error, status table

---

## Additional Resources

### Reference Files

For detailed patterns and techniques, consult:

- **[test-requirement-rules.md](references/test-requirement-rules.md)** - Decision tree for what to test
- **[category-detection.md](references/category-detection.md)** - How to categorize source classes
- **[essential-rules.md](references/essential-rules.md)** - Naming, attribute, structure rules
- **[validation-error-mapping.md](references/validation-error-mapping.md)** - Error codes and fixes
- **[shopware-stubs.md](references/shopware-stubs.md)** - StaticEntityRepository, Generator patterns
- **[common-patterns.md](references/common-patterns.md)** - Exception testing, data providers, mocks
- **[output-format.md](references/output-format.md)** - Report output contract

### Templates

Category-specific test generation templates in `templates/`:

- **category-a-dto.md** - Simple DTO/Entity tests
- **category-b-service.md** - Service tests with dependencies
- **category-c-flow.md** - Flow/Event subscriber tests
- **category-d-dal.md** - DAL/Repository tests
- **category-e-exception.md** - Exception handling tests
