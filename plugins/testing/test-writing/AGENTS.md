@README.md

## Quick Reference

| Component | Purpose | File |
|-----------|---------|------|
| Orchestrator | 4-phase workflow | `skills/phpunit-unit-test-writing/SKILL.md` |
| Generator | Test creation (categories A-E) | `skills/phpunit-unit-test-generation/SKILL.md` |
| Reviewer | 14-phase compliance analysis | `skills/phpunit-unit-test-reviewing/SKILL.md` |

**Agents:**
| Agent | Purpose | Permissions |
|-------|---------|-------------|
| `phpunit-unit-test-generator` | Create tests from source | acceptEdits |
| `phpunit-unit-test-reviewer` | Read-only analysis | none (read-only) |
| `phpunit-unit-test-reviewer-fixer` | Analysis + fix loop | acceptEdits |

**MCP Tools (used by fixer agent, NEVER Bash equivalents):**
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
│   ├── phpunit-unit-test-reviewer.md
│   └── phpunit-unit-test-reviewer-fixer.md
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
Phase 2: Invokes test-writing:phpunit-unit-test-reviewer-fixer (Agent)
    ↓
Agent validates test path → Invokes test-writing:phpunit-unit-test-reviewing (Skill)
    ↓
Skill reviews test → Agent applies fixes → Re-validates → Re-reviews (up to 4 iterations internally)
    ↓
Agent returns final status with fixes_applied, iterations_used, oscillation_detected
    ↓
Phase 3/4: Orchestrator handles user decision on warnings/oscillation → Final report
```

### Tool Usage Policy

**CRITICAL**: All PHP validation MUST use MCP tools, NEVER shell commands.

| Forbidden (Bash) | Required (MCP) |
|------------------|----------------|
| `vendor/bin/phpstan` | `mcp__plugin_php-tooling_php-tooling__phpstan_analyze` |
| `vendor/bin/phpunit` | `mcp__plugin_php-tooling_php-tooling__phpunit_run` |
| `vendor/bin/ecs` | `mcp__plugin_php-tooling_php-tooling__ecs_check/fix` |
| `composer phpstan:*` | MCP equivalent |

**Note:** MCP tools are used by the fixer agent (not the orchestrator skill) to keep context isolated.

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

**Purpose**: Read-only test analysis without modifications.

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

**Model**: Sonnet | **Mode**: none (read-only, no edit permissions)

**Tools**: Glob, Grep, Read, Skill (no Edit, no MCP tools)

### phpunit-unit-test-reviewer-fixer

**Purpose**: Test analysis with automatic fix application and validation.

**Validates**: test exists, in `tests/unit/`, ends with `*Test.php`

**Features**:
- Internal fix loop (up to 4 iterations)
- Oscillation detection
- PHPStan/PHPUnit/ECS validation via MCP tools

**Output**:
```yaml
test_path: tests/unit/Path/To/ClassTest.php
status: PASS|NEEDS_ATTENTION|ISSUES_FOUND|FAILED
category: A|B|C|D|E
iterations_used: 2
fixes_applied:
  - code: E001
    location: line 45
oscillation_detected: false
issue_history:
  - iteration: 1
    issues: ["E001:45", "E008:67"]
  - iteration: 2
    issues: []
errors: []
warnings: []
reason: null
```

**Model**: Sonnet | **Mode**: acceptEdits

**Tools**: Glob, Grep, Read, Skill, Edit, + MCP tools

## Skills

### phpunit-unit-test-writing (Orchestrator)

Manages complete workflow from generation through review to final report.

**Features**: Sequential processing, delegates fix iterations to fixer agent, oscillation escalation to user

**Tools**: Task, TodoWrite, AskUserQuestion, Read, Glob (no MCP tools - delegated to fixer agent)

### phpunit-unit-test-generation

Generates Shopware-compliant PHPUnit unit tests.

**Features**: Category detection (A-E), test requirement rules, template-based generation, PHPStan/PHPUnit validation

### phpunit-unit-test-reviewing

Validates tests against Shopware conventions with 17 error codes.

**Features**: 14-phase review, E001-E017 errors, W001-W011 warnings, I001-I008 info, FIRST principles, test smell detection

## Modification Guide

| Task | Edit Files |
|------|------------|
| Add test category | `generation/SKILL.md` + `templates/category-*.md` + `reviewing/references/error-code-summary.md` |
| Add error code | `reviewing/SKILL.md` + `references/error-code-summary.md` + `references/error-code-details-*.md` |
| Change category detection | `generation/SKILL.md` Phase 1 + `reviewing/references/test-categories.md` |
| Modify fix iterations | `agents/phpunit-unit-test-reviewer-fixer.md` (max iterations in fix loop) |
| Update oscillation handling | `agents/phpunit-unit-test-reviewer-fixer.md` + `writing/SKILL.md` Step 3 |
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

Fixer agent references via frontmatter:
```yaml
tools: Glob, Grep, Read, Skill, Edit, mcp__plugin_php-tooling_php-tooling__phpstan_analyze, mcp__plugin_php-tooling_php-tooling__phpunit_run, mcp__plugin_php-tooling_php-tooling__ecs_check, mcp__plugin_php-tooling_php-tooling__ecs_fix
```

## External References

- [Shopware PHPUnit Testing Docs](https://developer.shopware.com/docs/guides/plugins/plugins/testing/php-unit)
- [PHPUnit Documentation](https://phpunit.de/documentation.html)
- [PHPStan Documentation](https://phpstan.org/user-guide/getting-started)
