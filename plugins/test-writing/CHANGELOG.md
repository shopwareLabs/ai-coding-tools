# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.8.12] - 2026-06-24

### Changed
- **Team-review migration step 1 — scope review rules per unit, tier the reasoning-wave payloads, and recover from partial failures.** Design fixes from the Jun 21–24 multi-run analysis, landing in the `references/` and the `build_rule_package` MCP tool. They follow through the still-per-run-authored workflow now; a later migration step crystallizes the stabilized design into a committed script. No change to the Wave-1 zero-finding gate, model pinning, the 3-reviewer consensus triad, or the result shape (beyond the `red_team` coverage flag below).
  - **C2 — `build_rule_package` renders a scoped subset; agents get only their track's `## RULES`.** The tool previously took zero parameters and rendered all five unit-review groups (49 rules, ~106 KB) into one package injected into every agent — the prompt-overflow source that killed context-heavy agents ("Prompt is too long"). It now accepts the same scope filters as `get_rules` — `review_unit` (a single value **or** a comma-separated list, for the whole-class fused track), `test_category`, and `scoped_review` — in both its `tools.json` `inputSchema` and `lib/build.sh`, rendering a byte-faithful subset under a scope-derived filename so a composition's per-track packages coexist as distinct paths. `_filter_rules` now matches `review_unit` by membership (a single value is a one-element list), so `get_rules` is unaffected. `workflow-design.md` §Pre-Run Collect and `agent-guardrails.md` now build one scoped package per distinct `(review_unit-track, category, scoped_review)` combination and inject only the matching one (method-shard → `method`; whole-class fused → `class-structure,class-bodies`; digest → `class-structure`; Track A → full catalog).
  - **C3 — minimal rule payload for the finding-reasoning waves.** The waves that reason about findings rather than detect them now carry a tiered payload instead of the full catalog: the arbiter gets only the one contested rule; the Wave-1 peer and Wave-3 defense reconcilers get only the rule entries their findings reference (the union, computable at assembly time); the Wave-2 red team gets the category-scoped catalog (it still introduces new rule-cited findings); adversary impressions stay catalog-free. These were the agents that carried a large second payload and overflowed first.
  - **C4 — bounded re-spawn + an adversary-coverage gate replace silent degradation.** `error-handling.md` and `workflow-design.md` now re-spawn a dead unit/agent up to `RESPAWN_MAX` (= 2) before any graceful degradation, and only that unit — never the whole fleet (a clustered transient `529` previously forced a full-fleet re-run, discarding completed work). Adversary-wave coverage is tracked: after re-spawns settle, any in-scope file left un-red-teamed raises a prominent coverage-gap flag in `red_team`, so partial adversary coverage is never presented as complete. Reviewer loss still degrades gracefully to 2-of-2, and the honest run-integrity reporting is kept. §Run Failures no longer offers "re-run the review" as the sole recourse for a mid-flight error.
  - **R1 — rule delivery is inline-scoped, never by file pointer.** Confirmed and held: no spawned-agent instruction reads a rule-package file and no `get_rules` route remains anywhere in the team-review references; the inline `## RULES` block (now C2-scoped) is the only rule source for agents. The standalone single-reviewer path keeps `get_rules` when no inline rules are supplied.

## [3.8.11] - 2026-06-21

### Changed
- **Team-review rule delivery switched from a file path to inline prompt text, so spawned agents stop grep-paging the rule catalog.** Since 3.8.7 the orchestrator handed every reviewer, reconciler, adversary, and arbiter a *path* to the pre-rendered rule package and the sub-skill's Supplied-Rules Mode said to `Read` it once and select. In practice agents did not comply — they grep-paged the flat catalog file (Grep for rule headers/IDs, then `Read` offset slices, one turn each), and in the 3.8.9 run that pushed turns/agent from ~7.4 to ~9.3 with ~90% of reviewers' and ~82% of reconcilers' Read/Grep calls landing on the catalog rather than the code under review. Now the orchestrator `Read`s the package **once** at composition time and the rendered catalog is delivered to each agent as fixed agent-prompt data under a `## RULES` heading — the agent has no file to open, grep, or page, so the rule-file navigation turns disappear. The path is never passed to a spawned agent, and `agent-guardrails.md` forbids reading, searching, or locating any rule file by any means — native tool (`Read`/`Grep`/`Glob`) or terminal command (`ugrep`/`bfs`/`grep`/`find`/`cat`) — and forbids `get_rules`, while explicitly leaving the agent's test-file and source-class reads untouched.
  - **`{rules_file}` (path) → `{rules}` (inline text); Supplied-Rules Mode → Inline-Rules Mode.** The optional rule input on `phpunit-unit-test-reviewing`, `phpunit-unit-test-reconciling`, and `phpunit-unit-test-adversarial-reviewing` (and the arbiter prompt) now carries the rendered catalog as text in the prompt instead of an absolute path. The selection predicate is **byte-for-byte unchanged** — group match + category-in-`Categories` + `Review unit` (with list-union) + `Scoped review` ≠ `exclude` — so it returns the same rule set as the corresponding `get_rules` call by construction; only the input the predicate reads over changes from a file to in-context text. No review-behavior change: same rules, same detection algorithms, same per-track filtering (`review_unit` / category / scoped).
  - **Standalone flow unaffected.** When `{rules}` is omitted, every sub-skill loads rules via `get_rules` exactly as before, so the single-reviewer `phpunit-unit-test-writing` path is byte-for-byte unchanged. `build_rule_package` is unchanged (still renders the catalog to a file and returns its path); only the channel the rule bytes travel from that file to the agents changes.
  - **The Workflow stays a blackbox** (per 3.8.1): the references describe the rule text as a composition-time in-prompt artifact — mirroring the existing structural-digest and cross-file-fingerprint artifacts in Pre-Run Collect — and name no scripts, files, `args`, or `scriptPath`; no JS workflow file is added. The `build_rule_package` descriptions in `README.md` and `AGENTS.md` were corrected to reflect inline delivery (the orchestrator reads once and injects, rather than each agent reading the file).

## [3.8.10] - 2026-06-21

### Fixed
- **Team-review skill instructions hardened against an execution misbehavior surfaced in a test run, where the executor audited the skill instead of running it.** A run aborted after the executor modeled the team review as a pre-existing artifact to locate, ran a filesystem-wide search, found a stale research script from an earlier run, and began diffing it against the references — then started re-verifying the sub-skill input interface before fanning out. A later run still consulted the advisor before launching despite a soft inline note, so the orchestrator-posture rules are now hard directives in a dedicated, front-loaded `## Execution posture` section that names and overrides the general disciplines they displace. All changes are instruction-only: no code changes, and no change to the review logic, waves, consensus, or field contracts. The Workflow stays a blackbox (per 3.8.1) — none of the wording names a script, the Workflow, `scriptPath`/`args`, or any delivery mechanism.
  - **Agent descriptions no longer imply a pre-existing workflow artifact.** `test-reviewer` and `test-adversary` read "Spawned per wave by the team-reviewing workflow" — a definite-article noun that modeled the workflow as a concrete object to find and reuse. Both now read "Spawned per wave during team review."
  - **New `## Execution posture` section, front-loaded before Phase 0, suspends three standing disciplines for a normal run.** (1) Do not consult the advisor — composing and launching is not the pre-flight-check-worthy substantive work the advisor's standing guidance targets, and the agent count is not an inflection point; consult it only after a run fails for an unidentifiable reason. (2) Do not search the filesystem for anything to reuse — the review has no pre-built form, and a leftover file from a prior run is stale and misleading. (3) Do not re-verify the references or the sub-skill input contracts — they are authoritative, complete, and already verified. Phases 2 and 3 now state only the compose-fresh and launch-directly actions and defer the prohibitions to this section.
  - **`input-resolution.md` Diff-to-Method Resolution gains a shared-code ripple rule.** A change to `setUp`/`tearDown`, a private helper, a data provider, or a class property that unchanged test methods depend on now scopes the file full-class, since the change ripples beyond the methods whose lines it touched — previously left to executor judgment.

## [3.8.9] - 2026-06-21

### Changed
- **Team-review Wave-1 peer reconciliation now skips a unit when all three of its Wave-0 stances carry zero findings.** In the Workflow-based team review, `workflow-design.md` reconciled every unit that had a live reviewer in Wave 0 — including units where all three reviewers found nothing, which spawned 3 reconciler agents to reconcile empty-against-empty. The wave shape (Step 3) now gates reconciliation per unit: a unit whose three Wave-0 stances are all empty has nothing to reconcile, so its three empty stances carry forward unchanged as binding input to the preliminary consensus and no agent is spawned for it. The gate is **zero-findings-only** — a single reviewer finding obliges the other two to weigh it, so the unit still reconciles; unanimous-identical units are deliberately not skipped (skipping them would change the red-team concession-rate denominator and remove a stress-test). The skip is deterministic from Wave-0 outputs and applies per unit, so a decomposed (Track B) file skips Wave 1 on its empty method-shards while still reconciling a whole-class unit that has findings.
  - **Output-neutral and concession-rate-neutral.** Reconciling empty-against-empty yields empty, so a skipped unit's preliminary consensus is identical to having run Wave 1 — no finding is lost. A zero-finding unit contributes 0 to both the numerator and denominator of the red-team skip signal (Adaptation Point 2), so the concession rate and that branch are unchanged. Step 4 now states this explicitly.
  - **Auditable.** The `adaptation` field in the Result Shape now reports the count of units whose Wave-1 reconciliation was skipped for carrying zero Wave-0 findings.
  - **The Workflow stays a blackbox** (per 3.8.1): the change is design-reference prose describing the wave shape and an output contract only; it names no script, no Workflow, no `scriptPath`/`args`, and no delivery mechanism.
  - **Standalone flow unaffected.** The single-reviewer `phpunit-unit-test-writing` flow has no waves and no peer reconciliation, so the gate has no effect there. No review logic, consensus merge, wave, or field contract changes; no shared agent definition is touched.

## [3.8.8] - 2026-06-21

### Changed
- **Team-review agents now emit one short visible line alongside their structured output, removing the "no visible output" retry waste.** In the Workflow-based team review, every agent's output contract instructed it to return the structured output *only* — so each schema-bound turn carried a tool call and no visible text, and the agent then spent a full extra turn re-reading its entire context to produce zero new analysis. The universal guardrail (`agent-guardrails.md`) is rewritten from "Return structured output only — no prose outside the field contract" to a positive one-line contract: emit exactly one short visible line summarizing the result (e.g. a one-line finding tally) in the same response as the structured output, and no other prose — the structured output stays the only contract-bearing payload. The two shared agent definitions (`test-reviewer`, `test-adversary`) drop the text-forbidding "Return structured output only" line in favor of "Return only your result — no chatter or filler prose," so no surviving instruction pushes the text-free turn.
  - **The Workflow stays a blackbox** (per 3.8.1): the guardrail states an agent output contract only; it names no nudge, no Workflow, no `scriptPath`/`args`, and no delivery mechanism.
  - **Standalone flow unaffected.** `test-reviewer`/`test-adversary` are shared with the single-reviewer `phpunit-unit-test-writing` flow, which returns a text report (no `StructuredOutput` tool call). The visible-line requirement is moot there and the "no chatter" intent is preserved, so the change is behavior-neutral for the standalone flow. No review logic, wave, consensus, or field contract changes.

## [3.8.7] - 2026-06-21

### Added
- **`build_rule_package` MCP tool on the bundled `test-rules` server, plus a Supplied-Rules Mode that lets team-review agents read the rule catalog from a file instead of fetching it per agent.** In the Workflow-based team review, every reviewer, reconciler, adversary, and arbiter agent previously loaded the rule catalog itself via `get_rules` — the same ~30K of rule bytes fetched once per agent and re-read every turn, the dominant cost lever in a run. The new tool renders the five unit-review groups (convention → design → unit → isolation → provider, 49 rules) once at composition time to `$CLAUDE_PLUGIN_DATA/rule-packages/unit-review.md` (atomic `mktemp` + `mv`) and returns the absolute path; the orchestrator provides that path to every agent as fixed prompt data, and each agent `Read`s it once. The tool fails hard — unset `CLAUDE_PLUGIN_DATA`, a write failure, or zero rendered rules abort with a clear error, never a silent fallback to `/tmp` or the plugin install directory. Output is byte-identical to concatenating `get_rules(group=X)` over the five groups: both the new tool and `get_rules` now render through a shared `_render_rules` helper, so the catalog the agents read is the same bytes `get_rules` would serve (a before/after diff over every `get_rules` call mode is zero, and a byte-fidelity BATS golden pins it).
  - **Supplied-Rules Mode** is a new optional `{rules_file}` input on `phpunit-unit-test-reviewing`, `phpunit-unit-test-reconciling`, and `phpunit-unit-test-adversarial-reviewing` (and the team-review arbiter prompt). When set, the sub-skill selects rules from the package by matching the per-rule header lines — a predicate that returns the exact same rule set as the corresponding `get_rules` filter, locked by a selection-equivalence golden test across every `(group × category × scoped × review_unit)` combination a reviewer can pass. When omitted, every sub-skill behaves exactly as today, so the standalone single-reviewer flow (`phpunit-unit-test-writing`) is unchanged. `get_rules` stays in every agent's tool list and in `AGENTS.md`; in team review it is forbidden by prompt, never removed.
  - **The Workflow stays a blackbox** (per 3.8.1): the skill and its references describe rule delivery as a composition-time artifact provided to agents — mirroring the existing structural-digest and cross-file-fingerprint artifacts in Pre-Run Collect — and name no scripts, files, `args`, or `scriptPath`; no JS workflow file is added to the skill. Quality-neutral by construction: the 3-reviewer triad, adversary wave, contested-exclusion filter, arbitration, and cross-file pass are untouched — only the channel the rule bytes travel changes.

## [3.8.6] - 2026-06-20

### Changed
- **Team-review agent models are now pinned explicitly on every spawn instead of stated as a fact.** `workflow-design.md` declared the per-role tiers ("reviewers run on sonnet, arbiter/cross-file run on opus") but never required the model to be set on each spawn, so an agent spawned without an explicit model would silently inherit the session/default model — possibly a different tier — and the opus roles had no agent type to source opus from (all three read-only agent types are sonnet). The Design Constraints now state that each agent's model is fixed before the run and set explicitly on its own spawn, never inherited; that agent type and model are orthogonal (the read-only agent type supplies tools and the no-write guarantee, not the model); and that the arbiter's opus tier can come only from its explicit spawn. The up-front scope announcement now includes the model tier per role for auditability.
- **Cross-file consistency agent retiered from opus to sonnet.** Its input is the pre-extracted per-file fingerprint (a fixed structural signature), not raw code, so its task is signature comparison plus an alignment recommendation — well within sonnet. opus was over-provisioned for a pre-digested input. No change to what it produces.

### Fixed
- **Corrected the stale team-review description in `plugin.json`.** It advertised "Wave-based Agent Teams orchestration … peer-to-peer debate," which contradicted the Workflow migration and the references' own "blackboard, not a mesh; no agent-to-agent messaging" design. Now reads "Workflow-based team review: wave-orchestrated agents coordinated through a shared blackboard (no agent-to-agent messaging), with adversarial red team and defense rounds."

## [3.8.5] - 2026-06-20

### Changed
- **Consensus merge now preserves the most complete remediation per finding.** When 2-of-3 or 3-of-3 reviewers agree on the same `(rule_id, location)` but supply `suggested` fixes of differing completeness, the team-review merge (`consensus-and-verdicts.md`) left payload selection unstated, so the authoring session could carry the weaker fix forward by luck (in the analyzed run the complete suggestion won by chance). The "Per-File Consensus Merge" section gains a **Remediation payload** rule: take the superset suggestion when one stance's fix subsumes the others, combine genuinely distinct sub-actions into one `suggested`, never pick an arbitrary stance's payload (e.g. first reviewer, first wave), and record a one-line note on non-obvious selections. Only the `suggested` content of some merged findings changes; the set of findings and every status is unchanged.
- **Orchestrator fix loop applies the reviewer's `suggested` fix in full.** `phpunit-unit-test-writing` Phase 4 Step 1 now states that the `suggested` remediation is applied verbatim — every sub-action it specifies — and not re-summarized, narrowed, or reinterpreted. A fix that looks wrong is applied as given and caught by the existing re-review and oscillation/escalation handling, rather than silently replaced by a partial fix. Hardens an existing instruction; the validation gate (Step 2 / Step 5) is unchanged.
- **Recorded the fix-application fidelity contract for a future team-review fix phase** (`AGENTS.md`). Team review is read-only and has no fix phase today, so nothing changes in the skill. The maintainer note states that any future team-review fixer must pass the consensus `suggested` to the fixer **verbatim** (never a paraphrase) and run a PHPStan/PHPUnit/ECS check via the dev-tooling MCP before reporting a fix done. Documentation only.

## [3.8.4] - 2026-06-20

### Changed
- **Renamed the rule review-mode classifier from `class-scope-only` to `scoped-review: include | exclude`.** Every rule under `rules/` now declares `scoped-review` directly: `exclude` skips the rule when a review is scoped to changed/added methods (a whole-class concern, noise on a method diff); `include` evaluates it (the default for nearly all rules). This replaces the overloaded `class-scope-only: true` boolean, whose name read like an input-axis classifier but only ever drove the review-mode axis — sitting beside the input-axis `review-unit` field, it invited setting the wrong one and silently changing scoped behavior. The field is required and CI-validated (`.github/scripts/validate-review-unit.sh`, extended to enforce both classification fields), fail-hard at index time on a missing or invalid value, with BATS coverage for parsing, the fail-hard guard, the `get_rules` metadata-header exposure, and a behavior-equivalence check. The `test-rules` MCP server resolves the `scoped_review=true` filter via the new field and surfaces it in each rule's `get_rules` header.

  Behavior-preserving: the `scoped-review: exclude` set is exactly the rules that previously carried `class-scope-only: true` (CONV-005, CONV-007, UNIT-002, INTEGRATION-008), so a `get_rules(scoped_review=true)` call returns the same rule set as before and every review's output is unchanged. The sole internal consumer (the `phpunit-unit-test-reviewing` sub-skill) keeps passing the `scoped_review` query parameter and needs no change.

### Removed
- **`class-scope-only` rule frontmatter property.** Retired in favor of `scoped-review` (above). The four rules that declared it now declare `scoped-review: exclude`; all other rules declare `scoped-review: include`.

## [3.8.3] - 2026-06-20

### Fixed
- **Team review no longer overflows the 200K context window on large test files or changesets.** The 3.8.0 Workflow refactor reviewed each file as one rule-heavy agent and bundled multiple files per reviewer at large N; a single moderately large test+source pair could drive an agent to ~80% of the window, and bundling tipped agents past it and failed the run. `phpunit-unit-test-team-reviewing` now decomposes each agent's work unit deterministically from line counts known at resolution time, against fixed skill-owned thresholds — never a runtime "will this fit" estimate:
  - Files with combined test+source ≤ `T` (300) are unchanged: 3 reviewers, full class, all rules.
  - Larger files shard their test methods into groups of ≤ `M` (8) — each shard reviewed by 3 reviewers loading only `method` rules — plus a whole-class set (3 reviewers over the class-structure + class-bodies rules). Above `C` (800) the whole-class set degrades to a body-free structural-digest review and emits a "split this test class" entry instead of attempting a review it cannot fit. The 3-reviewer / 2-of-3-majority consensus invariant now holds per track, and a scoped review still reports only changed-method findings on every track that reads the class; a per-file reviewer cap (`U_file`=18) bounds the pathological case via a fixed shard-coarsening formula. Round-robin file bundling is removed — every reviewer agent carries exactly one unit.
- **Cross-file consistency no longer scales with finding volume.** The dedicated cross-file agent (which peaked highest of any agent in the failing run) now ingests a fixed-size structural fingerprint per file (setUp shape, mock strategy, assertion style, data-provider style, attribute order) instead of every file's full consensus, so its input is `N × small-constant`. Above `F_cap` (40) files it shards by pattern dimension and merges; it correlates structural patterns only.
- **Large changesets review end-to-end instead of risking the agent cap.** When the projected reviewer total exceeds `G` (300), the manifest auto-partitions into sequential chunks each ≤ `G`, with one global cross-file pass over the union of all fingerprints so chunking never blinds it. Adversaries scale as `⌈N / K_adv⌉` (K_adv=6) with a contiguous partition.

### Added
- **Internal `review_unit` and `digest` inputs on `phpunit-unit-test-reviewing`** (the `user-invocable: false` sub-skill) — the plumbing the decomposition above rides on. `review_unit` (`method` | `class-structure` | `class-bodies`, single or list) scopes a review to one rule track via the 3.8.2 `get_rules` filter; `digest` supplies a body-free structural digest the sub-skill reviews instead of reading the test file (loading only the category-agnostic `class-structure` rules). Both default off — omit them and every existing caller and small-file review behaves exactly as before.

## [3.8.2] - 2026-06-19

### Added
- **`review-unit` rule classification field.** Every detection rule under `rules/` now declares a required, CI-validated `review-unit: method | class-structure | class-bodies` frontmatter field stating the minimal input a rule's detection algorithm needs: `method` (one test method body + its data provider), `class-structure` (class shape only — member order, signatures, attributes, `#[CoversClass]`; no bodies), or `class-bodies` (multiple full method bodies together). The bundled `test-rules` MCP server now indexes the field, exposes it in each rule's `get_rules` metadata header, and accepts a new `review_unit` filter parameter so callers can enumerate the whole-class set (`class-bodies`/`class-structure`) separately from the shardable `method` set. A missing or invalid value is a hard error at index time (the server refuses to index it), never an empty entry. A new CI gate (`.github/scripts/validate-review-unit.sh`) enforces the field across every rule, and new BATS coverage (`plugin-tests/test-writing/`) covers indexing, filtering, header exposure, and the fail-hard guard. Placement rules are classified `class-bodies`. This change is purely additive and behavior-preserving: `scoped_review`, `class-scope-only`, and every review's output are unchanged.

## [3.8.1] - 2026-06-19

### Fixed
- **Team review skill leaked Workflow implementation details.** `phpunit-unit-test-team-reviewing` and its references named the orchestration mechanism directly — authoring a "Workflow script", baking the manifest "as constants", launching the "script inline", and recovering by editing the returned "scriptPath". This coupled the skill to the `Workflow` tool's internals and competed with the tool's own contract (pass the script inline; it auto-persists), so an executing session wrote the script into the project tree and launched it from there — overriding that contract. The skill now treats `Workflow` as a blackbox: it specifies the review *design* abstractly (waves, roles, output contract, adaptation points) and runs it via the `Workflow` tool, with no mention of scripts, files, constants, args, or scriptPath/resume. The skill trigger and the report a user receives are unchanged.

## [3.8.0] - 2026-06-19

### Changed
- **Team review converted from Agent Teams to a Claude Code Workflow.** `phpunit-unit-test-team-reviewing` no longer orchestrates an Agent Teams run itself. The skill is now an authoring brief: it resolves the input to a file manifest inline (still able to ask the user about base branch and scope), authors a Workflow script adapted to that manifest, launches it via the `Workflow` tool with the script passed inline, and renders the returned object into the report. The orchestration logic that used to live as prose in the SKILL.md — reviewer allocation, consensus merge, red-team skip, adversary-impact tagging — moves into the authored Workflow as deterministic code. The `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` prerequisite and the `TeamCreate`/`TeamDelete`/`SendMessage` tools are gone; team review now works without the experimental Agent Teams flag. The skill trigger and the report a user receives are unchanged.
- **Peer debate replaced by blackboard reconciliation.** A Workflow has no agent-to-agent messaging, so the live `SendMessage` debate is replaced by structured waves: each reviewer receives peers' prior-wave findings in its prompt and returns a revised binding stance. No emergent peer mesh; coordination is explicit and code-driven.
- **Cross-file consistency is now a dedicated wave.** A single agent receives every file's final consensus and hunts pattern divergence across files. Individual reviewers no longer emit cross-file references, so per-file reviewer packing is free to optimize for isolation.
- **Reviewer allocation reconceived for the Workflow model.** The consensus invariant is unchanged (3 independent reviewers per file, 2-of-3 majority), but persistent reviewer identity and the team-era `R ≤ 5` cap are gone. Small/medium inputs (N ≤ 6) use per-file fan-out with no allocation arithmetic; large inputs (N ≥ 7) bundle via round-robin. Adversary count is 1 (N ≤ 3), 2 (N 4–11), or 3 (N ≥ 12).
- **Runtime adaptation points.** The authored Workflow carries fixed-cap adaptations: red-team skip on zero findings or substantive peer contention, an optional second peer-reconciliation pass (max 2 total), adversary-introduced findings routed into the defense wave, per-finding arbitration of contested findings, and targeted reviewer widening (+2, once) on high-contention files.

### Added
- **`phpunit-unit-test-reconciling` skill.** Internal multi-mode sub-skill (`user-invocable: false`) that re-evaluates findings against incoming critique and emits a binding revised stance. `peer` mode reconciles against co-reviewers' findings (supplied in-prompt, no messaging); `adversary` mode reconciles against adversary challenges. Evidence (the rule's detection algorithm applied to the code) decides every disposition.

### Removed
- **`phpunit-unit-test-debating` and `phpunit-unit-test-defending` skills**, merged into `phpunit-unit-test-reconciling`. Both were structurally identical (re-apply detection algorithm → per-finding disposition → binding stance); debating's only Agent-Teams coupling was the `SendMessage` round.
- **`SendMessage` from the `test-reviewer` agent** and the `team-reviewing/references/message-formats.md` reference (folded into `agent-guardrails.md` and the reconciling skill's output format).

## [3.7.2] - 2026-06-11

### Removed
- **Role-persona sentences dropped from all three agents and the team-reviewing skill.** Removed "You are a test generator." (`agents/test-generator.md`), "You are a read-only test reviewer." (`agents/test-reviewer.md`), "You are an adversarial test reviewer." (`agents/test-adversary.md`), and "You (the skill executor) act as team lead." (`skills/phpunit-unit-test-team-reviewing/SKILL.md`). Research on persona prompting shows role assignments do not improve the factual correctness of LLM output — at best they steer writing style. In these files the roles steered nothing: every behavior the role words implied is enforced explicitly elsewhere — read-only via tool lists and "Do NOT modify any files" scope constraints, adversarial behavior via the agent description and the `phpunit-unit-test-adversarial-reviewing` skill, output shape via "return structured output only" plus the invoking skills' output contracts, and orchestration duties via the wave workflow itself. The sentences were inert ballast and are gone. No behavior change.

## [3.7.1] - 2026-05-13

### Changed
- All 12 skill descriptions rewritten to follow https://agentskills.io/skill-creation/optimizing-descriptions. User-facing skills (`phpunit-unit-test-writing`, `phpunit-migration-test-generation`, `phpunit-integration-test-generation`, `phpunit-integration-to-unit-migrating`, `phpunit-unit-test-team-reviewing`) lead with imperative "Use this skill when..." and list explicit trigger phrases sourced from prior descriptions and README. The 7 internal-only sub-skills (all with `user-invocable: false`) now share one minimal "Do not auto-activate" line — they should only trigger when another skill or agent invokes them by name. No behavior change.

## [3.7.0] - 2026-05-13

### Added
- **MIGRATION-009 — setUp/tearDown must not mutate DB state**: New `must-fix` rule. Detects DDL or DML (`ALTER`, `CREATE`, `DROP`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REPLACE`; `$conn->insert/update/delete`; schema-manager mutations) inside `setUp()` or `tearDown()` — including inside `try/catch` wrappers. Connection acquisition, PHP-side ID generation, and read-only fetches remain permitted. Codifies the fix pattern applied across 19 files in shopware/shopware PR #16799: every migration test class contains `testGetCreationTimestamp` (MIGRATION-008), and any state mutation in lifecycle hooks runs around a test that doesn't need it, leaving non-transactional schema or per-row state for sibling test classes. Two canonical fixes: private helper invoked from the test method, or `try/finally` inside the test method.

### Changed
- **MIGRATION-005 — Separate try/catch per cleanup statement — catch Throwable**: Title and scope broadened from "in setUp/tearDown" to any cleanup site. The teaching points (one statement per try, catch `\Throwable`) are unchanged; only the location qualifier is dropped, since MIGRATION-009 now owns *where* cleanup lives. Example rewritten to use a private helper, mirroring the `revertMigration` fix in shopware/shopware commit `957284966e1` (split chained FK + column drop into two independently-guarded statements).
- **Migration test template — Schema-Remove conditional**: Removed the `tearDown()` that restored the column. Restore now lives inside `testUpdateDestructive()` wrapped in `try/finally`, with an inline note pointing at MIGRATION-009 and the reason (DDL is not transactional in MySQL).
- **`phpunit-migration-test-reviewing` skill**: Overview updated to "MIGRATION-001 through MIGRATION-009". Source-aware note unchanged — MIGRATION-009 detection needs only the test file.

## [3.6.0] - 2026-05-12

### Added
- **Integration test ruleset** (`rules/integration/`, INTEGRATION-001..008): 8 rules covering Shopware integration-base usage, real-collaborator policy, transactional cleanup, determinism, independence, fixture-skip prohibition, setup-to-assertion balance, and a placement smoke check.
- **Placement ruleset** (`rules/placement/`, PLACEMENT-001..008): 8 deep-reasoning prompts (container intent, persistence intent, kernel intent, assertion shape catalog, collaborator graph, setup-vs-assertion symmetry, name-vs-body coherence, stay-in-integration veto indicators). Loaded only by the migrating skill, not by reviewers.
- **`phpunit-integration-test-generation` skill**: Generates Shopware-compliant PHPUnit integration tests for source classes whose contract requires wired-up code. Analyzes the source class to detect a supported pattern (controller/route, scheduled-task, message-handler, indexer, DAL-persistence flow, multi-service coordinator). Returns SKIPPED with a pointer to `phpunit-unit-test-generation` when the SUT is unit-shape — same negative cases the migrating skill recognizes (factory, compiler pass, single subscriber, parser, constraint-only rule, DAL materializer). Single template with conditional sections calibrated against recent Shopware integration tests: realtime `EntityIndexer::update($event)` flow for indexers, direct `ScheduledTaskHandler::run()` invocation for scheduled tasks, `DatabaseTransactionBehaviour + KernelTestBehaviour` lighter trait choice for indexer/scheduled-task patterns, `IdsCollection` for ID management, generic `EntityRepository<XxxCollection>` PHPDoc typing. Validates via PHPStan/PHPUnit/ECS. Forks into `test-generator` agent via `context: fork`.
- **`phpunit-integration-test-reviewing` skill**: Reviews integration tests against the integration ruleset. Assumes correct placement; emits a single placement smoke-alarm hint (INTEGRATION-008) when assertion shape is entirely unit-shape, pointing at the migrating skill. Invoked by the `test-reviewer` agent, not directly by users.
- **`phpunit-integration-to-unit-migrating` skill**: User-invoked audit-and-migrate workflow. Walks PLACEMENT-001..008 per test, buckets into migrate/split/keep/delete, requires explicit user confirmation, then applies one of 6 refactoring patterns codified from shopware/shopware PRs #16704, #16742, #16754, #16759, and #16769. Trigger phrases: "audit integration tests", "migrate integration tests to unit".
- **MCP `group` enum extended** with `integration` and `placement` so rules are discoverable via `mcp__plugin_test-writing_test-rules__get_rules(group=integration)` and `(group=placement)`.

### Changed
- `test-generator` agent now serves three generation skills (unit, migration, integration). File write restriction is enforced per-skill in the invoking SKILL.md — the agent itself remains a generic execution environment.

## [3.5.2] - 2026-05-07

### Changed
- Marked four sub-skills as model-only via `user-invocable: false` in their SKILL.md frontmatter so they no longer surface as user-triggerable skills: `phpunit-unit-test-adversarial-reviewing`, `phpunit-unit-test-debating`, `phpunit-unit-test-defending` (all wave-internal — they require consensus context, peer SendMessage channels, or adversary challenges as inputs), and `phpunit-migration-test-reviewing` (invoked by the `test-reviewer` agent, mirroring `phpunit-unit-test-reviewing`). Migration reviewer description rewritten from user-trigger phrasing to "Invoked by the test-reviewer agent, not directly by users."

## [3.5.1] - 2026-04-19

### Changed
- Internal shellcheck cleanup in `shared/mcpserver_core.sh`. No behavior change. The `log()` function now splits `local line` from its assignment so the `local` builtin no longer masks `date`'s exit status (SC2155).

## [3.5.0] - 2026-04-16

### Added
- **DESIGN-010 — Guard Clause Isolation in Arrange**: New `should-fix` rule for categories B, C, D. When testing one early-return condition in a method with multiple sequential guards, the arrange section must satisfy all other guards so only the intended exit path can fire. Prevents tests that pass for the wrong reason.

### Changed
- **UNIT-001 — PHPStan type narrowing exceptions**: Added detection guidance for `assertIsArray`, `assertInstanceOf`, etc. that narrow a PHPStan union type for a subsequent assertion. These are not trivially true and must not be removed. Conversely, `assertInstanceOf` on a method with a single non-nullable return type IS trivially true and should be flagged.
- **Category B template**: Added arrange comment in the configuration test pattern reminding the generator to satisfy all other guard clauses (DESIGN-010).
- **Category C template**: Same arrange comment in edge-case test patterns for event subscribers and flow actions.

## [3.3.4] - 2026-04-13

### Fixed
- All SKILL.md files: bare-path references to bundled `references/` and `templates/` files across all eight skills, so progressive disclosure loads them correctly.

## [3.3.3] - 2026-04-13

### Changed
- **Generation reference `category-detection.md`**: Removed the Template column from the Category Overview table. The category-to-template mapping is already owned by `phpunit-unit-test-generation/SKILL.md`, and reference files cannot predictably point at sibling bundled files under progressive disclosure.
- **Generation reference `test-requirement-rules.md`**: Removed a vestigial `See SKILL.md Step 1 for matching rules.` pointer. The preceding sentence already covers the exclusion gate, and cross-references from reference files are forbidden.

## [3.3.2] - 2026-04-13

### Changed
- **UNIT-007 — Deprecation Guard Required**: Corrected the rule's understanding of the Shopware unit test feature flag lifecycle. `FeatureFlagExtension` force-activates all registered flags before every unit test, so `Feature::skipTestIfActive()` without a matching `#[DisabledFeatures]` silently skips the test body, and `Feature::skipTestIfInActive()` is dead code. Decision table, detection algorithm, and all examples now treat `#[DisabledFeatures]` as the sole mechanism for deactivating a flag in unit tests. Detection algorithm expanded with three new violation kinds: silently-skipped-unit-test, dead-deprecation-guard, and redundant-guard. `Feature::silent()` / `callSilentIfInactive()` guidance unchanged.
- **UNIT-010 — No Error Suppression on Deprecated Code**: Fix example now uses `#[DisabledFeatures(['v6.8.0.0'])]` instead of the broken `Feature::skipTestIfActive()` pattern. Body text no longer claims `skipTestIfActive()` makes a flag inactive.
- **Generation reference `deprecation-guards.md`**: Mirrors the UNIT-007 corrections. New-behavior section now shows an unguarded test.

## [3.3.1] - 2026-04-11

### Changed
- **Reviewing skill context reduction**: Collapsed 5 identical rule-group phases into a single parameterized section with a group table. Replaced `list_rules` + `get_rules(ids=...)` two-step pattern with direct `get_rules` filter mode across all reviewing skills.
- **Reference file trimming**: Removed redundant examples from output-format.md files (reviewing, migration-reviewing, generation). Trimmed category detection references to decision tree and indicators only.

### Removed
- **`list_rules` MCP tool**: The `get_rules` tool supports the same filter parameters directly. Removed tool definition, implementation (`lib/list.sh`), and all references from skills, agents, and documentation.

## [3.3.0] - 2026-04-10

### Added
- **Scoped review mode**: Reviewing skill accepts optional method names to restrict reviews to changed/added methods. When reviewing tests from a branch or PR, only violations in scoped methods are reported. Pre-existing issues in untouched methods are ignored.
- **`class-scope-only` rule property**: Rules can declare `class-scope-only: true` in frontmatter to be excluded from method-scoped reviews. Applied to UNIT-002, CONV-005, CONV-007.
- **`scoped_review` MCP filter**: `list_rules` and `get_rules` accept `scoped_review=true` to exclude class-scope-only rules.
- **Diff-to-method resolution**: Team-reviewing input resolution resolves commit/branch/PR diffs to per-file method scope and threads it through all wave spawn prompts.

### Changed
- Reviewing skill marked `user-invocable: false` — always invoked through agents or orchestrators
- Team-reviewing wave prompts include method scope for reviewers, adversaries, debaters, and defenders
- Output format includes `Scope` field in summary

## [3.2.2] - 2026-04-10

### Changed
- **UNIT-007 — Deprecation Guard Required**: Recognizes `Feature::silent()` and `Feature::callSilentIfInactive()` as valid guard patterns. Updated detection algorithm to scan source for these calls, accept them as method-level guards, and flag misuse (using `Feature::silent` when source doesn't). Added example section for incidental deprecated calls.
- **Generation references split for progressive disclosure**: Extracted `exception-patterns.md`, `mocking-patterns.md`, and `deprecation-guards.md` from `common-patterns.md`. SKILL.md references point to specific files at the phase where they're needed instead of loading the full 385-line file.

## [3.2.1] - 2026-04-10

### Changed
- Replaced explicit MCP tool lists with server-level wildcards (`mcp__plugin_dev-tooling_php-tooling`, `mcp__plugin_gh-tooling_gh-tooling`) in skill and agent frontmatter `allowed-tools`/`tools`
- Removed redundant Tool Usage Policy sections from unit test and migration test generation skills (policy is enforced by the MCP tools themselves)
- Collapsed orchestrator fix loop into a single validation step (was separate ECS fix, PHPStan, PHPUnit steps)

## [3.2.0] - 2026-04-08

### Added
- **UNIT-010 — No Error Suppression on Deprecated Code**: Must-fix rule forbidding `@` on deprecated code. Ineffective in Shopware's test infra: flag active → exception (unsuppressible); flag inactive → `TESTS_RUNNING` already silences.

### Changed
- **UNIT-007 — Deprecation Guard Required** (was `consider`, now `must-fix`): Replaces "DisabledFeatures for Legacy Tests" with full detection algorithm. Reads source for `@deprecated` and `triggerDeprecationOrThrow()`, verifies correct guard (`#[DisabledFeatures]`, `skipTestIfActive`, `skipTestIfInActive`) with matching direction. Decision table covers single-method, class-level, new-behavior, paired old/new, and multi-flag patterns.

## [3.1.0] - 2026-04-06

### Added
- **Migration test generation skill** (`phpunit-migration-test-generation`): Analyzes migration source classes to detect SQL patterns (schema-add, schema-remove, data-update, config, mail-template) and generates pattern-appropriate migration tests. Forks into `test-generator` agent via `context: fork`. Single template with conditional sections driven by source analysis.
- **Migration test reviewing skill** (`phpunit-migration-test-reviewing`): Reviews migration tests against 8 migration-specific rules. Pure instruction set (v3.0.0 pattern), no `context:` or `agent:` frontmatter.
- **8 migration rules** (MIGRATION-001 through MIGRATION-008): Idempotency (update/updateDestructive called at least twice), no helper method reuse, cleanup of test-created tables/data, separate try/catch with Throwable in setUp/tearDown, hardcoded SQL identifiers, assertSame over assertEquals, mandatory testGetCreationTimestamp.
- **Source analysis reference** (`references/source-analysis.md`): SQL pattern detection, updateDestructive analysis, helper method detection, trait selection table.
- **Migration test template** (`templates/migration-test.md`): Conditional template with schema-add, schema-remove, data-update, config, and mail-template sections.
- `"migration"` added to `group` enum in MCP server `tools.json` for both `list_rules` and `get_rules`.

### Changed
- `test-generator` agent description broadened from "unit tests" to "tests" (now serves both unit and migration generation skills).
- Plugin description updated to mention migration test support.

## [3.0.1] - 2026-04-05

### Fixed
- **Phase 9 broadcast error**: Lead attempted `SendMessage(to: "*")` after collecting defense stances despite "no shutdown messages" instruction. Strengthened Phase 9 to explicitly prohibit SendMessage calls before TeamDelete.
- **Agent name collisions across waves**: Spawn templates reused `reviewer-{n}` across waves, causing name collisions within the same team. Agent names now include wave suffix (`reviewer-{n}-{wave}`). Output contracts still use the stable `reviewer-{n}` identity.

## [3.0.0] - 2026-04-05

### Added
- **Debating skill** (`phpunit-unit-test-debating`): Peer-to-peer debate within Agent Teams wave. Reviewers debate directly via SendMessage (max 2 rounds), then output final stance. Replaces lead-mediated hub-and-spoke debate.
- **Defending skill** (`phpunit-unit-test-defending`): Defense against adversary challenges. Evaluates each challenge on merits, outputs defense stance with adversary impact tracking.

### Changed
- **BREAKING: Wave-based team orchestration**: Team-reviewing skill rewritten from persistent cross-wave agents to spawn-per-wave agents. Each wave spawns fresh agents with single-task instructions. Eliminates premature phase anticipation.
- **BREAKING: Skills are pure instruction sets**: Reviewing and adversarial-reviewing skills drop `context: fork` and `agent:` frontmatter. Callers must spawn agents explicitly via `Agent(agent: "test-writing:test-reviewer")`.
- **BREAKING: Standalone orchestrator invocation**: `phpunit-unit-test-writing` Phase 3 spawns `test-reviewer` agent instead of calling reviewing skill directly.
- **Agent definitions generalized**: `test-reviewer` and `test-adversary` agents updated as generic execution environments. Input validation removed from agents (provided by skills).
- **Error handling rewritten**: Wave-level recovery replaces idle-agent reminder/retry pattern.

### Removed
- `spawn-prompt.md`, `adversary-spawn-prompt.md`: Lead assembles wave-specific prompts inline.
- `debate-protocol.md`: Rules absorbed into debating skill.
- `adversary-protocol.md`: Rules absorbed into defending skill.

## [2.6.1] - 2026-04-04

### Fixed
- **Premature defense stances in team review**: Reviewers fabricated adversary arguments and sent defense stances before team-lead distributed actual challenges. Caused by Phase 4 (Defense) instructions visible in spawn prompt from the start, priming the model to anticipate the next phase instead of waiting. Fix: removed Phase 4 and shutdown instructions from reviewer spawn prompt. Defense round rules are now delivered inline in the Phase 7 SendMessage. Reviewers only learn about defense when it happens.

## [2.6.0] - 2026-04-04

### Added
- **Adversarial reviewing skill** (`phpunit-unit-test-adversarial-reviewing`): 6-phase red team skill that forms independent judgment via intuitive code scan before consensus exposure, then challenges weak findings using MCP rule evidence. Two-phase cognitive model: intuition proposes, evidence disposes.
- **test-adversary agent**: Read-only execution environment (`model: sonnet`, `color: red`), maintains parity with test-reviewer for debate balance.
- **Skill references**: `intuitive-scan-guidance.md` (heuristic lenses for rule-free code analysis), `comparison-strategies.md` (contrast intuition against consensus), `output-format.md` (challenges/resurrections/endorsements contract).

### Changed
- **Explicit agent types in team spawning**: `subagent_type: "general-purpose"` replaced with `agent: "test-writing:test-reviewer"` / `agent: "test-writing:test-adversary"`.
- **Adversary workflow restructured**: Spawn prompt delegates to skill. Adversaries form impressions concurrently during reviewer Phases 3-5 (no added wall-clock time). Protocol trimmed to Defense Round Rules only — behavioral rules moved into skill.
- **Terminology**: "advocate" / "devil's advocate" renamed to "adversary" throughout. Field names updated (`advocate_impact` -> `adversary_impact`, `advocate_challenges` -> `adversary_challenges`, etc.).

## [2.5.0] - 2026-03-30

### Added
- **UNIT-009 — No dedicated tests for abstract classes**: Must-fix rule forbidding test classes that cover abstract classes directly. Detects `abstract class` in the `#[CoversClass]` target. Generator validation gate and test-requirement-rules updated to skip abstract classes alongside interfaces and traits.

## [2.4.0] - 2026-03-27

### Added
- **Red team debate round** (`phpunit-unit-test-team-reviewing`): After round 1 consensus, 1-2 devil's advocate agents challenge accepted findings, resurrect premature withdrawals, and introduce new violations. Original reviewers defend under adversarial rules where "I already conceded" is not a valid defense. Round 2 defense stances become the binding input to consensus merge. Advocates influence through argumentation but do not vote. Red team round is conditionally skipped when there are zero findings or round 1 debate was already substantive.
- **Advocate protocol reference** (`advocate-protocol.md`): Six adversarial rules for advocates (challenge bias, resurrection with evidence, new findings permitted, target weak concessions, substantive challenges only, cross-file patterns) plus four defense round rules for reviewers.
- **Advocate spawn prompt template** (`advocate-spawn-prompt.md`): Spawn prompt for devil's advocate agents — idle until activated, red team phase, shutdown.
- **Red team context package reference** (`red-team-context.md`): Defines skip conditions and the YAML context package format (consensus findings, withdrawn findings with reasons, debate transcript).

### Changed
- **Phase numbering**: Verdicts & Report is now Phase 8 (was Phase 6), Cleanup is now Phase 9 (was Cleanup without number). New Phases 6 (Red Team) and 7 (Defense Round) inserted between Final Stances and Verdicts.
- **Team Setup spawns advocates**: Phase 2 now spawns advocate agents alongside reviewers. Advocates go idle until Phase 6.
- **Reviewer spawn prompt extended**: Phase 4 (Defense) added — reviewers respond to advocate challenges after round 1.
- **Message formats extended**: `advocate_challenges` (Red Team) and `defense_stance` (Defense Round) formats added.
- **Report format extended**: Per-finding `advocate_impact` annotations, Red Team Impact summary section, `red_team` block in output contract YAML.
- **Reviewer allocation extended**: Advocate count formula (1 for N≤3, 2 for N>3) and file partitioning for advocates.
- **Error handling extended**: Advocate failure scenarios (no challenges, partial engagement, context limits) and defense round failures (no response, partial engagement).

## [2.3.2] - 2026-03-27

### Fixed
- **Team review input resolution skipped**: SKILL.md Phase 1 now requires `Read` of input-resolution.md before any git or file discovery commands. Previously the reference was linked but not enforced, allowing the model to skip it and act on assumptions.
- **Cross-skill category detection removed from input resolution**: Input resolution no longer reads source classes or detects categories — that is the reviewing skill's responsibility. Removes cross-skill dependency on `phpunit-unit-test-reviewing/references/test-categories.md`.

### Changed
- **Plain file paths in references**: Replaced all markdown link syntax (`[file.md](path)`) with plain relative paths in SKILL.md and reference files. Prevents progressive disclosure from being blocked by path interpolation.

## [2.3.1] - 2026-03-27

### Fixed
- **Team review base branch detection**: Branch-based input resolution no longer hardcodes `main`/`master` as the base branch. Now asks the user for the base branch, correctly handling stacked branches where a feature branch is based on another feature branch.

## [2.3.0] - 2026-03-27

### Changed
- **Team review supports multiple files**: `phpunit-unit-test-team-reviewing` now accepts flexible input (file paths, commits, branches, PRs, directories) and resolves to a list of test files. Variable reviewer pool (3-5) with balanced round-robin file assignment ensures each file is reviewed by 3 reviewers while no reviewer sees all files (diversified perspectives). Cross-file references during debate allow reviewers to cite patterns from other files as evidence. Per-file consensus reports plus a cross-file consistency section identify pattern divergences and recommend alignment.
- **Progressive disclosure**: SKILL.md refactored from 403-line monolith to ~200-line orchestrator with 6 new reference files (input-resolution, reviewer-allocation, spawn-prompt, message-formats, report-format, error-handling). Reference files cross-reference each other for transitive loading.
- **Debate protocol extended**: Rules 8-10 added for cross-file references — valid evidence, first-hand only, supporting argument not standalone finding. Message format examples moved to dedicated message-formats.md.

## [2.2.1] - 2026-03-26

### Fixed
- **Team review spawn prompt**: Clarified phase transition instructions to prevent reviewers from resending previous phase responses. Each phase now explicitly names the expected `type:` value and the preceding phase's type to avoid. Consolidated rules to "one SendMessage per phase, then go idle."

## [2.2.0] - 2026-03-26

### Added
- **Team-based test review skill** (`phpunit-unit-test-team-reviewing`): Consensus-based review using Claude Code Agent Teams. Three independent reviewers analyze a test file in parallel, participate in a structured one-round debate (challenges, endorsements, concessions citing detection algorithms), and submit final stances. The lead merges results using majority voting (2-of-3 or 3-of-3 agreement) with dissent annotations for minority opinions and a contested section for 1-of-3 findings. Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.
- **Debate protocol reference** (`debate-protocol.md`): Seven rules governing structured inter-reviewer debate — evidence-based challenges, no new findings during debate, binding final stances with mandatory withdrawal reasons.

## [2.1.2] - 2026-02-26

### Fixed
- **Align delegation skip logic across all sources**: Pure delegation methods (forwarding to a dependency without transformation) were documented as skip-worthy in category-b-service template but missing from the core decision tree (`test-requirement-rules.md`), the generation skill quick check (`SKILL.md`), and the review rule (`UNIT-001.md`). All three now include delegation patterns with examples for both skip and needs-test cases.

## [2.1.1] - 2026-02-26

### Changed
- **PHPUnit invocations use `result-only` output format**: Both the orchestrator fix loop (Phase 4, Step 4) and the generation skill (Phase 4, Step 3) now invoke `phpunit_run` with `output_format: "result-only"` first, re-running with default output only when tests fail. Reduces token usage on passing runs.

## [2.1.0] - 2026-02-26

### Added
- **Coverage exclusion offer (Phase 2)**: When a source file is SKIPPED because it has no testable logic, the orchestrator offers to add it to `phpunit.xml.dist` `<exclude>` section so it doesn't show as 0% in coverage reports
- **`skip_type` field**: Generator output contract now distinguishes SKIPPED reasons — `coverage_excluded` (already in phpunit.xml.dist) vs `no_logic` (trivial file, no testable logic)
- **Multi-file batch exclusion**: When processing multiple files, collects all trivial files and presents a single batch prompt to add them all to coverage exclusions
- SKIPPED-with-exclusion report template in report-formats reference

### Changed
- Orchestrator Phase 1 decision table now branches on `skip_type` instead of treating all SKIPPED statuses identically
- Orchestrator file write restrictions expanded to allow user-confirmed edits to phpunit.xml.dist `<exclude>` entries (Phase 2 only)

## [2.0.3] - 2026-02-26

### Removed
- **`resolve_legacy` MCP tool**: Deleted tool and all supporting infrastructure (`resolve.sh`, `LEGACY_TO_ID`/`RULE_LEGACY` arrays)
- **Legacy E/W/I identifiers**: Removed `legacy` frontmatter from all 46 rule files, legacy code columns from `list_rules` output, and Legacy metadata line from `get_rules` output
- Legacy identifier references from skill instructions, output-format templates, and documentation

## [2.0.2] - 2026-02-25

### Added
- **Filter mode for `get_rules` MCP tool**: `get_rules` now accepts metadata filter parameters (`group`, `test_type`, `test_category`, `scope`, `enforce`) as an alternative to ID-based lookup
- **Shared `_filter_rules()` helper**: Extracted common filtering logic reused by both `list_rules` and `get_rules`

## [2.0.1] - 2026-02-25

### Fixed
- **Phase execution enforcement**: Clarified that "Report after" directive applies to communication only — workflow phases must still execute regardless of reporting threshold
- **NEEDS_ATTENTION routing**: NEEDS_ATTENTION status now routes through the fix loop before escalating to user decision, instead of escalating immediately
- **Skill invocability**: Marked `phpunit-unit-test-generation` as `user-invocable: false` to prevent direct invocation outside the orchestrator

## [2.0.0] - 2026-02-25

### Added
- **test-rules MCP server**: Rule content served dynamically via `list_rules`, `get_rules`, and `resolve_legacy` tools — replaces static reference file loading in the reviewing skill
- **rules/ directory**: Individual rule files organized by group (convention, design, unit, isolation, provider), auto-discovered by MCP server
- **shared/mcpserver_core.sh**: Reusable MCP server library for stdio JSON-RPC transport
- **.mcp.json**: MCP server configuration for the bundled test-rules server

### Changed
- **Breaking**: Reviewing skill rewritten from static 14-phase reference-file workflow to MCP-driven rule-group workflow (convention → design → unit → isolation → provider) — loads only rules applicable to detected test category
- **Breaking**: All three original agents replaced by two thin fork targets: `test-generator` (acceptEdits) and `test-reviewer` (read-only) — skills fork into agents via `context: fork`
- **Breaking**: Fix loop moved from `phpunit-unit-test-reviewer-fixer` agent to orchestrator skill (inline, max 4 iterations with oscillation detection)
- Orchestrator uses `Skill` tool (not `Task`) for generation and review invocations
- Orchestrator uses `Edit` + MCP tools directly for fix-loop validation
- Each skill consumed exactly one way (`context: fork`), no dual consumption

### Removed
- `agents/phpunit-unit-test-generator.md` — replaced by `agents/test-generator.md`
- `agents/phpunit-unit-test-reviewer-fixer.md` — fix loop absorbed by orchestrator
- `agents/phpunit-unit-test-reviewer.md` — replaced by `agents/test-reviewer.md`
- 7 reviewing reference files (`error-code-details-structure.md`, `error-code-details-style.md`, `error-code-summary.md`, `mocking-strategy.md`, `phpunit-conventions.md`, `shopware-stubs.md`, `test-case-justification.md`) — rule content now served by MCP server
- `feature-flags.md` reviewing reference — content moved to `rules/unit/UNIT-007.md`

## [1.2.8] - 2026-02-24

### Added
- **W016** — Single-use test property: flags properties assigned in `setUp()` but referenced in only one test method; fix is to inline the construction at the usage site
- **W017** — `Test` prefix on non-test helper class: the `Test` prefix is reserved for classes extending `TestCase`; helper classes should use `Stub*`, `Fake*`, or a role-based name
- **W018** — Description-only data provider parameter: flags parameters used only for `#[TestDox]` interpolation; fix is to use `$_dataName` (resolves to yield key automatically)

### Fixed
- **Generation**: Skip test generation for source files excluded from coverage by `phpunit.xml.dist` — checks `<directory suffix>` and `<file>` exclusion rules before analyzing the class, returns SKIPPED when matched
- **E018**: Decoration pattern test example now uses `expectExceptionObject()` instead of bare `expectException()` — aligns with E018 rule since `DecorationPatternException` has a parameterized constructor
- **Generation**: `phpunit-conventions.md` Pattern 3 example corrected to use `$_dataName` instead of a `$description` parameter — prevents generating the anti-pattern W018 now detects

## [1.2.7] - 2026-02-23

### Fixed
- **E008**: Strengthened `expectException*()` exception guidance to prevent false positives — Phase 3 instruction now explicitly states both directions (flag `static::expectException*()`, do NOT flag `$this->expectException*()`); Quick Reference table pattern narrowed from `$this->assertEquals()` to `$this->assert*()` with inline exclusion note

## [1.2.6] - 2026-02-21

### Added
- **W015** — Data provider uses `return []` instead of `yield`/`iterable`: flagged as a warning, fix is to convert to `yield` statements

### Changed
- **E019**: Replace `expects($this->any())` with `expects($this->atLeastOnce())` — `any()` permits 0 invocations so callbacks with assertions could silently never fire; added Scenario B to flag `->with(static::callback(...))` chains that lack `->expects()`
- **E008**: `expectException*()` setup methods must use `$this->`, not `static::`
- **W007**: Require verb-first provider names; adjective/noun starts are flagged

## [1.2.5] - 2026-02-20

Regression fixes from second real-world review (95-file ContentSystem suite). Corrects three rules that caused behavioral assertions to be silently lost during automated fixing.

### Fixed
- **W012**: Detection now correctly excludes `createMock()` when `->with(static::callback(...))` argument verification is present — argument callbacks justify `createMock()` as much as `expects()` does; the previous rule caused W012 to fire and the fixer to strip the callback assertions
- **E019**: Fix pattern now branches on whether `->with(static::callback(...))` is present — if so, replace `expects($this->once())` with `expects($this->any())` instead of removing `expects()` entirely; PHPUnit silently ignores `->with()` constraints without `expects()`, so full removal discarded argument assertions
- **E009**: Phase 11 fix step now explicitly prohibits: (1) deleting a test method that is the sole coverage of any code path, and (2) collapsing a data provider test into a single parameterless test with inline assertions (which creates W002)

### Added
- **W014** — `#[Package(...)]` attribute on test classes: Shopware's source-class ownership annotation has no meaning on test classes; flagged as a warning, fix is removal
- **I009** — Duplicated inline Arrange code: informational suggestion when two or more test methods repeat ≥ 5 identical lines of object construction that could be extracted to `setUp()` or a private helper

## [1.2.4] - 2026-02-19

### Fixed
- Corrected invocation matcher methods (`once()`, `never()`, `exactly()`) to use `$this->` instead of `static::` in all code examples and skill instructions — ECS enforces this distinction (invocation matchers are instance methods, not static assertion helpers)
- Clarified E008 scope: `static::` applies to assertion methods (`assert*`, `expect*`) only; invocation matchers inside `->expects()` require `$this->`

## [1.2.3] - 2026-02-19

Improvements derived from real-world test generation experience (content system, 66 test files, 17 improvement iterations). Encodes the most frequently recurring fix patterns directly into generation templates and the reviewing skill.

### Added
- **E018** — Weak exception assertion: flags `expectException(Foo::class)` without `expectExceptionMessage()`, `expectExceptionCode()`, or `expectExceptionObject()` for parameterized exceptions (was the single most pervasive issue in practice, affecting 13+ files)
- **E019** — Call-count over-coupling: flags `expects($this->once())->method()->willReturn()` when the test already asserts the returned value, making the call-count redundant (affected 9 files)
- **W012** — `createMock()` when `createStub()` would suffice: flags `createMock()` on variables where no `expects()` call is ever made (16 files converted in one sweep in practice)
- **W013** — Opaque test data identifiers: flags 32-char hex UUID strings used as test IDs when descriptive strings (`'product-id'`) would be clearer

### Changed
- **Category B template**: uses `createStub()` by default; `createMock()` only in explicitly labeled side-effect verification sub-section; exception error cases now always include `expectExceptionMessage()` at minimum
- **Category E template**: `expectExceptionObject()` is now the primary pattern; data provider pattern uses `\Throwable $exception` for full object matching; all factory-method examples assert error code + status code + message
- **`essential-rules.md`**: added `createStub` vs `createMock` distinction; added Test Data Identifiers section
- **`common-patterns.md`**: new "Stub vs Mock" section with intersection type reference; exception testing leads with `expectExceptionObject()`; `expects(once())` moved to labeled side-effect sub-section; added Decoration Pattern Testing section
- **`mocking-strategy.md`**: new top-level `createStub()` vs `createMock()` section with call-count over-coupling anti-patterns
- Reviewing skill overview updated to 19 error codes, 13 warnings
- E005 expanded to explicitly include call-count verification on non-side-effect methods as a detection pattern

## [1.2.2] - 2025-12-19

Issues discovered during test generation for `Shopware\Core\Content\ContentSystem\Output\SubTreeExtractor` class.

### Changed
- Final status now reports as COMPLIANT or NON-COMPLIANT instead of PASS/ISSUES_FOUND
- E-codes are mandatory compliance failures; W-codes are optional improvements

### Fixed
- Fixer agent now attempts ALL E-codes, not just tool validation errors
- No longer prompts for confirmation on NON-COMPLIANT status
- Re-invokes fixer when fixes failed due to dependencies and iterations remain

## [1.2.1] - 2025-12-18

### Changed
- Updated MCP tool references from `php-tooling` plugin to `dev-tooling` plugin
- Documentation now references `dev-tooling` as the required dependency

## [1.2.0] - 2025-12-18

### Changed
- **Breaking**: Split reviewer into `phpunit-unit-test-reviewer` (read-only) and `phpunit-unit-test-reviewer-fixer` (edit-capable with internal fix loop)
- Fixer agent handles iterations internally (up to 4) with oscillation detection
- Significant reduction in main context tool calls (Edit + MCP isolated to fixer agent)
- Extended output contract with `iterations_used`, `fixes_applied`, `oscillation_detected`
- Read-only reviewer cannot modify files (security improvement)

## [1.1.0] - 2025-12-17

### Changed
- Enhanced E009 (test redundancy) detection with explicit code path analysis algorithm
- Added source class reading requirement in Phase 1 for code path identification
- Added worked example showing test method merge pattern (`SubTreeExtractor`)

### Fixed
- E009 now correctly detects methods exercising same code path (discovered via real-world test generation)

## [1.0.0] - 2025-12-16

### Added
- Three-tier skill system: generation, review, and orchestration
- Generator and reviewer agents for input validation
- Test categories with category-specific templates (DTO, Service, Flow/Event, DAL, Exception)
- Error, warning, and informational codes for compliance validation
- Review loop with oscillation and stuck loop detection
- PHPStan/PHPUnit/ECS validation via php-tooling MCP integration
- Shopware testing references (stubs, feature flags, mocking strategy)
