# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.2.1] - 2026-08-21

### Added
- **`model: sonnet` on the `code-researcher` agent.** The agent carried no `model` field, so it inherited the main conversation's model — running an Opus- or Fable-class model to do what is structurally a dispatch: invoke `researching-code`, let ChunkHound do the retrieval and synthesis, return the result. Every other agent in this marketplace pins its model explicitly (`dev-tooling-runner` haiku, the three `test-writing` agents sonnet); this one was the outlier.
- **`name: code-researcher`** in the agent frontmatter. The field is documented as required and every sibling agent sets it; only the filename was carrying the identity here.

### Changed
- **Step 3 primitive catalog inverted — a ChunkHound primitive opens every code search; `ugrep` only closes one.** Since 3.0.0 the catalog listed `ugrep` as a first-line primitive for known identifiers, known literals, and call-site enumeration, and `search` regex ahead of `search` semantic. Practice in the Shopware codebase showed the cost during refactorings: a word-based search reports occurrences of a string but not indirect callers, dynamic dispatch, container wiring, or string-keyed references, so an impact map opened with `ugrep` under-reports its own surface while looking complete. The catalog now routes concept, behavior, and relationship lookups to `search` semantic (the default whenever the exact token is not already known), retrieval of a string whose exact form is already known to `search` regex, and cross-file flow to `code_research`. `ugrep` is reachable only as an exhaustive-enumeration sweep after a ChunkHound query has located the surface. `Read` on a known file path is unchanged — that is not a search. Two rules make the ordering explicit: *Prefer semantic over regex* and *`ugrep` is a complement, never an opener*.
- **Deep workflow closes refactoring POIs with a `ugrep` sweep.** Its Focus step previously offered "`search` or native text search" as interchangeable per-POI primitives. It now takes `search` for symbol-level POIs and, where the deliverable is an exhaustive list, confirms the ChunkHound findings against a native sweep rather than substituting one for them.
- **Pre-flight is now reached by every plan that searches code.** The skip condition previously exempted any "purely native" plan (`Read`, `ugrep`, `bfs`); with `ugrep` no longer a legitimate opener, the exemption is now keyed on whether the plan consults the index at all rather than on which tool it uses. A known-path `Read` and a path-pattern `bfs` still skip the gate, since neither touches ChunkHound; anything that searches code reaches it. Restated in the three places that carry the condition — Step 2 of `SKILL.md`, the opening directive and hard-gate note of `references/pre-flight.md`, and the workflow digraph's bypass edge. An unavailable index therefore hard-stops research that would previously have degraded to `ugrep` and returned shallow findings under the appearance of a completed search. Users with a broken or unindexed project see structured failures where they previously saw grep-quality results — the failure shape already carries the remediation steps.
- **A known symbol name no longer routes a question to regex.** Relationship and impact questions ("what calls X", "what breaks if X changes") take `search` semantic even when X is named exactly; regex is reserved for retrieving occurrences of a string whose exact form is already known. Without this split, "find all callers of `FooService`" reads as a lexical lookup and misses aliases, dynamic dispatch, and container wiring — the failure the whole change exists to prevent.
- **The closing `ugrep` sweep is mandatory at every depth** when the deliverable is an exhaustive list, including surface. No workflow named such a sweep before, so a "quick check, find all callers" request could return an unconfirmed enumeration and stop there. The Surface and Broad procedures carry the sweep as an explicit step rather than inheriting it from the rule above them, since both previously authorized termination the moment a result looked sufficient, which is exactly the moment an enumeration question is not yet answered. `Primitive override` states that a forced `code_research` plan still owes the sweep — the override picks which primitive answers a question and the sweep verifies an answer, so the two do not compete.
- **`bfs` is exempt from the complement rule; `ugrep` is not.** Matching file paths is not searching code, and no ChunkHound primitive searches paths — so a path glob has nothing that could precede it. The catalog keeps a **Known file pattern** → `bfs` row (and the README its matching row) as a legitimate opener. Without the carve-out, "find all `*.test.ts`" had no lawful route at all, and an agent's cheapest option would have been to decide the rule was soft. The `Language scope` filename scan relies on the same exemption.
- **The `Language scope` prohibition no longer collides with a known-path `Read`.** It forbade reading unsupported-language files outright, which an explicit request for a named `.twig` or `.erb` file would trip. It now forbids only backfilling a coverage gap with their contents.
- Step 2's no-downgrade directive and the Surface workflow's retry line name the concrete primitives (`regex → semantic`, `search → code_research`) instead of the removed "native ↔ ChunkHound" axis.
- Documentation re-synced with the new routing: the README `🧭 What the skill uses internally` table and its usage sentence, AGENTS.md's MCP tool reference, its `Change skill tool surface` / `Change ... routing` navigation rows, and its pre-flight maintenance guidance.
- The workflow digraph's pre-flight bypass edge is labelled `no — searches no code`, so the diagram states the same condition the prose does rather than a bare `no`.
- AGENTS.md's `Modify subagent invocation trigger` navigation row is retitled `...or model` and carries the reason the agent's model is pinned.
- **The `researching-code` description is trigger-only again.** It closed on a summary of the workflow ("Picks a research depth …, executes the corresponding chunkhound query sequence, and returns synthesized findings"), which is the Description Trap: a summary in the highest-attention position competes with the digraph and the Step 3 routing rules it purports to describe. The trigger phrasings above it are unchanged.
- **`code-researcher` is dispatched proactively and leads with the task domain.** The description previously opened with the invocation condition and closed on a sentence describing its own isolation mechanism. It now states what the agent researches and what it returns, then carries `Use proactively` with the concrete triggers — matching the documented pattern (task domain, then when to delegate) and dropping the self-referential clause. Proactive dispatch fits the delegation criteria for current models, which reserve subagents for large independent work such as a wide multi-file investigation and warn only against delegating handful-of-tool-calls tasks or verification passes. The description also carries the one-at-a-time constraint, so the rule travels with the agent rather than living only in the SessionStart directive; that constraint is about concurrency and does not compete with proactive invocation.

`allowed-tools` is unchanged — `Bash(ugrep:*)` remains granted for the closing sweep and `Bash(bfs:*)` for path enumeration. The constraint on `ugrep` is a rule rather than a withdrawn permission, matching how the existing `Language scope` rule already governs native tools.

## [3.2.0] - 2026-07-12

### Added
- **`CHUNKHOUND_DB_EXECUTE_TIMEOUT=120` in the MCP server registration** (`.mcp.json` `env` block). The wrapper script `exec`s `chunkhound mcp`, so the variable reaches ChunkHound itself and raises its database operation timeout to 120 seconds. ChunkHound 5.2 introduced DuckDB auto-compaction to prevent the database file from growing beyond reasonable size, and compaction can push individual database operations past the default timeout. The variable was recognized before 5.2 as well, so it does no harm when an older ChunkHound version is installed.
- **README "Database operation timeout" subsection** in `🎛️ Configuration Reference` documenting the variable and the manual-indexing prefix.

### Changed
- **Manual indexing instructions carry the timeout variable.** Every documented `chunkhound index` invocation now reads `CHUNKHOUND_DB_EXECUTE_TIMEOUT=120 chunkhound index`: README setup and troubleshooting sections, `SETUP.md` validation and post-setup steps, AGENTS.md external dependencies, and the remediation lines in `skills/researching-code/references/pre-flight.md`. The `SETUP.md` change is mirrored byte-identical to `plugins/plugin-setup/skills/chunkhound-integration-setting-up/references/plugin-setup.md`.
- **`supported-languages.md` synced with upstream ChunkHound 5.2.0** — adds PowerShell (`.ps1`, `.psm1`) and Metal (`.metal`, parsed with the C++ grammar) to the Programming languages table.

## [3.1.2] - 2026-06-11

### Removed
- **Role-persona sentence dropped from the `code-researcher` agent** ("You are a code researcher."). Research on persona prompting shows role assignments do not improve the factual correctness of LLM output — at best they steer writing style. In this agent the role sentence steered nothing: the output shape is fully defined by the `researching-code` skill's synthesis format, and the agent body's task instruction ("Invoke the `researching-code` skill … return the synthesized findings") carries all the behavior. The sentence was inert ballast and is gone. No behavior change.

## [3.1.1] - 2026-05-18

### Fixed
- **LanceDB recommendations removed.** ChunkHound upstream now marks LanceDB as **experimental** and explicitly recommends DuckDB for all use cases (see [chunkhound.ai/docs/configuration/](https://chunkhound.ai/docs/configuration/#database-backends)). Prior versions defaulted setup to `lancedb` and steered users away from DuckDB based on outdated `vss`-extension caveats that the upstream docs no longer assert. Removed: LanceDB setup question, LanceDB minimal/full config snippets in `SETUP.md`, README "Database provider" section, and the `database: lancedb` template in `references/pre-flight.md`. Affected files: `SETUP.md`, `README.md`, `skills/researching-code/references/pre-flight.md`, and the byte-identical mirror in `plugins/plugin-setup/skills/chunkhound-integration-setting-up/references/plugin-setup.md`.
- **Ollama removed as an embedding-provider option.** Current ChunkHound docs no longer list `ollama` among the embedding providers — Ollama is reached via `provider: "openai"` with `base_url: http://localhost:11434/v1`. Removed Ollama from `SETUP.md`'s setup questions, README's embedding-provider list and troubleshooting bullet, `references/pre-flight.md`'s remediation guidance, and AGENTS.md's embedding-provider list. Marketplace `README.md` updated to drop the Ollama reference in the Third-Party Integrations notice.
- **Documentation URLs migrated to `chunkhound.ai`.** Upstream's canonical docs site is now `chunkhound.ai`; the `chunkhound.github.io/code-research/` and `chunkhound.github.io/under-the-hood/` subpaths have no equivalent on the new site. Updated `plugin.json` homepage field, README intro/links/configuration references, and AGENTS.md "Related Documentation" entries. Dropped the two 404-equivalent links from README "Links" and AGENTS.md.
- **README complete-config example model bumped** from `voyage-3.5` to `voyage-4-lite`.

### Added
- **SessionStart hook — sequential ChunkHound-dispatch directive.** Introduces `hooks/hooks.json`, `hooks/prompts/sequential-chunkhound-directives.md`, and `hooks/scripts/session-start.sh`. The hook injects a directive instructing the model to dispatch any subagent performing ChunkHound operations sequentially. The directive covers the bundled `code-researcher` agent and any other subagent (general-purpose or custom) whose task involves `mcp__plugin_chunkhound-integration_ChunkHound__search` or `mcp__plugin_chunkhound-integration_ChunkHound__code_research`. ChunkHound's background daemon serializes parallel MCP clients onto a single DuckDB writer connection, so parallel subagent dispatch produces no wall-clock speedup while burning extra agent-spawn overhead and tokens. The skill itself stays unopinionated about parallelism (it does not spawn subagents); the hook makes the plugin opinionated only at the layer that actually decides whether to fan out.
- **README "Parallel use" subsection** in `🎛️ Configuration Reference` explaining the daemon serialization behavior and pointing at the SessionStart enforcement.
- Marketplace `README.md` component-badge row for `chunkhound-integration` now lists `🪝 Hooks`.

## [3.1.0] - 2026-05-18

### Added
- **Unsupported-language awareness** — new Step 3 `Language scope` rule directs the skill to surface files in languages outside ChunkHound's parser set (e.g. `.twig` in Shopware, `.erb` in Rails, `.heex` in Phoenix LiveView) as a coverage gap rather than backfilling with `ugrep`/`Read` over their contents. Permits a single `bfs` filename scan to confirm presence; forbids content reads. A word-based search cannot replicate ChunkHound's cross-file synthesis, and silent compensation would mask the gap from the caller — especially harmful when the skill runs inside a subagent context where nested subagent invocation is forbidden.
- `skills/researching-code/references/supported-languages.md` — enumerates ChunkHound's parser language set across five tables (Programming languages, Build and infrastructure, Web and UI, Data and configuration, Fallback parsers). Loaded inline by the `Language scope` rule. Mirrors the upstream `Language` enum (`chunkhound/core/types/common.py`) and `EXTENSION_TO_LANGUAGE` map (`chunkhound/parsers/parser_factory.py`) from `chunkhound/chunkhound`.
- README `🗂️ Supported Languages` section explaining the coverage-gap behavior and linking the upstream source files.
- AGENTS.md `Syncing the supported-languages list with upstream ChunkHound` maintenance directive — concrete steps to check the upstream `Language` enum and `EXTENSION_TO_LANGUAGE` map on every ChunkHound version bump and update the reference file accordingly. Plus directory tree, Key Navigation row, and corrected Step 4 reference.

### Changed
- Synthesis output: Step 4 `Index health notes` section renamed to `Coverage caveats` with two sub-bullets — *Unsupported-language gaps* (new, surfaced as a missing slice rather than a softening of the supported-slice findings) and *Index health notes* (pre-flight warnings, verbatim). Step 2's cross-reference updated to match.

## [3.0.0] - 2026-05-17

### Breaking Changes
- `code-research-routing` skill renamed to `researching-code` and rewritten as a workflow executor (depth detection → conditional pre-flight → execute → synthesize) rather than a routing decision table. Callers referencing the old skill name must update.
- `/research` and `/chunkhound-status` slash commands removed. The force-`code_research` role of `/research` is preserved as a Step 1 primitive directive in the skill (phrases like "use code_research", "research this with synthesis", "force code_research"). The diagnostic content of `/chunkhound-status` moved into `skills/researching-code/references/pre-flight.md` under "Setup diagnostic".
- `code-researcher` agent body simplified — environment-aware language removed; description advertises isolation, body is task-only.
- Skill `allowed-tools` introduced with scoped permissions: `Read`, `Bash(bfs:*)`, `Bash(ugrep:*)`, and the three ChunkHound MCP tools. Other tools (Grep, Glob, arbitrary Bash) are structurally unavailable inside the skill — enforces "no silent downgrade to native tools" at the harness level.

### Added
- Depth detection (surface / broad / deep) driven by explicit directive, question shape, or default.
- Primitive directive — caller can force `code_research`-only mode regardless of question shape; preserves the role of the removed `/research` command.
- Conditional pre-flight — `daemon_status` runs only when the plan uses ChunkHound primitives. Plans that use only `Read`, `ugrep`, or `bfs` skip pre-flight entirely.
- Embeddings gate — conditional probe (`search` semantic with a high-recall noise word) for stale-index detection where chunks exist but embeddings are missing. Covers both "missing embeddings" (re-index required) and "no embedding provider" (schema rejection of `type: semantic`) cases.
- `references/pre-flight.md` — progressive-disclosure reference containing hard gates, warnings, failure return shape, embeddings gate, and the setup diagnostic procedure.
- "Index health notes" section in synthesis output — surfaces pre-flight warnings inline with findings so coverage caveats are not buried.
- Native research primitives in the Step 3 catalog — `Read`, `ugrep`, and `bfs` are first-class options alongside `search` and `code_research`, picked deliberately per question shape rather than treated as fallbacks.

### Changed
- Pre-flight failure semantics: hard gates stop the skill loudly. ChunkHound-dependent plans must not silently downgrade to native-only — a native-only plan from the start is fine and never reaches pre-flight.
- README usage section reframed around natural-language invocation; new "Force ChunkHound synthesis" section explains primitive directives.
- AGENTS.md navigation overhauled to reflect the new workflow structure and removed surface area.

### Removed
- `commands/research.md` and `commands/chunkhound-status.md`. Force-`code_research` covered by Step 1 primitive directive; diagnostic covered by `references/pre-flight.md` "Setup diagnostic" section.
- Old `code-research-routing` skill (replaced by `researching-code`).

## [2.0.0] - 2026-05-17

### Breaking Changes
- MCP tool surface consolidated. `search_semantic` and `search_regex` → `search` (with `type: "semantic" | "regex"`). `health_check` and `get_stats` → `daemon_status`. Update agent frontmatter and skill references.
- `code-researcher` subagent rewritten as a thin wrapper over `code-research-routing`. Frontmatter `tools:` replaced with `skills:`; output format moved into the skill.
- PreToolUse `Grep` hook removed (Grep is no longer a Claude Code tool).

### Added
- Setup asks `lancedb` vs `duckdb` and recommends `lancedb` (cheaper incremental backups; DuckDB's `vss` extension is experimental).
- Warning against `indexing.realtime_backend: watchman` on macOS — kills daemon startup, no fallback to system watchman.
- "Synthesis Output Format" section in `code-research-routing` (Overview / Key Components / Architecture Insights / Recommendations).

### Changed
- README Configuration Reference links upstream docs instead of duplicating drifting tables; plugin-specific guidance kept inline.
- `Glob`/`Grep` references replaced with `bfs`/`ugrep` via Bash. Subagent Bash permission scoped to `Bash(bfs:*)`.
- `database.provider: lancedb` added to recommended configs across SETUP.md, README, and `chunkhound-status`.

### Removed
- `hooks/hooks.json` (only entry was the defunct Grep hook).

### Fixed
- README: removed false claim "currently only `duckdb` supported" from Database Options.

## [1.2.2] - 2026-05-13

### Changed
- `code-research-routing` description rewritten to follow https://agentskills.io/skill-creation/optimizing-descriptions. Leads with imperative "Use this skill when..." and adds an explicit "activate even when the user does not mention 'semantic search' or 'ChunkHound'" clause to broaden triggering on architectural questions phrased without naming the underlying tool. No behavior change.

## [1.2.1] - 2026-04-18

### Changed
- `setting-up` skill aligned with the shared template by adding an optional Phase 4 (Plugin Scope Setup) and renumbering the remaining phases. The phase is a no-op for chunkhound-integration since its `SETUP.md` has no `## Plugin Scope Setup` section.

## [1.2.0] - 2026-04-13

### Added
- **Permission configuration in `setting-up` skill** — new Phase 4 pre-approves ChunkHound MCP tools in `.claude/settings.local.json` as a single wildcard allow group. Merges non-destructively into any existing settings.

## [1.1.1] - 2026-04-13

### Fixed
- `setting-up` SKILL.md: bare-path reference to `references/plugin-setup.md` so progressive disclosure loads it correctly.

## [1.1.0] - 2026-04-10

### Added
- **Interactive setup skill** — `setting-up` skill walks users through plugin configuration: checks chunkhound CLI installation, verifies embedding provider API key (VoyageAI, OpenAI, or Ollama), creates `.chunkhound.json` with provider settings, runs the initial codebase index, validates the MCP server connection, and reports post-setup steps. Activates when users ask about setup or when ChunkHound MCP tools fail due to missing config.

## [1.0.3] - 2026-01-09

### Changed
- Improved skill description to follow Anthropic's best practices (third-person voice, quoted trigger phrases)

## [1.0.2] - 2026-01-09

### Fixed
- Corrected MCP tool identifiers from `mcp__ChunkHound__*` to `mcp__plugin_chunkhound-integration_ChunkHound__*` format

## [1.0.1] - 2026-01-09

### Fixed
- `/chunkhound-status` now correctly detects database at configured `database.path` instead of only checking hardcoded `.chunkhound/` directory
- Status command now checks all 8 config file locations (project root through `.claude/`) instead of only project root

## [1.0.0] - 2026-01-08

### Added
- Initial release
- MCP server integration for ChunkHound semantic code research
- `/research <query>` command for explicit ChunkHound invocation
- `/chunkhound-status` command for diagnostics
- `code-research-routing` skill for automatic tool selection
- `code-researcher` agent for complex investigations
- PreToolUse hook suggesting ChunkHound for architectural Grep queries
- Multi-location config discovery (8 locations, `.claude/` highest priority)
