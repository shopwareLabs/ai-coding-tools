@README.md

## Quick Reference

| Component | Purpose | File |
|-----------|---------|------|
| Orchestrator | 4-phase workflow | `skills/phpunit-unit-test-writing/SKILL.md` |
| Generator | Test creation (categories A-E) | `skills/phpunit-unit-test-generation/SKILL.md` |
| Reviewer | 14-phase compliance validation | `skills/phpunit-unit-test-reviewing/SKILL.md` |

**MCP Tools (NEVER use Bash equivalents):**
- `mcp__plugin_php-tooling_php-tooling__phpstan_analyze`
- `mcp__plugin_php-tooling_php-tooling__phpunit_run`
- `mcp__plugin_php-tooling_php-tooling__ecs_check/fix`

## Directory Structure

```
plugins/testing/test-writing/
├── README.md
├── AGENTS.md
├── agents/
│   ├── phpunit-unit-test-generator.md
│   └── phpunit-unit-test-reviewer.md
└── skills/
    ├── phpunit-unit-test-writing/
    │   ├── SKILL.md
    │   └── references/{report-formats,oscillation-handling}.md
    ├── phpunit-unit-test-generation/
    │   ├── SKILL.md
    │   ├── references/{category-detection,common-patterns,essential-rules,output-format,shopware-stubs,test-requirement-rules,validation-error-mapping}.md
    │   └── templates/category-{a,b,c,d,e}-*.md
    └── phpunit-unit-test-reviewing/
        ├── SKILL.md
        └── references/{error-code-summary,error-code-details-*,test-categories,output-format,phpunit-conventions,mocking-strategy,shopware-stubs,feature-flags,test-case-justification}.md
```

## Architecture

### Invocation Flow

```
User Request
    ↓
test-writing:phpunit-unit-test-writing (Orchestrator Skill)
    ↓
Phase 1: Invokes test-writing:phpunit-unit-test-generator (Agent)
    ↓
Agent validates input → Invokes test-writing:phpunit-unit-test-generation (Skill)
    ↓
Skill generates test → Returns status, test_path, category
    ↓
Phase 2: Invokes test-writing:phpunit-unit-test-reviewer (Agent)
    ↓
Agent validates test path → Invokes test-writing:phpunit-unit-test-reviewing (Skill)
    ↓
Skill reviews test → Returns status, errors, warnings
    ↓
Orchestrator applies fixes → Re-validates → Re-reviews (up to 4 iterations)
    ↓
Phase 3/4: User decision on warnings → Final report
```

### Tool Usage Policy

**CRITICAL**: All PHP validation MUST use MCP tools, NEVER shell commands.

| Forbidden (Bash) | Required (MCP) |
|------------------|----------------|
| `vendor/bin/phpstan` | `mcp__plugin_php-tooling_php-tooling__phpstan_analyze` |
| `vendor/bin/phpunit` | `mcp__plugin_php-tooling_php-tooling__phpunit_run` |
| `vendor/bin/ecs` | `mcp__plugin_php-tooling_php-tooling__ecs_check/fix` |
| `composer phpstan:*` | MCP equivalent |

## Agents

### phpunit-unit-test-generator

**Validates**: source exists, is PHP class (not interface/trait), in `src/`

**Output**:
```yaml
source: src/Path/To/Class.php
test_path: tests/unit/Path/To/ClassTest.php
status: SUCCESS|PARTIAL|SKIPPED|FAILED
category: A|B|C|D|E
reason: null  # if not SUCCESS
```

**Model**: Sonnet | **Mode**: acceptEdits

### phpunit-unit-test-reviewer

**Validates**: test exists, in `tests/unit/`, ends with `*Test.php`

**Output**:
```yaml
test_path: tests/unit/Path/To/ClassTest.php
status: PASS|NEEDS_ATTENTION|ISSUES_FOUND|FAILED
category: A|B|C|D|E
errors: [{code, title, location, current, suggested}]
warnings: []
reason: null  # if FAILED
```

**Model**: Sonnet | **Mode**: bypassPermissions (read-only)

## Skills

### phpunit-unit-test-writing (Orchestrator)

Manages complete workflow from generation through review to final report.

**Features**: Sequential processing, 4-iteration max, oscillation detection, stuck loop detection

### phpunit-unit-test-generation

Generates Shopware-compliant PHPUnit unit tests.

**Features**: Category detection (A-E), test requirement rules, template-based generation, PHPStan/PHPUnit validation

### phpunit-unit-test-reviewing

Validates tests against Shopware conventions with 17 error codes.

**Features**: 14-phase review, E001-E017 errors, W001-W011 warnings, I001-I007 info, FIRST principles, test smell detection

## Modification Guide

| Task | Edit Files |
|------|------------|
| Add test category | `generation/SKILL.md` + `templates/category-*.md` + `reviewing/references/error-code-summary.md` |
| Add error code | `reviewing/SKILL.md` + `references/error-code-summary.md` + `references/error-code-details-*.md` |
| Change category detection | `generation/SKILL.md` Phase 1 + `reviewing/references/test-categories.md` |
| Modify review iterations | `writing/SKILL.md` Phase 2 |
| Update oscillation handling | `writing/references/oscillation-handling.md` + `writing/SKILL.md` Step 3 |
| Change generation template | `generation/templates/category-*.md` + `generation/SKILL.md` Phase 3 |
| Update mocking guidance | `reviewing/references/mocking-strategy.md` |
| Add Shopware stub | `reviewing/references/shopware-stubs.md` + `generation/templates/*` |
| Modify feature flags | `reviewing/references/feature-flags.md` |
| Change report format | `writing/references/report-formats.md` |
| Update PHPUnit conventions | `reviewing/references/phpunit-conventions.md` |
| Change agent validation | `agents/*.md` validation section |
| Modify preservation criteria | `reviewing/references/test-case-justification.md` |
| Change output contracts | Agent file + corresponding `references/output-format.md` |

## Integration

### php-tooling Plugin (Required)

MCP tools follow pattern: `mcp__plugin_php-tooling_php-tooling__<tool_name>`

Skills reference via frontmatter:
```yaml
allowed-tools: mcp__plugin_php-tooling_php-tooling__phpstan_analyze, mcp__plugin_php-tooling_php-tooling__phpunit_run
```

## External References

- [Shopware PHPUnit Testing Docs](https://developer.shopware.com/docs/guides/plugins/plugins/testing/php-unit)
- [PHPUnit Documentation](https://phpunit.de/documentation.html)
- [PHPStan Documentation](https://phpstan.org/user-guide/getting-started)
