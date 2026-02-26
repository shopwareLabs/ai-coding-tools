@README.md

## Quick Reference

| Component | Purpose | File |
|-----------|---------|------|
| Orchestrator | End-to-end workflow | `skills/phpunit-unit-test-writing/SKILL.md` |
| Generator | Test creation (categories A-E) | `skills/phpunit-unit-test-generation/SKILL.md` |
| Reviewer | MCP-driven compliance analysis by rule group | `skills/phpunit-unit-test-reviewing/SKILL.md` |

**Agents:**
| Agent | Purpose | Permissions |
|-------|---------|-------------|
| `test-generator` | Execution environment for generation skills (generic) | acceptEdits |
| `test-reviewer` | Read-only analysis (generic) | none (read-only) |

**MCP Tools (used by orchestrator for fix-loop validation and by agents in forked contexts, NEVER Bash equivalents):**
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
│   ├── test-generator.md
│   └── test-reviewer.md
├── rules/
│   ├── convention/CONV-{001..018}.md
│   ├── design/DESIGN-{001..009}.md
│   ├── isolation/ISOLATION-{001..006}.md
│   ├── provider/PROVIDER-{001..005}.md
│   └── unit/UNIT-{001..008}.md
├── mcp-server-test-rules/
│   ├── server.sh
│   ├── config.json
│   ├── tools.json
│   └── lib/{common,list,get}.sh
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
test-writing:phpunit-unit-test-writing (Orchestrator Skill, inline in main conversation)
    │
    ├── Phase 1: Skill(test-writing:phpunit-unit-test-generation)
    │       → context: fork → test-generator agent
    │       → Returns {test_path, status, category}
    │
    ├── Phase 2: Skill(test-writing:phpunit-unit-test-reviewing)
    │       → context: fork → test-reviewer agent
    │       → Returns {status, errors, warnings}
    │
    ├── Phase 3: Fix Loop (inline, max 4 iterations)
    │       Apply fixes (Edit) → ECS/PHPStan/PHPUnit (MCP) →
    │       Re-invoke Skill(test-writing:phpunit-unit-test-reviewing) → track oscillation
    │
    ├── Phase 4: User Decision on Warnings
    └── Phase 5: Final Report
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

**Note:** MCP tools are used by the orchestrator skill for fix-loop validation and by agents in forked contexts.

## Agents

### test-generator

**Purpose**: Generic test generator. Used as execution environment for generation skills via `context: fork` — do not invoke directly.

**Validates**: single file, exists, is PHP class (not interface/trait), in `src/`

**Output**: Defined by the invoking skill's output contract.

**Model**: Sonnet | **Mode**: acceptEdits

**Tools**: Read, Grep, Glob, Write, Edit, + dev-tooling MCP tools

### test-reviewer

**Purpose**: Generic read-only test reviewer. Used as execution environment for reviewing skills via `context: fork` — do not invoke directly.

**Validates**: single file, exists, ends with `*Test.php`

**Output**: Defined by the invoking skill's output contract.

**Model**: Sonnet | **Mode**: none (read-only, no edit permissions)

**Tools**: Glob, Grep, Read, mcp__plugin_test-writing_test-rules__list_rules, mcp__plugin_test-writing_test-rules__get_rules

## Skills

### phpunit-unit-test-writing (Orchestrator)

Manages complete workflow from generation through review and fix loop to final report.

**Features**: Sequential processing, inline fix loop (max 4 iterations) with oscillation detection, user escalation on warnings/oscillation

**Tools**: Skill, Edit, Read, Glob, TodoWrite, AskUserQuestion, + dev-tooling MCP tools (for fix-loop validation)

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
| Modify fix iterations | `writing/SKILL.md` Phase 3 (max iterations in fix loop) |
| Update oscillation handling | `writing/SKILL.md` Phase 3 + `writing/references/oscillation-handling.md` |
| Change generation template | `generation/templates/category-*.md` + `generation/SKILL.md` Phase 3 |
| Add Shopware stub | `rules/unit/UNIT-003.md` + `generation/references/shopware-stubs.md` + `generation/templates/*` |
| Change report format | `writing/references/report-formats.md` |
| Change generator agent | `agents/test-generator.md` (generic — shared by all generation skills) |
| Change reviewer agent | `agents/test-reviewer.md` (generic — shared by all reviewing skills) |
| Change output contracts | Skill file + corresponding `references/output-format.md` |
| Add detection algorithm | Add Detection Algorithm section to the rule's markdown body |

## Integration

### dev-tooling Plugin (Required)

MCP tools follow pattern: `mcp__plugin_dev-tooling_php-tooling__<tool_name>`

Orchestrator and agents reference via frontmatter:
```yaml
tools: ..., mcp__plugin_dev-tooling_php-tooling__phpstan_analyze, mcp__plugin_dev-tooling_php-tooling__phpunit_run, mcp__plugin_dev-tooling_php-tooling__ecs_check, mcp__plugin_dev-tooling_php-tooling__ecs_fix
```

### test-rules MCP Server (Bundled)

Serves test writing rules with `mcp__plugin_test-writing_test-rules__list_rules` and `mcp__plugin_test-writing_test-rules__get_rules` tools. Configured in `.mcp.json`.

MCP tools follow pattern: `mcp__plugin_test-writing_test-rules__<tool_name>`

**Tools**:
- `mcp__plugin_test-writing_test-rules__list_rules` — Discover applicable rules by test_type, test_category, group, scope, enforce level
- `mcp__plugin_test-writing_test-rules__get_rules` — Get full rule content by ID or metadata filters (test_type, test_category, group, scope, enforce)

## External References

- [Shopware PHPUnit Testing Docs](https://developer.shopware.com/docs/guides/plugins/plugins/testing/php-unit)
- [PHPUnit Documentation](https://phpunit.de/documentation.html)
- [PHPStan Documentation](https://phpstan.org/user-guide/getting-started)
