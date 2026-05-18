# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
