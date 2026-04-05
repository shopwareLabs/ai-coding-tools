# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
