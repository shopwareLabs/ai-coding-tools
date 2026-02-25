@README.md

## Quick Reference

| Component | Purpose | File |
|-----------|---------|------|
| Orchestrator | 4-phase workflow | `skills/phpunit-unit-test-writing/SKILL.md` |
| Generator | Test creation (categories A-E) | `skills/phpunit-unit-test-generation/SKILL.md` |
| Reviewer | MCP-driven compliance analysis by rule group | `skills/phpunit-unit-test-reviewing/SKILL.md` |

**Agents:**
| Agent | Purpose | Permissions |
|-------|---------|-------------|
| `phpunit-unit-test-generator` | Create tests from source | acceptEdits |
| `test-reviewer` | Read-only analysis (generic) | none (read-only) |
| `phpunit-unit-test-reviewer-fixer` | Analysis + fix loop | acceptEdits |

**MCP Tools (used by reviewer/fixer agents, NEVER Bash equivalents):**
- `mcp__plugin_dev-tooling_php-tooling__phpstan_analyze`
- `mcp__plugin_dev-tooling_php-tooling__phpunit_run`
- `mcp__plugin_dev-tooling_php-tooling__ecs_check/fix`
- `mcp__plugin_test-writing_test-rules__list_rules`
- `mcp__plugin_test-writing_test-rules__get_rules`

## Directory Structure

```
plugins/test-writing/
├── README.md
├── AGENTS.md
├── .mcp.json
├── agents/
│   ├── phpunit-unit-test-generator.md
│   ├── test-reviewer.md
│   └── phpunit-unit-test-reviewer-fixer.md
├── rules/
│   ├── convention/CONV-{001..018}.md
│   ├── design/DESIGN-{001..009}.md
│   ├── isolation/ISOLATION-{001..006}.md
│   ├── provider/PROVIDER-{001..005}.md
│   └── unit/UNIT-{001..008}.md
├── mcp-server-test-rules/
│   ├── server.sh
│   ├── tools.json
│   └── lib/{common,list,get,resolve}.sh
├── shared/
│   └── mcpserver_core.sh
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
        └── references/{test-categories,output-format}.md
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
Agent applies preloaded reviewing workflow → Applies fixes → Re-validates → Re-reviews (up to 4 iterations)
    ↓
Agent returns final status with fixes_applied, iterations_used, oscillation_detected
    ↓
Phase 3/4: Orchestrator handles user decision on warnings/oscillation → Final report
```

### Direct Review (without orchestrator)

```
test-writing:phpunit-unit-test-reviewing (Skill, context: fork)
    ↓
Forks into test-writing:test-reviewer (Agent)
    ↓
Agent validates input → Skill workflow executes → Returns structured report
```

### Rule Discovery Flow

```
Reviewing Skill
    ↓
Phase 2: mcp__plugin_test-writing_test-rules__list_rules(test_type=unit, test_category={detected})
    ↓
Groups rules by group: convention, design, unit, isolation, provider
    ↓
Phase 3-7: mcp__plugin_test-writing_test-rules__get_rules(ids={group IDs}) per group
    ↓
Apply detection algorithms → Record violations with rule IDs and enforce levels
```

### Tool Usage Policy

**CRITICAL**: All PHP validation MUST use MCP tools, NEVER shell commands.

| Forbidden (Bash) | Required (MCP) |
|------------------|----------------|
| `vendor/bin/phpstan` | `mcp__plugin_dev-tooling_php-tooling__phpstan_analyze` |
| `vendor/bin/phpunit` | `mcp__plugin_dev-tooling_php-tooling__phpunit_run` |
| `vendor/bin/ecs` | `mcp__plugin_dev-tooling_php-tooling__ecs_check/fix` |
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

### test-reviewer

**Purpose**: Generic read-only test reviewer. Used as execution environment for reviewing skills via `context: fork` — do not invoke directly.

**Validates**: single file, exists, ends with `*Test.php`

**Output**: Defined by the invoking skill's output contract.

**Model**: Sonnet | **Mode**: none (read-only, no edit permissions)

**Tools**: Glob, Grep, Read, mcp__plugin_test-writing_test-rules__list_rules, mcp__plugin_test-writing_test-rules__get_rules

### phpunit-unit-test-reviewer-fixer

**Purpose**: Test analysis with automatic fix application and validation.

**Validates**: test exists, in `tests/unit/`, ends with `*Test.php`

**Features**:
- Internal fix loop (up to 4 iterations)
- Oscillation detection
- PHPStan/PHPUnit/ECS validation via MCP tools
- Dynamic rule discovery via test-rules MCP server

**Output**:
```yaml
test_path: tests/unit/Path/To/ClassTest.php
status: PASS|NEEDS_ATTENTION|ISSUES_FOUND|FAILED
category: A|B|C|D|E
iterations_used: 2
fix_attempts:
  - rule_id: {rule_id}
    legacy: {legacy}
    location: line 45
    attempted: true
    applied: true
    reason: null
  - rule_id: {rule_id}
    legacy: {legacy}
    location: line 89
    attempted: true
    applied: false
    reason: "Fix would break other tests"
oscillation_detected: false
issue_history:
  - iteration: 1
    issues: ["{rule_id}:45", "{rule_id}:89"]
  - iteration: 2
    issues: ["{rule_id}:89"]
errors: []  # must-fix rules: MANDATORY compliance failures
warnings: []  # should-fix rules: optional improvements
reason: null
```

**fix_attempts fields**: `attempted` (true if tried), `applied` (true if succeeded), `reason` (explanation if failed)

**Status interpretation**:
- `PASS` → Test is COMPLIANT
- `ISSUES_FOUND` → Test is NON-COMPLIANT (has unresolved must-fix rules - mandatory failures)
- `NEEDS_ATTENTION` → Test is COMPLIANT (has should-fix rules - optional warnings only)

**Model**: Sonnet | **Mode**: acceptEdits

**Tools**: Glob, Grep, Read, Edit, + dev-tooling MCP tools, + test-rules MCP tools

**Preloaded skill**: `test-writing:phpunit-unit-test-reviewing` (reviewing workflow available without runtime Skill invocation)

## Skills

### phpunit-unit-test-writing (Orchestrator)

Manages complete workflow from generation through review to final report.

**Features**: Sequential processing, delegates fix iterations to fixer agent, oscillation escalation to user

**Tools**: Task, TodoWrite, AskUserQuestion, Read, Glob (no MCP tools - delegated to fixer agent)

### phpunit-unit-test-generation

Generates Shopware-compliant PHPUnit unit tests.

**Features**: Category detection (A-E), test requirement rules, template-based generation, PHPStan/PHPUnit validation

### phpunit-unit-test-reviewing

Validates tests against Shopware conventions using MCP-driven rule discovery.

**Features**: MCP-driven review by rule group (convention → design → unit → isolation → provider), dynamic rule loading by category, detection algorithms loaded from rule files

## Modification Guide

| Task | Edit Files |
|------|------------|
| Add test category | `generation/SKILL.md` + `templates/category-*.md` + `reviewing/references/test-categories.md` |
| Add rule | Create `rules/{group}/RULE-NNN.md` (MCP auto-discovers; no other files need updating) |
| Modify existing rule | Edit `rules/{group}/RULE-NNN.md` (content served by MCP) |
| Change category detection | `generation/SKILL.md` Phase 1 + `reviewing/references/test-categories.md` |
| Modify fix iterations | `agents/phpunit-unit-test-reviewer-fixer.md` (max iterations in fix loop) |
| Update oscillation handling | `agents/phpunit-unit-test-reviewer-fixer.md` + `writing/SKILL.md` Step 3 |
| Change generation template | `generation/templates/category-*.md` + `generation/SKILL.md` Phase 3 |
| Add Shopware stub | `rules/unit/UNIT-003.md` + `generation/references/shopware-stubs.md` + `generation/templates/*` |
| Change report format | `writing/references/report-formats.md` |
| Change agent validation | `agents/*.md` validation section |
| Change reviewer agent | `agents/test-reviewer.md` (generic — shared by all reviewing skills) |
| Change output contracts | Agent file + corresponding `references/output-format.md` |
| Add detection algorithm | Add Detection Algorithm section to the rule's markdown body |

## Integration

### dev-tooling Plugin (Required)

MCP tools follow pattern: `mcp__plugin_dev-tooling_php-tooling__<tool_name>`

Fixer agent references via frontmatter:
```yaml
tools: Glob, Grep, Read, Edit, mcp__plugin_dev-tooling_php-tooling__phpstan_analyze, mcp__plugin_dev-tooling_php-tooling__phpunit_run, mcp__plugin_dev-tooling_php-tooling__ecs_check, mcp__plugin_dev-tooling_php-tooling__ecs_fix, mcp__plugin_test-writing_test-rules__list_rules, mcp__plugin_test-writing_test-rules__get_rules
```

### test-rules MCP Server (Bundled)

Serves 46 test writing rules with `mcp__plugin_test-writing_test-rules__list_rules`, `mcp__plugin_test-writing_test-rules__get_rules`, and `mcp__plugin_test-writing_test-rules__resolve_legacy` tools. Configured in `.mcp.json`.

MCP tools follow pattern: `mcp__plugin_test-writing_test-rules__<tool_name>`

**Tools**:
- `mcp__plugin_test-writing_test-rules__list_rules` — Discover applicable rules by test_type, test_category, group, scope, enforce level
- `mcp__plugin_test-writing_test-rules__get_rules` — Get full rule content by ID (supports both new IDs and legacy codes)
- `mcp__plugin_test-writing_test-rules__resolve_legacy` — Map legacy E/W/I codes to current rule IDs

## External References

- [Shopware PHPUnit Testing Docs](https://developer.shopware.com/docs/guides/plugins/plugins/testing/php-unit)
- [PHPUnit Documentation](https://phpunit.de/documentation.html)
- [PHPStan Documentation](https://phpstan.org/user-guide/getting-started)
