@README.md

## Quick Reference

| Component | Purpose | File |
|-----------|---------|------|
| Orchestrator | End-to-end workflow | `skills/phpunit-unit-test-writing/SKILL.md` |
| Generator | Test creation (categories A-E) | `skills/phpunit-unit-test-generation/SKILL.md` |
| Reviewer | MCP-driven compliance analysis by rule group | `skills/phpunit-unit-test-reviewing/SKILL.md` |
| Adversarial Reviewer | Consensus stress-testing with independent scan | `skills/phpunit-unit-test-adversarial-reviewing/SKILL.md` |
| Team Reviewer | Consensus-based multi-reviewer analysis | `skills/phpunit-unit-test-team-reviewing/SKILL.md` |
| Migration Generator | Migration test creation | `skills/phpunit-migration-test-generation/SKILL.md` |
| Migration Reviewer | Migration test compliance analysis | `skills/phpunit-migration-test-reviewing/SKILL.md` |

**Agents:**
| Agent | Purpose | Permissions |
|-------|---------|-------------|
| `test-generator` | Execution environment for generation skills (generic) | acceptEdits |
| `test-reviewer` | Read-only analysis (generic) | none (read-only) |
| `test-adversary` | Adversarial review execution environment (generic) | none (read-only) |

**MCP Tools (used by orchestrator for fix-loop validation and by spawned agents, NEVER Bash equivalents):**
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
│   ├── test-reviewer.md
│   └── test-adversary.md
├── rules/
│   ├── convention/CONV-{001..018}.md
│   ├── design/DESIGN-{001..009}.md
│   ├── isolation/ISOLATION-{001..006}.md
│   ├── provider/PROVIDER-{001..005}.md
│   ├── unit/UNIT-{001..008}.md
│   └── migration/MIGRATION-{001..008}.md
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
    ├── phpunit-unit-test-reviewing/
    │   ├── SKILL.md
    │   └── references/{test-categories,output-format}.md
    ├── phpunit-unit-test-adversarial-reviewing/
    │   ├── SKILL.md
    │   └── references/{intuitive-scan-guidance,comparison-strategies,output-format}.md
    ├── phpunit-unit-test-debating/
    │   ├── SKILL.md
    │   └── references/{debate-rules,output-format}.md
    ├── phpunit-unit-test-defending/
    │   ├── SKILL.md
    │   └── references/{defense-rules,output-format}.md
    ├── phpunit-unit-test-team-reviewing/
    │   ├── SKILL.md
    │   └── references/{error-handling,input-resolution,message-formats,red-team-context,report-format,reviewer-allocation}.md
    ├── phpunit-migration-test-generation/
    │   ├── SKILL.md
    │   ├── references/{source-analysis,output-format}.md
    │   └── templates/migration-test.md
    ├── phpunit-migration-test-reviewing/
    │   ├── SKILL.md
    │   └── references/output-format.md
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
    │       → Returns {test_path, status, category, skip_type}
    │
    ├── Phase 2: Coverage Exclusion Offer (if SKIPPED with skip_type: no_logic)
    │       → Offers to add trivial files to phpunit.xml.dist <exclude>
    │
    ├── Phase 3: Agent(test-writing:test-reviewer)
    │       → Invokes reviewing skill → Returns {status, errors, warnings}
    │
    ├── Phase 4: Fix Loop (inline, max 4 iterations)
    │       Apply fixes (Edit) → ECS/PHPStan/PHPUnit (MCP) →
    │       Re-invoke Agent(test-writing:test-reviewer) → track oscillation
    │
    ├── Phase 5: User Decision on Warnings
    └── Phase 6: Final Report
```

### Direct Review (without orchestrator)

```
Agent(test-writing:test-reviewer)
    ↓
Invokes test-writing:phpunit-unit-test-reviewing (Skill)
    ↓
Skill workflow executes → Returns structured report
```

### Migration Test Generation (without orchestrator)

```
User Request (migration source file)
    ↓
test-writing:phpunit-migration-test-generation (Skill, context: fork)
    ↓
Forks into test-writing:test-generator (Agent)
    ↓
Agent validates input → Skill workflow executes → Returns structured report
```

### Migration Test Review (without orchestrator)

```
Agent(test-writing:test-reviewer)
    ↓
Invokes test-writing:phpunit-migration-test-reviewing (Skill)
    ↓
Skill workflow executes → Returns structured report
```

Note: Migration reviewing follows the v3.0.0 pattern — pure instruction set, caller spawns agent.

### Team Review (Wave-Based, Agent Teams)

```
User Request (file paths, commits, branches, PRs, directories)
    ↓
test-writing:phpunit-unit-test-team-reviewing (Skill, inline)
    │
    ├── Phase 0: Prerequisites Check (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
    ├── Phase 1: Input Resolution
    ├── Phase 2: Team Setup (TeamCreate, calculate R reviewers + A adversaries)
    ├── Phase 3: Wave 0 — reviewers invoke reviewing skill + adversaries form impressions
    ├── Phase 4: Wave 1 — reviewers invoke debating skill (peer-to-peer via SendMessage)
    ├── Phase 5: Red Team Skip Evaluation
    ├── Phase 6: Wave 2 — adversaries invoke adversarial reviewing skill
    ├── Phase 7: Wave 3 — reviewers invoke defending skill
    ├── Phase 8: Verdicts & Report (consensus merge, cross-file consistency, adversary impact)
    └── Phase 9: Cleanup (TeamDelete)
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

**Note:** MCP tools are used by the orchestrator skill for fix-loop validation and by spawned agents.

## Agents

### test-generator

**Purpose**: Generic test generator. Used as execution environment for generation skills via `context: fork` — do not invoke directly. Supports unit tests (tests/unit/) and migration tests (tests/migration/).

**Validates**: single file, exists, is PHP class (not interface/trait), in `src/`

**Output**: Defined by the invoking skill's output contract.

**Model**: Sonnet | **Mode**: acceptEdits

**Tools**: Read, Grep, Glob, Write, Edit, + dev-tooling MCP tools

### test-reviewer

**Purpose**: Read-only test reviewer. Spawned per wave by orchestrators. Invokes reviewing, debating, or defending skills.

**Output**: Defined by the invoking skill's output contract.

**Model**: Sonnet | **Mode**: none (read-only, no edit permissions)

**Tools**: Glob, Grep, Read, SendMessage, Skill, mcp__plugin_test-writing_test-rules__list_rules, mcp__plugin_test-writing_test-rules__get_rules

### test-adversary

**Purpose**: Adversarial test reviewer for consensus stress-testing. Spawned per wave by team-reviewing orchestrator. Invokes adversarial reviewing skill.

**Output**: Defined by the invoking skill's output contract.

**Model**: Sonnet | **Mode**: none (read-only, no edit permissions)

**Tools**: Glob, Grep, Read, Skill, mcp__plugin_test-writing_test-rules__list_rules, mcp__plugin_test-writing_test-rules__get_rules

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

### phpunit-unit-test-adversarial-reviewing

Adversarial review of test consensus with independent intuitive scan before consensus exposure.

**Features**: Two-phase cognitive model (intuition then evidence), independent pre-consensus assessment, structured comparison strategies, evidence-backed promotion gate, cross-file inconsistency detection

### phpunit-unit-test-debating

Peer-to-peer debate of review findings within an Agent Teams wave. Receives own and peer findings, debates with co-reviewers via SendMessage (max 2 rounds), outputs final stance.

**Features**: Peer-to-peer debate via SendMessage, bounded rounds, detection algorithm citation, cross-file references

### phpunit-unit-test-defending

Defense against adversary challenges. Receives adversary challenges, evaluates each on merits, outputs defense stance with adversary impact tracking.

**Features**: Evidence-based challenge evaluation, finding re-adoption, adversary impact annotations

### phpunit-unit-test-team-reviewing

Wave-based team review using Claude Code Agent Teams. Spawns fresh agents per wave with single-task instructions. 4 waves: independent review, peer-to-peer debate, adversarial red team, defense.

**Features**: Flexible input resolution (files, commits, branches, PRs, directories), variable reviewer pool (3-5) with balanced round-robin file assignment, peer-to-peer debate via SendMessage (max 2 rounds), red team round with 1-2 adversary agents, defense round with adversary impact tracking, majority voting with dissent annotations, per-file consensus reports with cross-file consistency analysis

**Prerequisites**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

**Tools**: Bash, TeamCreate, TeamDelete, Agent, SendMessage, Read, Glob, Grep, AskUserQuestion, test-rules MCP tools, gh-tooling MCP tools (for PR input)

## Modification Guide

| Task | Edit Files |
|------|------------|
| Add test category | `generation/SKILL.md` + `templates/category-*.md` + `reviewing/references/test-categories.md` |
| Add rule | Create `rules/{group}/RULE-NNN.md` (MCP auto-discovers; no other files need updating) |
| Modify existing rule | Edit `rules/{group}/RULE-NNN.md` (content served by MCP) |
| Change category detection | `generation/SKILL.md` Phase 1 + `reviewing/references/test-categories.md` |
| Modify fix iterations | `writing/SKILL.md` Phase 4 (max iterations in fix loop) |
| Update oscillation handling | `writing/SKILL.md` Phase 4 + `writing/references/oscillation-handling.md` |
| Modify coverage exclusion offer | `writing/SKILL.md` Phase 2 |
| Change generation template | `generation/templates/category-*.md` + `generation/SKILL.md` Phase 3 |
| Add Shopware stub | `rules/unit/UNIT-003.md` + `generation/references/shopware-stubs.md` + `generation/templates/*` |
| Change report format | `writing/references/report-formats.md` |
| Change generator agent | `agents/test-generator.md` (generic — shared by all generation skills) |
| Change reviewer agent | `agents/test-reviewer.md` (generic — shared by all reviewing skills) |
| Change output contracts | Skill file + corresponding `references/output-format.md` |
| Add detection algorithm | Add Detection Algorithm section to the rule's markdown body |
| Change team reviewer count | `team-reviewing/references/reviewer-allocation.md` |
| Change adversary count | `team-reviewing/references/reviewer-allocation.md` (adversary count formula) |
| Modify debate rules | `debating/references/debate-rules.md` |
| Modify defense rules | `defending/references/defense-rules.md` |
| Change debate output format | `debating/references/output-format.md` |
| Change defense output format | `defending/references/output-format.md` |
| Modify red team protocol | `team-reviewing/references/red-team-context.md` + `adversarial-reviewing/SKILL.md` |
| Change team review report | `team-reviewing/references/report-format.md` |
| Change team message formats | `team-reviewing/references/message-formats.md` |
| Change adversary agent | `agents/test-adversary.md` (generic — shared by all adversarial reviewing skills) |
| Change team input resolution | `team-reviewing/references/input-resolution.md` |
| Change team error handling | `team-reviewing/references/error-handling.md` |
| Add migration rule | Create `rules/migration/MIGRATION-NNN.md` (MCP auto-discovers) |
| Change migration generation template | `generation/templates/migration-test.md` + `generation/SKILL.md` Phase 3 |
| Change migration source analysis | `generation/references/source-analysis.md` + `generation/SKILL.md` Phase 2 |
| Change migration review output | `reviewing/references/output-format.md` |

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
