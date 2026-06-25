# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.8.17] - 2026-06-25

### Fixed
- `phpunit-unit-test-team-reviewing` no longer stalls before launching the team-review workflow (redundant advisor consults, reading the committed workflow script to "confirm" the contract, front-loading later-phase references). The advisor-suppression and committed-script-only disciplines moved from the "Execution posture" preamble — read once at load, not held at the launch decision — to the Phase 3 launch step where the decision is made, and that preamble section was removed. Phase 2 now states the rule catalog is large by design and is passed inline through `args` (no file/path channel needed, not a reason to read the script or consult the advisor).

## [3.8.16] - 2026-06-25

### Added
- Team review runs a second peer-reconciliation pass on units still contested after Wave 1 (max two passes) before forming the preliminary consensus.
- The red-team adversary now receives a fuller context package — consensus findings, withdrawn findings (with their Wave-0 reporters and withdrawal reason), and each reviewer's reconciliation record.

### Changed
- Team-review reference files (`workflow-design`, `reviewer-allocation`, `consensus-and-verdicts`, `agent-guardrails`, `red-team-context`) are now adaptation guides over the committed Workflow script, which is the source of truth: each keeps its load-bearing rules plus a "what you can adapt / already handled" surface. Cross-references between reference files were removed; file pointers live in `SKILL.md`.
- Active-voice and anti-bloat cleanup across the team-review skill, its references, and the sidecar skills (`phpunit-unit-test-reviewing`, `-adversarial-reviewing`, `-reconciling`): removed leftover "(unchanged behavior)" notes and an unreachable terminal-command guardrail (the rule-file ban is preserved), and converted narration to imperative. No review-behavior change.

### Fixed
- Report output contract declares `summary.files_with_issues` and `red_team.coverage_gap`, and the adversary coverage gap is now rendered.

## [3.8.15] - 2026-06-25

### Changed
- Commit the parameterized team-review Workflow script (`workflow/team-review.workflow.mjs`); the skill now launches it via `scriptPath` with the run manifest as `args` instead of re-authoring the script each run. The script encodes the full wave shape, every cap as a constant (including the re-instated `BUDGET_FLOOR=60000` and `ARB_CAP=15`), the six adaptation points, `RESPAWN_MAX=2` re-spawn, per-unit rule scoping, the static `T=450` threshold, and per-spawn model pinning. No new review behavior.
- Rule delivery: build the full catalog once and pass it in `args`; the script selects each agent's scoped `## RULES` block in-process — byte-identical to a scoped `build_rule_package`, CI-guarded by `selection_equivalence.bats`.
- Team-review references demoted to the design spec / prompt-template source the script implements; the Phase-1 manifest now carries `test_methods` so the script can shard a full-class Track B file.

### Removed
- Deleted the stale `team-review-workflow.mjs` research artifact; no runtime file referenced it.

## [3.8.14] - 2026-06-24

### Changed
- Raise the team-review Track-B threshold `T` from 300 to 450 (combined test+source lines), so files that comfortably fit an agent's context no longer over-decompose — fewer agents, less exposure to transient `529`. The track decision stays a static line-count threshold; reference text only. `T=450` is a pending-validation seed.

## [3.8.13] - 2026-06-24

### Changed
- Reconciling output contract now requires the one-line visible acknowledgment; it previously defined only the YAML schema and silently overrode the universal guardrail (the source of the residual "no visible output" retries).
- `phpunit-unit-test-team-reviewing` trigger scoped to unit tests in `tests/unit/`, so it no longer matches integration-test review requests it cannot serve.
- `## Execution posture` narrowed to forbid meta-reviewing the skill's design while still permitting the pre-launch input-fit check (unit-vs-integration, source-path existence).

## [3.8.12] - 2026-06-24

### Changed
- `build_rule_package` renders a scoped subset (`review_unit` / `test_category` / `scoped_review`); each agent gets only its track's `## RULES`, fixing the "Prompt is too long" deaths caused by injecting the full 49-rule catalog into every agent.
- Finding-reasoning waves carry a minimal rule payload: the arbiter gets only the contested rule, the peer and defense reconcilers only the rules their findings reference, the red team the category-scoped catalog.
- Bounded re-spawn (`RESPAWN_MAX=2`) of a dead unit/agent before graceful degradation — only that unit, never the whole fleet; an un-red-teamed in-scope file now raises a coverage-gap flag in `red_team` instead of being presented as complete coverage.

## [3.8.11] - 2026-06-21

### Changed
- Switch team-review rule delivery from a file path to inline prompt text — agents were grep-paging the catalog file instead of reviewing code. The orchestrator now reads the package once and hands each agent the rendered catalog as a `## RULES` block; `agent-guardrails.md` forbids opening any rule file by any means. The `{rules_file}` path input becomes `{rules}` inline text (Supplied-Rules Mode → Inline-Rules Mode) on the three review sub-skills; the selection predicate is byte-for-byte unchanged. Standalone single-reviewer flow unaffected (`get_rules` when `{rules}` is omitted).

## [3.8.10] - 2026-06-21

### Fixed
- Harden team-review instructions against a misbehavior where the executor audited the skill instead of running it (filesystem search, diffing a stale script, re-verifying input contracts). A front-loaded `## Execution posture` section makes the orchestrator-posture rules hard directives: do not consult the advisor, do not search the filesystem for artifacts to reuse, do not re-verify the references. Agent descriptions reworded so they no longer imply a pre-existing workflow artifact; `input-resolution.md` gains a shared-code ripple rule (a change to `setUp`/`tearDown`, a helper, a provider, or a shared property scopes the file full-class).

## [3.8.9] - 2026-06-21

### Changed
- Skip Wave-1 peer reconciliation for a unit when all three of its Wave-0 stances carry zero findings — nothing to reconcile, so no reconciler agents are spawned for it. The gate is zero-findings-only (a single finding still obliges reconciliation) and is output- and concession-rate-neutral. The `adaptation` field now reports the skipped-unit count.

## [3.8.8] - 2026-06-21

### Changed
- Require team-review agents to emit one short visible line alongside their structured output, removing the "no visible output" retry where a schema-bound turn produced no text and the agent burned a full turn re-reading context. The universal guardrail flips from "structured output only" to a one-line-summary contract; the `test-reviewer` and `test-adversary` definitions drop the text-forbidding line. Standalone flow unaffected.

## [3.8.7] - 2026-06-21

### Added
- `build_rule_package` MCP tool on the bundled `test-rules` server: renders the five unit-review groups (49 rules) once at composition time to a file under `$CLAUDE_PLUGIN_DATA` and returns its path, so team-review agents read the catalog from a file instead of each fetching it via `get_rules`. Output is byte-identical to concatenating `get_rules` over the groups (golden-tested), and it fails hard on an unset `CLAUDE_PLUGIN_DATA`, a write failure, or zero rendered rules. A new optional `{rules_file}` input (Supplied-Rules Mode) on the three review sub-skills selects rules from the package; standalone flow is unchanged when it is omitted.

## [3.8.6] - 2026-06-20

### Changed
- Pin team-review agent models explicitly on every spawn instead of stating the tiers as a fact — an unpinned spawn would silently inherit the session model, and the opus roles had no agent type to source opus from.
- Retier the cross-file consistency agent from opus to sonnet: its input is a pre-extracted structural fingerprint, not raw code, so opus was over-provisioned.

### Fixed
- Correct the stale `plugin.json` team-review description ("Wave-based Agent Teams … peer-to-peer debate") to match the Workflow migration ("Workflow-based team review … shared blackboard, no agent-to-agent messaging").

## [3.8.5] - 2026-06-20

### Changed
- Consensus merge now preserves the most complete remediation per finding: a new "Remediation payload" rule takes the superset suggestion, combines genuinely distinct sub-actions, and never picks an arbitrary stance's payload. Only `suggested` content changes; the set of findings and every status is unchanged.
- The `phpunit-unit-test-writing` fix loop applies the reviewer's `suggested` fix verbatim rather than re-summarizing or narrowing it; a wrong-looking fix is applied as given and caught by the existing re-review and oscillation handling.
- Record the fix-application fidelity contract for a future team-review fix phase (`AGENTS.md`, documentation only — team review is read-only today).

## [3.8.4] - 2026-06-20

### Changed
- Rename the rule review-mode classifier from `class-scope-only: true` to `scoped-review: include | exclude`, whose name no longer collides with the neighbouring input-axis `review-unit` field. The field is required, CI-validated, and fail-hard at index time. Behavior-preserving: the `exclude` set is exactly the rules that carried `class-scope-only: true` (CONV-005, CONV-007, UNIT-002, INTEGRATION-008), so `get_rules(scoped_review=true)` returns the same set.

### Removed
- The `class-scope-only` rule frontmatter property, retired in favor of `scoped-review`.

## [3.8.3] - 2026-06-20

### Fixed
- Team review no longer overflows the 200K context window on large test files or changesets. Each agent's work unit is decomposed deterministically from line counts against fixed thresholds: a file with combined test+source ≤ `T` (300) stays one full-class unit (3 reviewers, all rules); a larger file shards its methods into groups of ≤ `M` (8) plus a whole-class set, which above `C` (800) degrades to a body-free structural-digest review that emits a "split this test class" entry. A per-file reviewer cap `U_file` (18) bounds the pathological case, and round-robin file bundling is removed (one unit per reviewer).
- The cross-file consistency agent ingests a fixed-size structural fingerprint per file instead of every file's full consensus, so its input no longer scales with finding volume; above `F_cap` (40) files it shards by pattern dimension.
- Large changesets auto-partition into sequential chunks of ≤ `G` (300) projected reviewers, with one global cross-file pass over all fingerprints. Adversaries scale as `⌈N / K_adv⌉` (`K_adv` = 6).

### Added
- Internal `review_unit` and `digest` inputs on `phpunit-unit-test-reviewing` (the `user-invocable: false` sub-skill) — the plumbing the decomposition rides on. Both default off, so existing callers and small-file reviews behave exactly as before.

## [3.8.2] - 2026-06-19

### Added
- `review-unit` rule classification field (`method` | `class-structure` | `class-bodies`) on every rule, declaring the minimal input a rule's detection algorithm needs. The `test-rules` MCP server indexes it, exposes it in each `get_rules` metadata header, and accepts a new `review_unit` filter. Required, CI-validated, and a hard error at index time on a missing or invalid value. Purely additive and behavior-preserving.

## [3.8.1] - 2026-06-19

### Fixed
- Stop the team-review skill leaking `Workflow` implementation details (authoring a "script", baking the manifest "as constants", launching "inline", recovering via "scriptPath"), which competed with the tool's own contract and made a session write the script into the project tree. The skill now treats `Workflow` as a blackbox — specifying the review design abstractly and running it via the tool. Trigger and report unchanged.

## [3.8.0] - 2026-06-19

### Changed
- Convert team review from Agent Teams to a Claude Code Workflow. The skill is now an authoring brief that resolves the input to a file manifest, authors a Workflow script, launches it via the `Workflow` tool, and renders the result; the orchestration logic (reviewer allocation, consensus merge, red-team skip, adversary-impact tagging) moves into the script as deterministic code. The `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` flag and the `TeamCreate`/`TeamDelete`/`SendMessage` tools are gone. Live peer debate becomes structured blackboard reconciliation (each reviewer receives peers' prior-wave findings in its prompt); cross-file consistency becomes a dedicated wave; reviewer allocation is reconceived (per-file fan-out for N ≤ 6, round-robin bundling for N ≥ 7). Trigger and report unchanged.

### Added
- `phpunit-unit-test-reconciling` skill — internal `user-invocable: false` sub-skill that re-evaluates findings against incoming critique and emits a binding revised stance in `peer` or `adversary` mode.

### Removed
- `phpunit-unit-test-debating` and `phpunit-unit-test-defending` skills, merged into `phpunit-unit-test-reconciling`; `SendMessage` from the `test-reviewer` agent and the `team-reviewing/references/message-formats.md` reference.

## [3.7.2] - 2026-06-11

### Removed
- Drop the role-persona sentences from all three agents and the team-reviewing skill ("You are a test generator." etc.) — persona prompting does not improve factual correctness, and every behavior they implied is enforced explicitly elsewhere (tool lists, scope constraints, agent descriptions, output contracts). No behavior change.

## [3.7.1] - 2026-05-13

### Changed
- All 12 skill descriptions rewritten to follow https://agentskills.io/skill-creation/optimizing-descriptions. User-facing skills (`phpunit-unit-test-writing`, `phpunit-migration-test-generation`, `phpunit-integration-test-generation`, `phpunit-integration-to-unit-migrating`, `phpunit-unit-test-team-reviewing`) lead with imperative "Use this skill when..." and list explicit trigger phrases sourced from prior descriptions and README. The 7 internal-only sub-skills (all with `user-invocable: false`) now share one minimal "Do not auto-activate" line — they should only trigger when another skill or agent invokes them by name. No behavior change.

## [3.7.0] - 2026-05-13

### Added
- `MIGRATION-009` — `setUp`/`tearDown` must not mutate DB state: new `must-fix` rule detecting DDL/DML inside lifecycle hooks (including `try/catch`), while permitting connection acquisition, PHP-side ID generation, and read-only fetches. Codifies the fix applied across 19 files in shopware/shopware PR #16799.

### Changed
- `MIGRATION-005` title and scope broadened from "in setUp/tearDown" to any cleanup site (one statement per try, catch `\Throwable`); MIGRATION-009 now owns where cleanup lives.
- Migration test template (Schema-Remove): the column restore moves from `tearDown()` to `testUpdateDestructive()` wrapped in `try/finally` (DDL is not transactional in MySQL).
- `phpunit-migration-test-reviewing` overview updated to "MIGRATION-001 through MIGRATION-009".

## [3.6.0] - 2026-05-12

### Added
- Integration test ruleset (`rules/integration/`, INTEGRATION-001..008): 8 rules covering integration-base usage, real-collaborator policy, transactional cleanup, determinism, independence, fixture-skip prohibition, setup-to-assertion balance, and a placement smoke check.
- Placement ruleset (`rules/placement/`, PLACEMENT-001..008): 8 deep-reasoning prompts, loaded only by the migrating skill.
- `phpunit-integration-test-generation` skill: detects a supported pattern (controller/route, scheduled-task, message-handler, indexer, DAL-persistence flow, multi-service) and generates a Shopware-compliant integration test, returning SKIPPED with a pointer to unit generation when the SUT is unit-shape. Validates via PHPStan/PHPUnit/ECS.
- `phpunit-integration-test-reviewing` skill: reviews integration tests against the ruleset, assuming correct placement; emits the INTEGRATION-008 smoke hint when assertion shape is entirely unit-shape.
- `phpunit-integration-to-unit-migrating` skill: user-invoked audit-and-migrate workflow that walks PLACEMENT-001..008, buckets into migrate/split/keep/delete, and applies one of 6 refactoring patterns after confirmation.
- MCP `group` enum extended with `integration` and `placement`.

### Changed
- The `test-generator` agent now serves three generation skills (unit, migration, integration); the file-write restriction is enforced per-skill in the invoking SKILL.md.

## [3.5.2] - 2026-05-07

### Changed
- Marked four sub-skills as model-only via `user-invocable: false` in their SKILL.md frontmatter so they no longer surface as user-triggerable skills: `phpunit-unit-test-adversarial-reviewing`, `phpunit-unit-test-debating`, `phpunit-unit-test-defending` (all wave-internal — they require consensus context, peer SendMessage channels, or adversary challenges as inputs), and `phpunit-migration-test-reviewing` (invoked by the `test-reviewer` agent, mirroring `phpunit-unit-test-reviewing`). Migration reviewer description rewritten from user-trigger phrasing to "Invoked by the test-reviewer agent, not directly by users."

## [3.5.1] - 2026-04-19

### Changed
- Internal shellcheck cleanup in `shared/mcpserver_core.sh`. No behavior change. The `log()` function now splits `local line` from its assignment so the `local` builtin no longer masks `date`'s exit status (SC2155).

## [3.5.0] - 2026-04-16

### Added
- `DESIGN-010` — Guard Clause Isolation in Arrange: new `should-fix` rule (categories B, C, D) requiring the arrange section to satisfy all other guards so only the intended early-return path can fire.

### Changed
- `UNIT-001`: added type-narrowing guidance — `assertIsArray`/`assertInstanceOf` that narrow a PHPStan union for a later assertion are not trivially true; `assertInstanceOf` on a single non-nullable return type is.
- Category B and C templates: arrange comment reminding the generator to satisfy other guard clauses (DESIGN-010).

## [3.3.4] - 2026-04-13

### Fixed
- All SKILL.md files: bare-path references to bundled `references/` and `templates/` files across all eight skills, so progressive disclosure loads them correctly.

## [3.3.3] - 2026-04-13

### Changed
- Generation reference `category-detection.md`: drop the Template column (the mapping is owned by `phpunit-unit-test-generation/SKILL.md`; reference files cannot point at sibling bundled files).
- Generation reference `test-requirement-rules.md`: drop a vestigial `See SKILL.md Step 1` pointer (cross-references from reference files are forbidden).

## [3.3.2] - 2026-04-13

### Changed
- `UNIT-007`: correct the Shopware unit-test feature-flag lifecycle — `FeatureFlagExtension` force-activates all flags, so `skipTestIfActive()` without `#[DisabledFeatures]` silently skips the body and `skipTestIfInActive()` is dead code. `#[DisabledFeatures]` is now the sole deactivation mechanism; detection gains silently-skipped-test, dead-guard, and redundant-guard kinds.
- `UNIT-010`: fix example uses `#[DisabledFeatures(['v6.8.0.0'])]` instead of the broken `skipTestIfActive()`.
- Generation reference `deprecation-guards.md` mirrors the UNIT-007 corrections.

## [3.3.1] - 2026-04-11

### Changed
- Reviewing skill context reduction: collapse 5 identical rule-group phases into one parameterized section with a group table; replace the `list_rules` + `get_rules(ids=...)` two-step with direct `get_rules` filter mode.
- Trim redundant examples from the reviewing/migration/generation `output-format.md` files and the category-detection references.

### Removed
- `list_rules` MCP tool (its filters are covered by `get_rules`): tool definition, `lib/list.sh`, and all references.

## [3.3.0] - 2026-04-10

### Added
- Scoped review mode: the reviewing skill accepts optional method names to restrict a review to changed/added methods; pre-existing issues in untouched methods are ignored.
- `class-scope-only` rule property to exclude a rule from method-scoped reviews (applied to UNIT-002, CONV-005, CONV-007).
- `scoped_review` MCP filter on `list_rules`/`get_rules`.
- Diff-to-method resolution: team-reviewing resolves commit/branch/PR diffs to per-file method scope and threads it through all wave spawn prompts.

### Changed
- Reviewing skill marked `user-invocable: false` (always invoked through agents or orchestrators).
- Team-reviewing wave prompts include method scope for reviewers, adversaries, debaters, and defenders.
- Output format includes a `Scope` field.

## [3.2.2] - 2026-04-10

### Changed
- `UNIT-007`: recognize `Feature::silent()` and `Feature::callSilentIfInactive()` as valid guard patterns; flag misuse.
- Split generation references for progressive disclosure: extract `exception-patterns.md`, `mocking-patterns.md`, and `deprecation-guards.md` from `common-patterns.md`, referenced per phase instead of loading the full 385-line file.

## [3.2.1] - 2026-04-10

### Changed
- Replaced explicit MCP tool lists with server-level wildcards (`mcp__plugin_dev-tooling_php-tooling`, `mcp__plugin_gh-tooling_gh-tooling`) in skill and agent frontmatter `allowed-tools`/`tools`
- Removed redundant Tool Usage Policy sections from unit test and migration test generation skills (policy is enforced by the MCP tools themselves)
- Collapsed orchestrator fix loop into a single validation step (was separate ECS fix, PHPStan, PHPUnit steps)

## [3.2.0] - 2026-04-08

### Added
- `UNIT-010` — No Error Suppression on Deprecated Code: `must-fix` rule forbidding `@` on deprecated code (ineffective in Shopware's test infra — flag active throws an unsuppressible exception, flag inactive is already silenced).

### Changed
- `UNIT-007` promoted from `consider` to `must-fix` with a full detection algorithm: reads source for `@deprecated`/`triggerDeprecationOrThrow()` and verifies the correct guard (`#[DisabledFeatures]`, `skipTestIfActive`, `skipTestIfInActive`) with matching direction.

## [3.1.0] - 2026-04-06

### Added
- `phpunit-migration-test-generation` skill: detects SQL patterns (schema-add, schema-remove, data-update, config, mail-template) and generates pattern-appropriate migration tests; forks into `test-generator` via `context: fork`.
- `phpunit-migration-test-reviewing` skill: reviews migration tests against 8 migration rules (pure instruction set).
- 8 migration rules (MIGRATION-001 through MIGRATION-008): idempotency, no helper reuse, cleanup of test-created tables/data, separate try/catch with Throwable in lifecycle hooks, hardcoded SQL identifiers, assertSame over assertEquals, mandatory `testGetCreationTimestamp`.
- Source-analysis reference (`references/source-analysis.md`) and migration test template (`templates/migration-test.md`).
- `migration` added to the `group` enum for `list_rules`/`get_rules`.

### Changed
- `test-generator` agent description broadened from "unit tests" to "tests"; plugin description mentions migration support.

## [3.0.1] - 2026-04-05

### Fixed
- Phase 9 broadcast error: prohibit `SendMessage` calls before `TeamDelete` after collecting defense stances.
- Agent name collisions across waves: spawn names now include a wave suffix (`reviewer-{n}-{wave}`); output contracts keep the stable `reviewer-{n}` identity.

## [3.0.0] - 2026-04-05

### Added
- `phpunit-unit-test-debating` skill: peer-to-peer debate within an Agent Teams wave (reviewers debate via `SendMessage`, max 2 rounds, then output a final stance).
- `phpunit-unit-test-defending` skill: defense against adversary challenges with adversary-impact tracking.

### Changed
- Breaking — wave-based team orchestration: the team-reviewing skill moves from persistent cross-wave agents to fresh spawn-per-wave agents, eliminating premature phase anticipation.
- Breaking — skills are pure instruction sets: reviewing and adversarial-reviewing drop `context: fork`/`agent:` frontmatter; callers spawn agents explicitly via `Agent(agent: "test-writing:test-reviewer")`.
- Breaking — `phpunit-unit-test-writing` Phase 3 spawns the `test-reviewer` agent instead of calling the reviewing skill directly.
- `test-reviewer`/`test-adversary` generalized as execution environments (input validation moves to skills); error handling rewritten to wave-level recovery.

### Removed
- `spawn-prompt.md` and `adversary-spawn-prompt.md` (prompts assembled inline), `debate-protocol.md` (absorbed into the debating skill), and `adversary-protocol.md` (absorbed into the defending skill).

## [2.6.1] - 2026-04-04

### Fixed
- Premature defense stances in team review: reviewers fabricated adversary arguments because Phase 4 (Defense) instructions were visible in the spawn prompt from the start. Defense rules are now delivered inline in the Phase 7 `SendMessage`, so reviewers only learn about defense when it happens.

## [2.6.0] - 2026-04-04

### Added
- `phpunit-unit-test-adversarial-reviewing` skill: 6-phase red-team skill that forms independent judgment via an intuitive code scan before consensus exposure, then challenges weak findings using MCP rule evidence.
- `test-adversary` agent: read-only execution environment (`model: sonnet`), maintaining parity with `test-reviewer` for debate balance.
- Skill references `intuitive-scan-guidance.md`, `comparison-strategies.md`, and `output-format.md`.

### Changed
- Team spawning uses explicit agent types (`agent: "test-writing:test-reviewer"` / `test-adversary`) instead of `subagent_type: "general-purpose"`.
- Adversaries form impressions concurrently during reviewer Phases 3-5 (no added wall-clock).
- Rename "advocate" / "devil's advocate" to "adversary" throughout (`advocate_impact` → `adversary_impact`, etc.).

## [2.5.0] - 2026-03-30

### Added
- `UNIT-009` — No dedicated tests for abstract classes: `must-fix` rule detecting an `abstract class` in the `#[CoversClass]` target; the generator skips abstract classes alongside interfaces and traits.

## [2.4.0] - 2026-03-27

### Added
- Red team debate round (`phpunit-unit-test-team-reviewing`): after round-1 consensus, 1-2 devil's-advocate agents challenge accepted findings, resurrect premature withdrawals, and introduce new violations; original reviewers defend (round-2 defense stances become the binding consensus input). Advocates argue but do not vote; skipped when there are zero findings or round-1 debate was already substantive.
- `advocate-protocol.md` (six adversarial rules + four defense-round rules), `advocate-spawn-prompt.md`, and `red-team-context.md` (skip conditions + YAML context-package format).

### Changed
- Phase renumbering: Verdicts & Report → Phase 8, Cleanup → Phase 9; new Phases 6 (Red Team) and 7 (Defense Round) inserted.
- Phase 2 spawns advocate agents (idle until Phase 6); the reviewer spawn prompt gains Phase 4 (Defense).
- Message formats gain `advocate_challenges` and `defense_stance`; report format gains per-finding `advocate_impact`, a Red Team Impact summary, and a `red_team` output block.
- Reviewer allocation gains an advocate-count formula (1 for N≤3, 2 for N>3); error handling gains advocate and defense-round failure scenarios.

## [2.3.2] - 2026-03-27

### Fixed
- Team review input resolution: SKILL.md Phase 1 now requires `Read` of `input-resolution.md` before any git or file discovery.
- Remove cross-skill category detection from input resolution (it is the reviewing skill's responsibility), dropping the dependency on `test-categories.md`.

### Changed
- Replace markdown-link syntax with plain relative paths in SKILL.md and reference files so progressive disclosure is not blocked by path interpolation.

## [2.3.1] - 2026-03-27

### Fixed
- Team review base-branch detection no longer hardcodes `main`/`master`; it asks the user, correctly handling stacked branches.

## [2.3.0] - 2026-03-27

### Changed
- Team review supports multiple files: accepts file paths, commits, branches, PRs, and directories, resolving to a file list. A variable reviewer pool (3-5) with balanced round-robin assignment reviews each file 3× while no reviewer sees all files; per-file consensus plus a cross-file consistency section.
- Progressive disclosure: SKILL.md refactored from a 403-line monolith to a ~200-line orchestrator with 6 reference files.
- Debate protocol gains cross-file reference rules (8-10).

## [2.2.1] - 2026-03-26

### Fixed
- Team review spawn prompt: clarify phase transitions so reviewers stop resending previous-phase responses (one `SendMessage` per phase, then go idle).

## [2.2.0] - 2026-03-26

### Added
- `phpunit-unit-test-team-reviewing` skill: consensus review using Claude Code Agent Teams — three independent reviewers analyze a file, run a one-round debate, and submit final stances; the lead merges by 2-of-3 / 3-of-3 majority with dissent annotations and a contested section. Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.
- `debate-protocol.md`: seven rules governing evidence-based inter-reviewer debate.

## [2.1.2] - 2026-02-26

### Fixed
- Align delegation-skip logic across all sources: pure delegation methods are now documented as skip-worthy in the decision tree (`test-requirement-rules.md`), the generation quick check, and `UNIT-001.md`, matching the category-b-service template.

## [2.1.1] - 2026-02-26

### Changed
- PHPUnit invocations use `result-only` output first (orchestrator fix loop and generation skill), re-running with default output only on failure. Reduces token usage on passing runs.

## [2.1.0] - 2026-02-26

### Added
- Coverage exclusion offer (Phase 2): when a source file is SKIPPED for having no testable logic, offer to add it to `phpunit.xml.dist` `<exclude>`.
- `skip_type` field distinguishing `coverage_excluded` from `no_logic`.
- Multi-file batch exclusion: collect all trivial files into one prompt.
- SKIPPED-with-exclusion report template.

### Changed
- Orchestrator Phase 1 decision table branches on `skip_type`; file-write restrictions allow user-confirmed `phpunit.xml.dist` `<exclude>` edits (Phase 2 only).

## [2.0.3] - 2026-02-26

### Removed
- `resolve_legacy` MCP tool and its infrastructure (`resolve.sh`, `LEGACY_TO_ID`/`RULE_LEGACY` arrays).
- Legacy E/W/I identifiers: `legacy` frontmatter from all 46 rule files, legacy columns from `list_rules`, and the Legacy line from `get_rules`, plus references in skills, templates, and docs.

## [2.0.2] - 2026-02-25

### Added
- Filter mode for `get_rules`: accepts `group`, `test_type`, `test_category`, `scope`, `enforce` as an alternative to ID lookup.
- Shared `_filter_rules()` helper reused by `list_rules` and `get_rules`.

## [2.0.1] - 2026-02-25

### Fixed
- Phase execution enforcement: the "Report after" directive applies to communication only — workflow phases still execute.
- NEEDS_ATTENTION now routes through the fix loop before escalating to the user.
- Mark `phpunit-unit-test-generation` `user-invocable: false`.

## [2.0.0] - 2026-02-25

### Added
- `test-rules` MCP server serving rule content via `list_rules`, `get_rules`, and `resolve_legacy`, replacing static reference-file loading.
- `rules/` directory (rules by group, auto-discovered), `shared/mcpserver_core.sh` (stdio JSON-RPC library), and `.mcp.json`.

### Changed
- Breaking — reviewing skill rewritten from a static 14-phase reference-file workflow to an MCP-driven rule-group workflow (convention → design → unit → isolation → provider), loading only rules for the detected category.
- Breaking — the three original agents replaced by two thin fork targets, `test-generator` (acceptEdits) and `test-reviewer` (read-only); skills fork via `context: fork`.
- Breaking — the fix loop moves from the `phpunit-unit-test-reviewer-fixer` agent into the orchestrator skill (inline, max 4 iterations with oscillation detection).
- Orchestrator uses the `Skill` tool for generation/review and `Edit` + MCP tools for fix-loop validation.

### Removed
- `agents/phpunit-unit-test-generator.md`, `agents/phpunit-unit-test-reviewer-fixer.md`, and `agents/phpunit-unit-test-reviewer.md` (replaced or absorbed).
- 7 reviewing reference files now served by the MCP server, plus `feature-flags.md` (moved into `rules/unit/UNIT-007.md`).

## [1.2.8] - 2026-02-24

### Added
- `W016` — single-use test property: inline the construction at the usage site.
- `W017` — `Test` prefix on a non-test helper class: use `Stub*`, `Fake*`, or a role-based name.
- `W018` — description-only data provider parameter: use `$_dataName`.

### Fixed
- Skip test generation for source files excluded from coverage by `phpunit.xml.dist` (`<directory suffix>` and `<file>` rules).
- `E018`: decoration-pattern example uses `expectExceptionObject()` instead of bare `expectException()`.
- `phpunit-conventions.md` Pattern 3 uses `$_dataName` instead of a `$description` parameter.

## [1.2.7] - 2026-02-23

### Fixed
- `E008`: state both directions explicitly — flag `static::expectException*()`, do not flag `$this->expectException*()`; narrow the Quick Reference pattern to `$this->assert*()`.

## [1.2.6] - 2026-02-21

### Added
- `W015` — data provider uses `return []` instead of `yield`/`iterable`.

### Changed
- `E019`: replace `expects($this->any())` with `expects($this->atLeastOnce())` (`any()` permits 0 invocations); flag `->with(static::callback(...))` chains lacking `->expects()`.
- `E008`: `expectException*()` setup must use `$this->`, not `static::`.
- `W007`: require verb-first provider names.

## [1.2.5] - 2026-02-20

### Fixed
- `W012`: exclude `createMock()` when `->with(static::callback(...))` argument verification is present (callbacks justify the mock).
- `E019`: branch the fix on `->with(static::callback(...))` presence — replace `expects($this->once())` with `expects($this->any())` rather than removing `expects()` (which discards argument assertions).
- `E009`: prohibit deleting the sole coverage of a code path or collapsing a data-provider test into a parameterless one.

### Added
- `W014` (`#[Package(...)]` attribute on a test class) and `I009` (duplicated inline arrange code, ≥ 5 identical construction lines).

## [1.2.4] - 2026-02-19

### Fixed
- Corrected invocation matcher methods (`once()`, `never()`, `exactly()`) to use `$this->` instead of `static::` in all code examples and skill instructions — ECS enforces this distinction (invocation matchers are instance methods, not static assertion helpers)
- Clarified E008 scope: `static::` applies to assertion methods (`assert*`, `expect*`) only; invocation matchers inside `->expects()` require `$this->`

## [1.2.3] - 2026-02-19

### Added
- `E018` (weak exception assertion — `expectException()` without a message/code/object for parameterized exceptions), `E019` (call-count over-coupling), `W012` (`createMock()` where `createStub()` suffices), `W013` (opaque hex-UUID test identifiers).

### Changed
- Category B template defaults to `createStub()`; Category E leads with `expectExceptionObject()` and uses `\Throwable` for full object matching.
- `essential-rules.md`, `common-patterns.md`, and `mocking-strategy.md` gain stub-vs-mock guidance; reviewing overview updated to 19 error codes / 13 warnings; `E005` expanded to flag call-count verification on non-side-effect methods.

## [1.2.2] - 2025-12-19

### Changed
- Final status reports as COMPLIANT / NON-COMPLIANT instead of PASS / ISSUES_FOUND; E-codes are mandatory failures, W-codes optional.

### Fixed
- The fixer attempts all E-codes (not just tool-validation errors), no longer prompts on NON-COMPLIANT, and re-invokes when fixes failed on dependencies and iterations remain.

## [1.2.1] - 2025-12-18

### Changed
- Updated MCP tool references from `php-tooling` plugin to `dev-tooling` plugin
- Documentation now references `dev-tooling` as the required dependency

## [1.2.0] - 2025-12-18

### Changed
- Breaking — split the reviewer into `phpunit-unit-test-reviewer` (read-only) and `phpunit-unit-test-reviewer-fixer` (edit-capable, internal fix loop up to 4 iterations with oscillation detection); extends the output contract with `iterations_used`, `fixes_applied`, `oscillation_detected`.

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
