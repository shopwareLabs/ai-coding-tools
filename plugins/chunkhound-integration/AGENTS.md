@README.md

## Directory Structure

```
plugins/chunkhound-integration/
├── README.md                     # User documentation (setup, usage, troubleshooting)
├── SETUP.md                      # Interactive setup spec (consumed by plugin-setup mirror)
├── AGENTS.md                     # LLM navigation guide (this file)
├── CLAUDE.md                     # Points to AGENTS.md
├── CHANGELOG.md                  # Version history
├── .mcp.json                     # MCP server registration (ChunkHound)
├── .claude-plugin/
│   └── plugin.json               # Plugin manifest (name, version, metadata)
├── agents/
│   └── code-researcher.md        # Context-isolated investigation agent
├── hooks/
│   ├── hooks.json                # SessionStart hook configuration
│   ├── prompts/
│   │   └── sequential-chunkhound-directives.md   # Sequential-dispatch directive (code-researcher + any subagent invoking ChunkHound MCP tools)
│   └── scripts/
│       └── session-start.sh      # Emits the directive as additionalContext
├── scripts/
│   └── run-chunkhound.sh         # Multi-location config discovery wrapper
└── skills/
    └── researching-code/
        ├── SKILL.md              # Research execution: depth → pre-flight → execute → synthesize
        └── references/
            ├── pre-flight.md             # daemon_status gates, warnings, failure return shape
            └── supported-languages.md    # Mirror of ChunkHound's parser language set
```

## Component Overview

This plugin provides:
- **MCP Server** via `.mcp.json`: ChunkHound semantic code research tools
- **Skill** via `skills/researching-code/SKILL.md`: Executes code research; picks depth, sequences `code_research`/`search` calls, returns synthesized findings
- **Agent** via `agents/code-researcher.md`: Context-isolated investigations (auto-activates the skill in a clean conversation window)
- **SessionStart Hook** via `hooks/hooks.json`: Injects an opinionated directive instructing the model to invoke the `code-researcher` agent sequentially. ChunkHound's background daemon serializes parallel MCP clients onto a single DuckDB writer connection, so parallel subagent dispatch yields no wall-clock benefit and burns extra spawn overhead

## MCP Tools Reference

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `mcp__plugin_chunkhound-integration_ChunkHound__code_research` | Deep architectural analysis with LLM synthesis | "How does X work?", multi-file relationships |
| `mcp__plugin_chunkhound-integration_ChunkHound__search` | Pinpoint exact locations via regex or semantic search (`type` parameter) | Opens most searches — semantic for concepts, behavior, and relationships; regex for a string already known exactly |
| `mcp__plugin_chunkhound-integration_ChunkHound__daemon_status` | Daemon health, scan progress, realtime readiness | Verify MCP connection, check scan completion |

## Key Navigation Points

| Task | Primary File | Key Concepts |
|------|--------------|--------------|
| Change skill auto-activation triggers | `skills/researching-code/SKILL.md` | Frontmatter `description` |
| Change skill tool surface | `skills/researching-code/SKILL.md` | Frontmatter `allowed-tools` — `Read`, scoped `Bash(ugrep:*)` for the closing sweep, `Bash(bfs:*)` for path enumeration, and the three ChunkHound MCP tools |
| Change depth-detection or primitive-directive rules | `skills/researching-code/SKILL.md` | Step 1 — explicit directives (depth and primitive), question shape, default; forced `code_research` mode |
| Change per-depth research procedure | `skills/researching-code/SKILL.md` | Step 3 — Surface / Broad / Deep workflows |
| Change `code_research` vs `search` routing | `skills/researching-code/SKILL.md` | Step 3 primitive catalog — ChunkHound opens every code search (semantic preferred over regex); `ugrep` is a complement that only closes one; `Read` and `bfs` stand outside the rule because paths are not code |
| Change pre-flight gates, warnings, failure shape, or setup diagnostic | `skills/researching-code/references/pre-flight.md` | Hard gates list, embeddings gate (conditional on plan using semantic / `code_research`), warnings list, failure return shape, setup diagnostic (installation/config/database checks + remediation) |
| Modify synthesis output format | `skills/researching-code/SKILL.md` | Step 4 — Overview / Key Components / Architecture Insights / Recommendations / Coverage caveats (unsupported-language gaps + index health notes) |
| Modify subagent invocation trigger or model | `agents/code-researcher.md` | Frontmatter `description` routes invocation; `model: sonnet` is pinned because the agent dispatches to the skill rather than reasoning itself (the agent body is a thin wrapper around the skill) |
| Modify sequential-dispatch directive | `hooks/prompts/sequential-chunkhound-directives.md` | Static prompt emitted by SessionStart as `additionalContext`; covers the `code-researcher` agent and any other subagent that calls `mcp__plugin_chunkhound-integration_ChunkHound__search` or `mcp__plugin_chunkhound-integration_ChunkHound__code_research`. Tone matches the other plugins' MCP-tool directives |
| Sync supported-languages list with upstream ChunkHound | `skills/researching-code/references/supported-languages.md` | Mirror the `Language` enum (`chunkhound/core/types/common.py`) and `EXTENSION_TO_LANGUAGE` (`chunkhound/parsers/parser_factory.py`) from `chunkhound/chunkhound` on GitHub |
| Add config discovery location | `scripts/run-chunkhound.sh` | `CONFIG_LOCATIONS` array |
| Modify MCP server invocation | `.mcp.json` | Wrapper script path |

## When to Modify What

**Changing how the skill auto-activates**:
1. Edit the frontmatter `description` in `skills/researching-code/SKILL.md`.
2. Keep the description trigger-only ("Use this skill when…") — do not describe the workflow there.

**Changing the research workflow** (depth detection, per-depth procedure, primitive routing):
1. Edit the relevant Step in `skills/researching-code/SKILL.md`.
2. Update the digraph at the top of the workflow section to match — every prose step must be a node.

**Changing pre-flight behavior** (gates, warnings, failure return shape):
1. Edit `skills/researching-code/references/pre-flight.md`. The main SKILL.md keeps only the gate-and-stop directive in Step 2 and references the file.
2. Pre-flight is *conditional* — it runs only when the plan uses any ChunkHound primitive. Since a ChunkHound primitive opens every code search, only a plan that searches no code skips it (known-path `Read`, path-pattern `bfs`). Do not change that to always-run, and do not narrow it back to `Read` alone — that would gate path globs behind an index they never consult.
3. Do not introduce downgrade paths from ChunkHound-dependent plans to `ugrep`/`bfs` when pre-flight fails — pre-flight failures must return the structured failure shape so callers know research did not happen.
4. Pre-flight runs *after* depth detection. Daemon state must not influence the research plan — keep the depth decision (Step 1) independent of `daemon_status`.

**Adding config discovery location** (e.g., `.github/`):
1. Add to `CONFIG_LOCATIONS` array in `scripts/run-chunkhound.sh`.
2. Update README.md config locations table.

**Changing subagent activation**:
1. Edit `agents/code-researcher.md` frontmatter `description` — this is what auto-routes the subagent. The body is a thin wrapper that invokes `researching-code`; do not duplicate skill logic here.

**Changing the sequential-dispatch directive**:
1. Edit `hooks/prompts/sequential-chunkhound-directives.md`. The SessionStart script reads this file verbatim and injects it as `additionalContext`. Keep it short and imperative — it lands inside every session as ambient guidance.
2. The directive covers two paths: the bundled `code-researcher` agent, and any other subagent (general-purpose or custom) whose task involves ChunkHound MCP tools. When extending, name both paths explicitly; a single-path directive lets the model rationalize that the rule does not apply to ad-hoc subagents.
3. Do not document the *reason* (DuckDB serialization, daemon behavior) in the directive itself — the README's `Parallel use` subsection carries that explanation. The directive is a rule, not a justification.

**Syncing the supported-languages list with upstream ChunkHound** (run on every ChunkHound version bump and whenever a chunkhound-integration plugin release is prepared):
1. Open `https://github.com/chunkhound/chunkhound/blob/main/chunkhound/core/types/common.py` and inspect the `Language` enum for added, removed, or renamed entries since the last sync.
2. Open `https://github.com/chunkhound/chunkhound/blob/main/chunkhound/parsers/parser_factory.py` and inspect the `EXTENSION_TO_LANGUAGE` map for added or changed file extensions.
3. If either source changed, update `skills/researching-code/references/supported-languages.md` so its tables (Programming languages, Build and infrastructure, Web and UI, Data and configuration, Fallback parsers) match the upstream set. The reference file holds the language tables only — its consumption is wired by the `Language scope` rule in `skills/researching-code/SKILL.md`, so no further edits are needed there.
4. Update the README's `🗂️ Supported Languages` section only if its narrative content (examples, link targets) becomes inaccurate. The README does not enumerate languages.

## Architecture

### Config Discovery Flow

```
.mcp.json → run-chunkhound.sh → chunkhound mcp [--config path]
                    ↓
         Check CONFIG_LOCATIONS array:
         1. .chunkhound.json (project root)
         2. .ai/.chunkhound.json
         3. .aider/.chunkhound.json
         4. .cursor/.chunkhound.json
         5. .kite/.chunkhound.json
         6. .llm/.chunkhound.json
         7. .tabnine/.chunkhound.json
         8. .claude/.chunkhound.json (highest priority)
```

### Invocation Pathways

| Pathway | Trigger | Component |
|---------|---------|-----------|
| Auto-activation | Architectural questions matching the skill description | `skills/researching-code/SKILL.md` |
| Subagent (clean context) | Investigations that would flood the main thread; caller wants isolation | `agents/code-researcher.md` |

## Integration with Other Plugins

Other plugins can reference ChunkHound tools:

```yaml
---
tools:
  - mcp__plugin_chunkhound-integration_ChunkHound__code_research
  - mcp__plugin_chunkhound-integration_ChunkHound__search
---

Use code_research to understand the authentication architecture before implementing changes.
```

## External Dependencies

**ChunkHound** (required):
- Install: `uv tool install chunkhound`
- Index: `CHUNKHOUND_DB_EXECUTE_TIMEOUT=120 chunkhound index` in project root
- Config: `.chunkhound.json` with embedding provider

**Embedding Provider** (required for semantic search):
- VoyageAI (`VOYAGEAI_API_KEY`)
- OpenAI (`OPENAI_API_KEY`)

## Related Documentation

- **User guide**: [README.md](./README.md)
- **ChunkHound docs**: https://chunkhound.ai/
- **ChunkHound configuration**: https://chunkhound.ai/docs/configuration/
