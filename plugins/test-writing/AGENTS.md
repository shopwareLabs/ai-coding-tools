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
| Integration Generator | Integration test creation (controller/route, scheduled-task, message-handler, indexer, DAL-flow, multi-service) | `skills/phpunit-integration-test-generation/SKILL.md` |
| Integration Reviewer | Integration test compliance analysis (assumes correct placement) | `skills/phpunit-integration-test-reviewing/SKILL.md` |
| Integration→Unit Migrator | User-invoked placement audit + migration | `skills/phpunit-integration-to-unit-migrating/SKILL.md` |

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
│   ├── design/DESIGN-{001..010}.md
│   ├── isolation/ISOLATION-{001..006}.md
│   ├── provider/PROVIDER-{001..005}.md
│   ├── unit/UNIT-{001..010}.md
│   ├── migration/MIGRATION-{001..008}.md
│   ├── integration/INTEGRATION-{001..008}.md
│   └── placement/PLACEMENT-{001..008}.md
├── mcp-server-test-rules/
│   ├── server.sh
│   ├── config.json
│   ├── tools.json
│   └── lib/{common,get}.sh
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
    ├── phpunit-unit-test-reconciling/
    │   ├── SKILL.md
    │   └── references/{reconciliation-rules,output-format}.md
    ├── phpunit-unit-test-team-reviewing/
    │   ├── SKILL.md
    │   └── references/{input-resolution,workflow-design,agent-guardrails,reviewer-allocation,red-team-context,consensus-and-verdicts,report-format,error-handling}.md
    ├── phpunit-migration-test-generation/
    │   ├── SKILL.md
    │   ├── references/{source-analysis,output-format}.md
    │   └── templates/migration-test.md
    ├── phpunit-migration-test-reviewing/
    │   ├── SKILL.md
    │   └── references/output-format.md
    ├── phpunit-integration-test-generation/
    │   ├── SKILL.md
    │   ├── references/{source-analysis,output-format}.md
    │   └── templates/integration-test.md
    ├── phpunit-integration-test-reviewing/
    │   ├── SKILL.md
    │   └── references/output-format.md
    ├── phpunit-integration-to-unit-migrating/
    │   ├── SKILL.md
    │   └── references/{refactoring-patterns,output-format}.md
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

### Integration Test Generation (without orchestrator)

```
User Request (source file in src/)
    ↓
test-writing:phpunit-integration-test-generation (Skill, context: fork)
    ↓
Forks into test-writing:test-generator (Agent)
    ↓
Agent validates input → Skill detects integration pattern
    │
    ├── Pattern detected → applies template → writes tests/integration/... → validates
    └── No pattern (unit-shape SUT) → returns SKIPPED, points at phpunit-unit-test-generation
```

### Integration Test Review (without orchestrator)

```
Agent(test-writing:test-reviewer)
    ↓
Invokes test-writing:phpunit-integration-test-reviewing (Skill)
    ↓
Skill workflow executes → Returns structured report

If INTEGRATION-008 smoke check fires:
    Report includes one-line placement hint pointing at
    test-writing:phpunit-integration-to-unit-migrating
    (user must invoke it explicitly — never auto-routed)
```

### Integration-to-Unit Migration (user-invoked, separate workflow)

```
User Request ("audit integration tests in tests/integration/Core/...")
    ↓
test-writing:phpunit-integration-to-unit-migrating (Skill, inline)
    │
    ├── Phase 1: Scope resolution (file / directory / PR / branch)
    ├── Phase 2: SUT contract articulation (REQUIRED gate per test class)
    ├── Phase 3: Load placement + integration rules via MCP
    ├── Phase 4: Apply PLACEMENT-001..008 per method (PLACEMENT-008 veto first)
    ├── Phase 5: Bucket report + AskUserQuestion confirmation
    ├── Phase 6: Execute migrations (one of 6 refactoring patterns per test)
    └── Phase 7: Migration report
```

### Team Review (Workflow-Based, Multi-Agent)

```
User Request (file paths, commits, branches, PRs, directories)
    ↓
test-writing:phpunit-unit-test-team-reviewing (Skill, inline)
    │
    ├── Phase 0: Confirm scope + cost (AskUserQuestion; offer single-reviewer fallback)
    ├── Phase 1: Resolve input → file manifest (AskUserQuestion for ambiguity)
    ├── Phase 2: Compose review design (reads 5 design references; manifest fixed from Phase 1)
    ├── Phase 3: Run the review via the Workflow tool
    │       │
    │       ├── Pre-run collect (inline): per-file measurements + Track B digest/fingerprint
    │       ├── Wave 0: Independent review (3 reviewers/unit; Track A file or Track B shard/whole-class/digest) + adversary impressions (parallel)
    │       ├── Wave 1: Peer reconciliation — reviewers reconcile against peers' findings
    │       │          (reconciling sub-skill, peer mode; no peer-to-peer messaging)
    │       │          [optional 2nd pass if unresolved disputes remain; max 2 passes total]
    │       ├── Preliminary consensus (2-of-3 majority per file)
    │       ├── [conditional] Wave 2: Red team — adversaries challenge preliminary consensus
    │       ├── [conditional] Wave 3: Defense — reviewers reconcile against adversary challenges
    │       │          (reconciling sub-skill, adversary mode)
    │       ├── Cross-file consistency agent (dedicated; sole source of cross-file findings)
    │       └── Verdicts — final consensus merge, adversary-impact assembly, result
    └── Phase 4: Render report from result
```

**Fix-application fidelity contract (for a future team-review fix phase).** Team review is read-only — it has no fix phase, so there is nothing to change in it today. The report carries each finding's `current`/`suggested` verbatim, and the merge keeps the most complete `suggested` per finding — the superset suggestion, or a combination of genuinely distinct sub-actions (consensus-and-verdicts.md, "Remediation payload"). The only fix-applier in the plugin is the `phpunit-unit-test-writing` orchestrator (Phase 4), which applies the reviewer's `suggested` in full and gates on the static/compile checks. If a team-review fix phase is ever built, it MUST (i) pass the consensus `suggested` to the fixer **verbatim**, never a paraphrase, and (ii) run a compile/static check (PHPStan/PHPUnit/ECS via dev-tooling MCP) before reporting a fix done.

### Rule Discovery Flow

```
Reviewing Skill
    ↓
Phases 3-7: mcp__plugin_test-writing_test-rules__get_rules(group={group}, test_type=unit, test_category={detected}) per group
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

**Purpose**: Generic test generator. Used as execution environment for generation skills via `context: fork` — do not invoke directly. Supports unit tests (tests/unit/), migration tests (tests/migration/), and integration tests (tests/integration/). File-write scope is enforced per-skill in the invoking SKILL.md.

**Validates**: single file, exists, is PHP class (not interface/trait), in `src/`

**Output**: Defined by the invoking skill's output contract.

**Model**: Sonnet | **Mode**: acceptEdits

**Tools**: Read, Grep, Glob, Write, Edit, + dev-tooling MCP tools

### test-reviewer

**Purpose**: Read-only test reviewer. Spawned per wave by the team-reviewing workflow or a standalone orchestrator. Invokes reviewing and reconciling skills.

**Output**: Defined by the invoking skill's output contract.

**Model**: Sonnet | **Mode**: none (read-only, no edit permissions)

**Tools**: Glob, Grep, Read, Skill, mcp__plugin_test-writing_test-rules__get_rules

### test-adversary

**Purpose**: Adversarial test reviewer for consensus stress-testing. Spawned per wave by the team-reviewing workflow. Invokes adversarial reviewing skill.

**Output**: Defined by the invoking skill's output contract.

**Model**: Sonnet | **Mode**: none (read-only, no edit permissions)

**Tools**: Glob, Grep, Read, Skill, mcp__plugin_test-writing_test-rules__get_rules

## Skills

### phpunit-unit-test-writing (Orchestrator)

Manages complete workflow from generation through review and fix loop to final report.

**Features**: Sequential processing, inline fix loop (max 4 iterations) with oscillation detection, user escalation on warnings/oscillation

**Tools**: Skill, Edit, Read, Glob, TodoWrite, AskUserQuestion, + dev-tooling MCP tools (for fix-loop validation)

### phpunit-unit-test-generation

Generates Shopware-compliant PHPUnit unit tests.

**Features**: Category detection (A-E), test requirement rules, template-based generation, PHPStan/PHPUnit validation

### phpunit-unit-test-reviewing

Validates tests against Shopware conventions using MCP-driven rule discovery. Accepts optional method scope for focused reviews of changed/added methods.

**Features**: MCP-driven review by rule group (convention → design → unit → isolation → provider), dynamic rule loading by category, detection algorithms loaded from rule files, method-scoped review mode, optional `review_unit` rule-track filter (method / class-structure / class-bodies, single or list) and body-free `digest` mode for the team-review decomposition tracks

### phpunit-unit-test-adversarial-reviewing

Adversarial review of test consensus with independent intuitive scan before consensus exposure.

**Features**: Two-phase cognitive model (intuition then evidence), independent pre-consensus assessment, structured comparison strategies, evidence-backed promotion gate, cross-file inconsistency detection

### phpunit-unit-test-reconciling (internal sub-skill)

Re-evaluates review findings against incoming critique in one of two modes. `peer` mode: reconcile own findings against co-reviewers' findings on shared files (findings supplied in-prompt; no peer-to-peer messaging). `adversary` mode: reconcile own stance against adversary challenges. Evidence decides every disposition.

**User-invocable**: no — invoked only by the team-reviewing workflow via spawned reviewer agents

**Tools**: Read, Glob, Grep, mcp__plugin_test-writing_test-rules__get_rules

### phpunit-unit-test-team-reviewing

Workflow-based team review. Resolves input to a file manifest, composes a multi-agent review adapted to that manifest, runs it via the Workflow tool, and renders the result into a report.

**Features**: Flexible input resolution (files, commits, branches, PRs, directories); 3 independent reviewers per unit, 2-of-3 majority consensus per track; one unit per reviewer (no file bundling); large files decomposed by `review_unit` into method-shards (≤ M each) plus a whole-class or class-structure-digest track (Track A for `L ≤ T`, Track B above), with a `L > C` "split this test class" escape; adversaries scale as ⌈N/K_adv⌉; auto-chunking above G reviewer agents with one global cross-file pass; conditional red team (Wave 2) + defense (Wave 3) based on peer-contention signal; dedicated cross-file consistency agent (fingerprint input); adaptation points for a second peer pass (max 2 total), targeted reviewer widening (+2 per contested unit), and per-finding arbitration

**Tools**: Bash, Read, Glob, Grep, AskUserQuestion, Workflow, mcp__plugin_gh-tooling_gh-tooling

### phpunit-integration-test-generation

Generates Shopware-compliant PHPUnit integration tests for source classes whose contract requires wired-up code. Forks into `test-generator` via `context: fork`.

**Features**: Source-analysis pattern detection (controller/route, scheduled-task, message-handler, indexer, DAL-flow, multi-service), single template with conditional sections calibrated against recent Shopware integration tests (realtime indexer flow, direct scheduled-task invocation, `IdsCollection`-based ID management, generic `EntityRepository<XxxCollection>` PHPDoc typing), conservative fallback to `phpunit-unit-test-generation` when the SUT is unit-shape, PHPStan/PHPUnit/ECS validation loop with max 3 iterations.

### phpunit-integration-test-reviewing

Reviews integration tests in `tests/integration/` against the integration ruleset (INTEGRATION-001..008). Assumes correct placement.

**Features**: MCP-driven review via `get_rules(group=integration, test_type=integration)`, single placement smoke check (INTEGRATION-008) emitting an informational hint pointing at the migrating skill — never deliberates on placement inline. Does NOT load `group: placement` rules.

### phpunit-integration-to-unit-migrating

User-invoked audit-and-migrate workflow for integration tests that may belong in `tests/unit/`. Walks PLACEMENT-001..008 per test class with a required SUT-contract articulation gate.

**Features**: Scope resolution (file/directory/PR/branch), per-test SUT contract articulation, PLACEMENT-008 veto-first, four buckets (migrate / split / keep / delete-duplicate), `AskUserQuestion` confirmation gate before execution, 6 codified refactoring patterns (container-fetched service, compiler pass, subscriber, parser, constraint-only validation, DAL materializer). Never auto-invoked.

**Tools**: Glob, Grep, Read, Edit, Write, AskUserQuestion, Bash, mcp__plugin_test-writing_test-rules__get_rules

## Modification Guide

| Task | Edit Files |
|------|------------|
| Add test category | `generation/SKILL.md` + `templates/category-*.md` + `reviewing/references/test-categories.md` |
| Add rule | Create `rules/{group}/RULE-NNN.md` with required `review-unit` and `scoped-review` fields (MCP auto-discovers; both are CI-validated) |
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
| Set rule scoped-review (review-mode axis) | Add `scoped-review: include \| exclude` to rule frontmatter — required and CI-validated (`.github/scripts/validate-review-unit.sh`). `exclude`: skip the rule when the review is scoped to changed/added methods (whole-class concern). `include`: evaluate it in scoped reviews (default for nearly all rules). Drives the `get_rules(scoped_review=true)` filter. |
| Set rule review-unit (minimal evaluation input) | Add `review-unit: method \| class-structure \| class-bodies` to rule frontmatter — required and CI-validated (`.github/scripts/validate-review-unit.sh`). `method`: one test method body + its data provider. `class-structure`: class shape only — member order, signatures, attributes, `#[CoversClass]`, no bodies. `class-bodies`: multiple full method bodies together. Orthogonal to `scoped-review` (the review-mode axis). |
| Change team reviewer count | `team-reviewing/references/reviewer-allocation.md` |
| Change adversary count | `team-reviewing/references/reviewer-allocation.md` (adversary count formula) |
| Modify reconciliation rules | `reconciling/references/reconciliation-rules.md` |
| Change reconciling output format | `reconciling/references/output-format.md` |
| Modify red team protocol | `team-reviewing/references/red-team-context.md` + `adversarial-reviewing/SKILL.md` |
| Change team review report | `team-reviewing/references/report-format.md` |
| Change workflow wave design | `team-reviewing/references/workflow-design.md` |
| Change agent spawn guardrails | `team-reviewing/references/agent-guardrails.md` |
| Change consensus / verdict logic | `team-reviewing/references/consensus-and-verdicts.md` |
| Change adversary agent | `agents/test-adversary.md` (generic — shared by all adversarial reviewing skills) |
| Change team input resolution | `team-reviewing/references/input-resolution.md` |
| Change team error handling | `team-reviewing/references/error-handling.md` |
| Add migration rule | Create `rules/migration/MIGRATION-NNN.md` with required `review-unit` and `scoped-review` fields (MCP auto-discovers; both are CI-validated) |
| Change migration generation template | `generation/templates/migration-test.md` + `generation/SKILL.md` Phase 3 |
| Change migration source analysis | `generation/references/source-analysis.md` + `generation/SKILL.md` Phase 2 |
| Change migration review output | `reviewing/references/output-format.md` |
| Add integration rule | Create `rules/integration/INTEGRATION-NNN.md` with required `review-unit` and `scoped-review` fields (MCP auto-discovers; both are CI-validated) |
| Add integration pattern | `phpunit-integration-test-generation/references/source-analysis.md` + new conditional section in `templates/integration-test.md` |
| Change integration generation pattern detection | `phpunit-integration-test-generation/references/source-analysis.md` + `SKILL.md` Phase 2 |
| Change integration test template | `phpunit-integration-test-generation/templates/integration-test.md` |
| Change integration generation report output | `phpunit-integration-test-generation/references/output-format.md` |
| Add placement reasoning rule | Create `rules/placement/PLACEMENT-NNN.md` with required `review-unit` and `scoped-review` fields (MCP auto-discovers; both are CI-validated; loaded only by `phpunit-integration-to-unit-migrating`) |
| Change integration review output | `phpunit-integration-test-reviewing/references/output-format.md` |
| Add refactoring pattern for migration | `phpunit-integration-to-unit-migrating/references/refactoring-patterns.md` |
| Change migration audit output | `phpunit-integration-to-unit-migrating/references/output-format.md` |

## Integration

### dev-tooling Plugin (Required)

MCP tools follow pattern: `mcp__plugin_dev-tooling_php-tooling__<tool_name>`

Orchestrator and agents reference via frontmatter:
```yaml
tools: ..., mcp__plugin_dev-tooling_php-tooling__phpstan_analyze, mcp__plugin_dev-tooling_php-tooling__phpunit_run, mcp__plugin_dev-tooling_php-tooling__ecs_check, mcp__plugin_dev-tooling_php-tooling__ecs_fix
```

### test-rules MCP Server (Bundled)

Serves test writing rules with `mcp__plugin_test-writing_test-rules__get_rules`. Configured in `.mcp.json`.

MCP tools follow pattern: `mcp__plugin_test-writing_test-rules__<tool_name>`

**Tools**:
- `mcp__plugin_test-writing_test-rules__get_rules` — Get full rule content by ID or metadata filters (test_type, test_category, group, scope, enforce)
- `mcp__plugin_test-writing_test-rules__build_rule_package` — Render the five unit-review groups (convention, design, unit, isolation, provider) once to `$CLAUDE_PLUGIN_DATA/rule-packages/unit-review.md` and return its absolute path. Used at composition time by team review so agents read the catalog instead of fetching it per agent. Output is byte-identical to concatenating `get_rules(group=X)` over the five groups.

## External References

- [Shopware PHPUnit Testing Docs](https://developer.shopware.com/docs/guides/plugins/plugins/testing/php-unit)
- [PHPUnit Documentation](https://phpunit.de/documentation.html)
- [PHPStan Documentation](https://phpstan.org/user-guide/getting-started)
