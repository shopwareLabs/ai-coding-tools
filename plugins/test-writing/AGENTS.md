@README.md

## 🧭 Quick Reference

| Component | Purpose | File |
|-----------|---------|------|
| Orchestrator | End-to-end workflow | `skills/phpunit-unit-test-writing/SKILL.md` |
| Generator | Test creation (categories A-E) | `skills/phpunit-unit-test-generation/SKILL.md` |
| Reviewer | MCP-driven compliance analysis by rule group | `skills/phpunit-unit-test-reviewing/SKILL.md` |
| Adversarial Reviewer | Consensus stress-testing with independent scan | `skills/phpunit-test-adversarial-reviewing/SKILL.md` |
| Team Reviewer | Consensus-based multi-reviewer analysis | `skills/phpunit-test-team-reviewing/SKILL.md` |
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

## 🗂️ Directory Structure

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
│   ├── convention/CONV-{001..014,016,017}.md
│   ├── design/DESIGN-{001..010}.md
│   ├── isolation/ISOLATION-{001..006}.md
│   ├── provider/PROVIDER-{001..005}.md
│   ├── unit/UNIT-{001,003,004,007..010}.md
│   ├── migration/MIGRATION-{001..009}.md
│   ├── integration/INTEGRATION-{001..008}.md
│   └── placement/PLACEMENT-{001..008}.md
├── mcp-server-test-rules/
│   ├── server.sh
│   ├── config.json
│   ├── tools.json
│   └── lib/{build,common,get,survival}.sh
├── shared/
│   └── mcpserver_core.sh
└── skills/
    ├── phpunit-unit-test-writing/
    │   ├── SKILL.md
    │   └── references/{report-formats,oscillation-handling}.md
    ├── phpunit-unit-test-generation/
    │   ├── SKILL.md
    │   ├── references/{category-detection,common-patterns,deprecation-guards,essential-rules,exception-patterns,mocking-patterns,output-format,shopware-stubs,test-requirement-rules,validation-error-mapping}.md
    │   └── templates/category-{a,b,c,d,e}-*.md
    ├── phpunit-unit-test-reviewing/
    │   ├── SKILL.md
    │   └── references/{test-categories,output-format}.md
    ├── phpunit-test-adversarial-reviewing/
    │   ├── SKILL.md
    │   └── references/{intuitive-scan-guidance,comparison-strategies,output-format}.md
    ├── phpunit-test-reconciling/
    │   ├── SKILL.md
    │   └── references/{reconciliation-rules,output-format}.md
    ├── phpunit-test-team-reviewing/
    │   ├── SKILL.md
    │   ├── workflow/team-review.workflow.mjs    # committed parameterized Workflow script (reads its manifest from `const manifest = args;`)
    │   ├── workflow/build-run-script.sh         # splices the on-disk manifest into a flat run-script; launched via scriptPath (no args)
    │   ├── workflow/verify-method-counts.sh     # deterministic Phase-1 gate: re-counts test methods, corrects manifest entries
    │   ├── workflow/verify-finding-evidence.sh  # deterministic Phase-5 gate: demotes findings whose `current` block is not in the file
    │   └── references/{input-resolution,workflow-design,agent-guardrails,reviewer-allocation,red-team-context,consensus-and-verdicts,report-format,error-handling,fix-application}.md
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

## 🏗️ Architecture

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

### Team Review (Workflow-Based, Multi-Agent Campaign)

```
User Request (file paths, commits, branches, PRs, directories)
    ↓
test-writing:phpunit-test-team-reviewing (Skill, inline — the campaign driver)
    │
    ├── Phase 0: Confirm scope + cost (AskUserQuestion; offer single-reviewer fallback)
    ├── Phase 1: Resolve input → file list; classify each path (test_type=unit|integration|migration); fan out one general-purpose/haiku subagent per file to extract its entry — measurements, source_paths, fingerprint, Track B L>C digest, or ambiguous-flag (AskUserQuestion resolves ambiguity)
    ├── Phase 2: Project agent cost — launch the workflow in dry_run mode (no agents) for a per-preset table incl. review/adversarial agent bounds and per_file shard weights; select preset + model combo via AskUserQuestion (defaults standard / sonnet-opus); partition into review shards ≤ S_max=250 projected agents each (round-robin by descending weight; files never straddle shards)
    ├── Phase 3: Assemble the campaign on disk (mktemp dir) — campaign.json (stage list + statuses), one args-shard-k.json per shard (mode=review; per-type rule packages via build_rule_package, spliced by path with jq --rawfile; preset/models carried in), args-signals.json (mode=signals; no catalogs); manifests fixed
    ├── Phase 4: Execute — build each stage's flat run-script (workflow/build-run-script.sh splices the manifest into a top-level copy of team-review.workflow.mjs) → launch via Workflow tool scriptPath (no args)
    │       ├── signals run (mode=signals, concurrent with shard 1): cross-file consistency agent (whole changeset; sole source of cross-file findings) + changeset adoption signal (diff runs only)
    │       ├── review shards (mode=review), strictly sequential; each result persisted to $CAMPAIGN before the next launch; a partial (circuit-breaker) or failed shard stops the campaign
    │       │       ├── Wave 0: Independent review (3 reviewers/unit; per-type reviewing sub-skill; Track A file or Track B shard/whole-class/digest, narrow-diff downgrade to digest) + adversary impressions (parallel)
    │       │       ├── Wave 1: Peer reconciliation (reconciling sub-skill, peer mode; no peer-to-peer messaging) [optional 2nd pass; max 2 total]
    │       │       ├── Targeted widening (+2 reviewers per sharply-divided unit)
    │       │       └── Consensus (2-of-3 per unit → per file; a unit with < 2 live reviewer stances throws and fails the shard) → per-file consensus verdicts + persisted adversarial_input payloads + persisted guard refusals + exported adversarial-gate signal
    │       └── every mode: pre-flight cap assert (≤ 900 agents), storm-suppressed single retry, wave-level circuit breaker → structured partial result
    ├── Phase 5: Merge (deterministic, in-skill) — combined verdicts + SUT-coverage map + integration-to-unit placement flags (both computed here, not by a run)
    ├── Phase 6: Adversarial gate (AskUserQuestion: kept/contested totals, skip signals, projected bound) → on run: args-adversarial.json (mode=adversarial; consensus = the shards' adversarial_input payloads) → Wave 2 red team → Wave 3 defense → arbitration (hard caps arbFile/arbMax, must-fix first) → final per-file verdicts supersede consensus-stage ones
    └── Phase 7: Render combined report from the persisted stage results (per-stage cost lines)
```

**Naming the committed workflow script is allowed — it is not a `skill-writing.md` leak.** `skill-writing.md` forbids a SKILL.md from naming the *context-delivery mechanism* — how content reaches the skill (hooks, injection, `additionalContext`, tool results): "the skill receives content via context; it must not name how." The committed workflow script is the opposite — the skill's **output/action artifact**, spliced by `workflow/build-run-script.sh` into a flat run-script and launched through the allowed `Workflow` tool via `scriptPath`. Naming `workflow/team-review.workflow.mjs` and `workflow/build-run-script.sh` in SKILL.md Phase 4 is naming shipped files and a tool input, exactly like naming any path the skill reads or any MCP tool it calls — not a delivery-mechanism leak. The earlier "blackbox" framing (which forbade naming the script) over-extended that rule to a case it does not govern; this skill names the script deliberately.

**Fix-application fidelity contract (for a future team-review fix phase).** Team review is read-only — it has no fix phase, so there is nothing to change in it today. Every finding carries a `finding_id` (`${rule_id}|${methodId(method) || 'class-level'}`, where `methodId` strips a trailing `(...)` suffix and surrounding whitespace and `class-level` stands in for an absent `method`) — a finding IS the rule it cites in the method it sits in. Neither the line nor any fingerprint of the quoted code takes part, so one defect two reviewers placed at different lines, quoting different extents, or described in `summary` alone is one finding and pools its votes (consensus-and-verdicts.md, "Finding identity"). This over-merges by design, and the two costs are accepted rather than mitigated: two genuinely distinct defects citing the same rule in the same method merge into one record — the rendered descriptive fields belong to one of them while the other's remediation survives only as a `suggested_variants` entry — and the two reviewers count as two votes for the merged record, promoting it to `kept` on a majority neither defect earned alone. `class-level` findings collapse hardest, one bucket per rule per file. The asymmetry is the argument: over-merging costs separation between two defects that both still render, while a fingerprint made each reviewer's phrasing its own single-vote group, and single-vote groups are contested and excluded from the body. Do not reintroduce a similarity threshold to split them apart — a threshold reintroduces that fragmentation non-deterministically. The report carries each finding's `current`/`suggested` verbatim, and the merge discards no stance's remediation: every distinct `suggested` survives in `suggested_variants` (duplicates collapsed under whitespace normalization, the rest ordered longest first), `suggested` is the first and most complete of them, and `location`, `title`, `summary`, `current`, and `method` come from the record that proposed it, so `current` and `suggested` describe one change (consensus-and-verdicts.md, "Remediation payload"). Per field the precedence is the remediation's owner first, then the record the merge paired it with — the resolved original, or the other side of a union — because an owner is not always required to carry descriptive fields of its own (a defender's `re_adopted`/`adopted_new` entry is schema-required to carry only `finding_id`, `enforce` and `suggested`), and a field it never supplied falls back rather than being dropped. Absent means the property is missing, never that it is empty: `current: ""` is a finding that quoted no code and `method: ""` is the `class-level` locator, so both count as the owner's own value and neither borrows the paired record's. `title` is the one field that never takes the paired record's value directly — an owner without one gets a title derived from whichever `summary` won the fallback, so the title always describes the summary actually rendered. The only fix-applier in the plugin is the `phpunit-unit-test-writing` orchestrator (Phase 4), which applies the reviewer's `suggested` in full and gates on the static/compile checks. If a team-review fix phase is ever built, it MUST (i) pass the consensus `suggested` to the fixer **verbatim**, never a paraphrase, (ii) treat the remaining `suggested_variants` as alternatives to put in front of a human, never as remediations to drop, and (iii) run a compile/static check (PHPStan/PHPUnit/ECS via dev-tooling MCP) before reporting a fix done.

### Rule Discovery Flow

Unit reviewing loads one rule group per phase, filtered by category — A-E is a unit-only axis:

```
phpunit-unit-test-reviewing
    ↓
Phases 3-7: mcp__plugin_test-writing_test-rules__get_rules(group={group}, test_type=unit, test_category={detected}) per group
    ↓
Apply detection algorithms → Record violations with rule IDs and enforce levels
```

Integration and migration reviewing load the composed per-type catalog instead — one call, no `group`, no `test_category`; passing `group` narrows it back to that type's own group and drops every shared convention/design/isolation/provider rule:

```
phpunit-{integration|migration}-test-reviewing
    ↓
Phase 4: mcp__plugin_test-writing_test-rules__get_rules(test_type={integration|migration}, …)
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

## 🤖 Agents

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

## 🎯 Skills

### phpunit-unit-test-writing (Orchestrator)

Manages complete workflow from generation through review and fix loop to final report.

**Features**: Sequential processing, inline fix loop (max 4 iterations) with oscillation detection, user escalation on warnings/oscillation

**Tools**: Skill, Edit, Read, Glob, TodoWrite, AskUserQuestion, + dev-tooling MCP tools (for fix-loop validation)

### phpunit-unit-test-generation

Generates Shopware-compliant PHPUnit unit tests.

**Features**: Category detection (A-E), test requirement rules, template-based generation, PHPStan/PHPUnit validation

### phpunit-unit-test-reviewing

Validates tests against Shopware conventions using MCP-driven rule discovery. Accepts optional method scope for focused reviews of changed/added methods.

**Features**: MCP-driven review by rule group (convention → design → unit → isolation → provider), dynamic rule loading by category, detection algorithms loaded from rule files, method-scoped review mode, optional `review_unit` rule-track filter (method / class-structure / class-bodies, single or list) and body-free `digest` mode for the team-review decomposition tracks, a caller-supplied `baseline` (`pass` / `fail` / `unavailable`, never executed here), and a deletion after-state guard over its own findings via `assert_surviving_tests`

### phpunit-test-adversarial-reviewing

Adversarial review of test consensus (any test type — unit, integration, migration) with independent intuitive scan before consensus exposure.

**Features**: Two-phase cognitive model (intuition then evidence), independent pre-consensus assessment, structured comparison strategies, evidence-backed promotion gate, cross-file inconsistency detection. Type-neutral: receives the full catalog for the file's `test_type` as its inline `## RULES`; selects by rule area (no A–E category requirement for integration/migration).

### phpunit-test-reconciling (internal sub-skill)

Re-evaluates review findings against incoming critique in one of two modes, for any test type. `peer` mode: reconcile own findings against co-reviewers' findings on shared files (findings supplied in-prompt; no peer-to-peer messaging). `adversary` mode: reconcile own stance against adversary challenges. Evidence decides every disposition.

**User-invocable**: no — invoked only by the team-reviewing workflow via spawned reviewer agents

**Tools**: Read, Glob, Grep, mcp__plugin_test-writing_test-rules__get_rules

### phpunit-test-team-reviewing

Sole Workflow-based team reviewer for **unit, integration, and migration** PHPUnit tests over a mixed manifest, driven as a **campaign** of sequential workflow launches. Resolves input to a file list, classifies each path (`test_type`), fans out per-file extraction to parallel general-purpose/haiku subagents (measurements, source resolution, fingerprint, digest), projects the per-preset agent cost via a `dry_run` launch of the workflow (no agents spawned; returns review/adversarial agent bounds and per-file shard weights), selects the preset + model combo informed by it, partitions the manifest into review shards of ≤ 250 projected agents, and assembles every stage's manifest in a campaign directory on disk. Each stage is a flat top-level copy of the committed workflow script (`skills/phpunit-test-team-reviewing/workflow/team-review.workflow.mjs`, spliced via `workflow/build-run-script.sh`, launched through the Workflow tool's `scriptPath`), switched by a manifest `mode`: `signals` (cross-file consistency + adoption, whole changeset, concurrent with shard 1), `review` (consensus per shard, sequential, each result persisted before the next launch), and a **gated** `adversarial` stage (red team + defense + arbitration over the persisted consensus payloads). A deterministic in-skill merge computes the coverage map and placement flags and renders the combined report. Strictly read-only — it never mutates the tests under review. The committed script owns the orchestration; the `references/` provide the run's execution-phase contracts and the adaptation guide.

**Features**: `test_type` is the primary routing axis — per file it selects the rule catalog, the per-type reviewing sub-skill (`phpunit-{unit|integration|migration}-test-reviewing`), the decomposition track, and the adversary-lens `## RULES`. Flexible input resolution (files, commits, branches, PRs, directories); 3 independent reviewers per unit, 2-of-3 majority consensus per track; one unit per reviewer; large files decomposed by `review_unit` into method-shards (≤ M each, coarsened upward for very large classes to bound reviewer count — see reviewer-allocation.md) plus a whole-class or class-structure-digest track (Track A for `L ≤ T`, Track B above), with a `L > C` "split this test class" escape and a narrow-diff downgrade to the digest track; K independent per-file adversaries (one per active lens, `K_adv` = preset lens count), each reading a single file, on the adversary model tier; campaign sharding at S_max=250 with in-run auto-chunking at G as a safety net; per-run pre-flight cap assert, storm-suppressed single retry, and a wave-level circuit breaker returning structured partial results; red team (Wave 2) + defense (Wave 3) behind the campaign's adversarial gate (the review stage exports the skip signal); dedicated cross-file consistency agent (cross-type aware, whole changeset via the signals stage); a deterministic cross-cutting **SUT-coverage map** (`coverage_overlap`) and **integration-to-unit placement flags** (`placement_flags`, informational — never raises status, points at `phpunit-integration-to-unit-migrating`), both computed by the skill's merge step; a changeset **adoption signal** (`adoption_opportunities`, informational — never raises status; diff runs only; flags reviewed peers that could adopt a reusable abstraction the changeset introduced); adaptation points for a second peer pass (max 2 total), targeted reviewer widening (+2 per contested unit), and per-finding arbitration (3 adversary-tier arbiters on a contested must-fix; hard caps `arbFile` per file and `arbMax` per run, must-fix first). Cost/quality is selected per run by a named **preset** (`deep`/`standard`/`lean` — sets C, M, adversary lens count, arbitration caps) and **model combo** (`sonnet-opus`/`haiku-opus`/`haiku-sonnet`), both carried in the manifest and fail-soft to `standard` / `sonnet-opus` (see reviewer-allocation.md).

**Tools**: Bash, Read, Glob, Grep, AskUserQuestion, Workflow, mcp__plugin_test-writing_test-rules__build_rule_package
### phpunit-integration-test-generation

Generates Shopware-compliant PHPUnit integration tests for source classes whose contract requires wired-up code. Forks into `test-generator` via `context: fork`.

**Features**: Source-analysis pattern detection (controller/route, scheduled-task, message-handler, indexer, DAL-flow, multi-service), single template with conditional sections calibrated against recent Shopware integration tests (realtime indexer flow, direct scheduled-task invocation, `IdsCollection`-based ID management, generic `EntityRepository<XxxCollection>` PHPDoc typing), conservative fallback to `phpunit-unit-test-generation` when the SUT is unit-shape, PHPStan/PHPUnit/ECS validation loop with max 3 iterations.

### phpunit-integration-test-reviewing

Reviews integration tests in `tests/integration/` against the integration ruleset (INTEGRATION-001..008). Assumes correct placement.

**Features**: MCP-driven review via `get_rules(test_type=integration)` (the composed catalog — INTEGRATION-001..008 plus every convention/design/isolation/provider rule declaring `integration`), single placement smoke check (INTEGRATION-008) emitting an informational hint pointing at the migrating skill — never deliberates on placement inline. Does NOT load `group: placement` rules. Supports the team-review decomposition modes (method scope, `review_unit` track filter, body-free `digest`, inline-rules) so it can be a per-type routing target for the unified team reviewer.

### phpunit-migration-test-generation

Generates Shopware-compliant PHPUnit migration tests that run against a real database. Analyzes the migration's SQL operations and `updateDestructive` logic to select a test pattern. Forks into `test-generator` via `context: fork`; writes only to `tests/migration/`.

**Features**: SQL-operation pattern detection (schema-add, schema-remove, data-update, config, mail template), template-based generation with conditional sections, PHPStan/PHPUnit validation loop.

### phpunit-migration-test-reviewing

Reviews migration tests in `tests/migration/` against the migration ruleset (MIGRATION-001..009, all must-fix). Source-aware for the rules that need the migration class (MIGRATION-002, MIGRATION-004).

**Features**: MCP-driven review via `get_rules(test_type=migration)` (the composed catalog — MIGRATION-001..009 plus every convention/design/isolation/provider rule declaring `migration`), method scope, and the team-review decomposition modes (`review_unit` track filter, body-free `digest`, inline-rules) so it can be a per-type routing target for the unified team reviewer.

### phpunit-integration-to-unit-migrating

User-invoked audit-and-migrate workflow for integration tests that may belong in `tests/unit/`. Walks PLACEMENT-001..008 per test class with a required SUT-contract articulation gate.

**Features**: Scope resolution (file/directory/PR/branch), per-test SUT contract articulation, PLACEMENT-008 veto-first, four buckets (migrate / split / keep / delete-duplicate), `AskUserQuestion` confirmation gate before execution, 6 codified refactoring patterns (container-fetched service, compiler pass, subscriber, parser, constraint-only validation, DAL materializer). Never auto-invoked.

**Tools**: Glob, Grep, Read, Edit, Write, AskUserQuestion, Bash, mcp__plugin_test-writing_test-rules__get_rules

## 🛠️ Modification Guide

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
| Change team reviewer count | `team-reviewing/references/reviewer-allocation.md` (adaptation guide) + `team-reviewing/workflow/team-review.workflow.mjs` (implementation; `SLOTS` is the 2-of-3 consensus invariant, NOT a preset knob) |
| Change adversary count | `team-reviewing/workflow/team-review.workflow.mjs` (`ALL_LENSES` array + `PRESETS.*.lenses` — active adversary count = preset lens count, sliced in priority order) + `team-reviewing/references/reviewer-allocation.md` (adaptation guide) |
| Change tuning presets or model combos | `team-reviewing/workflow/team-review.workflow.mjs` (`PRESETS` / `MODEL_PRESETS` maps + manifest `preset`/`models` reads) + `team-reviewing/references/reviewer-allocation.md` & `workflow-design.md` (per-preset tables) + `team-reviewing/SKILL.md` Phase 2 (projection + selection) & Phase 3 (writes `preset`/`models` into args.json) |
| Change dry-run agent-cost projection | `team-reviewing/workflow/team-review.workflow.mjs` (`DRY_RUN` early return + `projectUnits` + parameterized `trackOf`/`effectiveShards`) + `team-reviewing/SKILL.md` Phase 2 (dry-run launch + table) + `team-reviewing/references/report-format.md` §Dry-Run Projection |
| Modify reconciliation rules | `reconciling/references/reconciliation-rules.md` |
| Change reconciling output format | `reconciling/references/output-format.md` |
| Modify red team protocol | `team-reviewing/references/red-team-context.md` + `adversarial-reviewing/SKILL.md` + `team-reviewing/workflow/team-review.workflow.mjs` (red-team prompt + skip signal) |
| Change team review report | `team-reviewing/references/report-format.md` (render template + result-shape contract) + `team-reviewing/workflow/team-review.workflow.mjs` (emits the result shape) |
| Change changeset adoption signal | `team-reviewing/workflow/team-review.workflow.mjs` (`ADOPTION_SCHEMA` + `adoptionPrompt` + diff-run gate + changeset-boundary filter) + `team-reviewing/references/report-format.md` (render + result-shape) |
| Change workflow wave design | `team-reviewing/workflow/team-review.workflow.mjs` (shipped workflow — owns the wave shape) + `team-reviewing/references/workflow-design.md` (adaptation guide) |
| Change run-script delivery / launch | `team-reviewing/workflow/build-run-script.sh` (manifest splice + marker guard + jq gate) + `team-reviewing/SKILL.md` Phase 3–4 (on-disk assembly + scriptPath launch) |
| Change pre-run manifest extraction | `team-reviewing/references/input-resolution.md` §Per-File Extraction (subagent contract) + `team-reviewing/SKILL.md` Phase 1 (fan-out) |
| Change agent spawn guardrails | `team-reviewing/references/agent-guardrails.md` (universal guardrails + adaptation guide) + `team-reviewing/workflow/team-review.workflow.mjs` (prompt builders + schemas) |
| Change consensus / verdict logic | `team-reviewing/references/consensus-and-verdicts.md` (adaptation guide) + `team-reviewing/workflow/team-review.workflow.mjs` (implementation) |
| Change finding identity | `skills/phpunit-test-team-reviewing/workflow/team-review.workflow.mjs` (`deriveFindingId`, `methodId`, `ingestFinding`) + `skills/phpunit-test-team-reviewing/references/consensus-and-verdicts.md` (§Finding identity) — every downstream schema (reconcile, red-team, defense) quotes the id back rather than recomputing it |
| Change adversary agent | `agents/test-adversary.md` (generic — shared by all adversarial reviewing skills) |
| Change team input resolution | `team-reviewing/references/input-resolution.md` (Phase 1 manifest contract; consumed by `team-reviewing/workflow/team-review.workflow.mjs`) |
| Change team error handling | `team-reviewing/references/error-handling.md` (spec) + `team-reviewing/workflow/team-review.workflow.mjs` (re-spawn + coverage gate) |
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

## 🔗 Integration

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
- `mcp__plugin_test-writing_test-rules__build_rule_package` — Render a rule catalog to a file in `$CLAUDE_PLUGIN_DATA/rule-packages/` and return its absolute path. With no arguments it renders the five unit-review groups (convention, design, unit, isolation, provider) to `unit-review.md`, byte-identical to concatenating `get_rules(group=X)` over the five groups. Pass `test_type` **alone** (no `group`) to render that type's **composed** catalog — its own group plus every convention/design/isolation/provider rule declaring the type — byte-identical to `get_rules(test_type=X)`; this is the call the unified team review uses for integration and migration. Pass `group` (with `test_type`) instead to narrow to a **single non-composed** group — `group=integration test_type=integration`, `group=migration test_type=migration`, `group=placement test_type=integration` (the last used only by `phpunit-integration-to-unit-migrating`) — byte-identical to the matching `get_rules` selection, under a group/test_type-derived filename. Optional scope filters (`review_unit` — a single value or comma-separated list — / `test_category` / `scoped_review`, mirroring the `get_rules` filters) render a **scoped subset**. The unified team review composes **one catalog per test type present** at composition time (via `test_type` alone) and passes them as `rule_packages.{unit|integration|migration}` in each review/adversarial stage's manifest (the signals stage uses no catalogs); the committed workflow script then selects each agent's scoped `## RULES` block from the file's per-type catalog by the per-rule metadata in its rendered header — byte-identical to a scoped `build_rule_package`/`get_rules` call (same renderer and separator), so agents apply only their per-track rules without fetching them per agent. The equivalence of in-package selection and the server filter is CI-guarded by `plugin-tests/test-writing/selection_equivalence.bats` (unit and non-unit groups); the non-unit catalogs' byte-fidelity, content-isolation, and filename coexistence are additionally guarded by `plugin-tests/test-writing/build_rule_package.bats` (§C3).

## 📚 External References

- [Shopware PHPUnit Testing Docs](https://developer.shopware.com/docs/guides/plugins/plugins/testing/php-unit)
- [PHPUnit Documentation](https://phpunit.de/documentation.html)
- [PHPStan Documentation](https://phpstan.org/user-guide/getting-started)
