@README.md

## Directory Structure

```
plugins/chunkhound-integration/
├── README.md                     # User documentation (setup, usage, troubleshooting)
├── AGENTS.md                     # LLM navigation guide (this file)
├── CLAUDE.md                     # Points to AGENTS.md
├── .mcp.json                     # MCP server registration (ChunkHound)
├── .claude-plugin/
│   └── plugin.json               # Plugin manifest (name, version, metadata)
├── agents/
│   └── code-researcher.md        # Context-isolated investigation agent
├── scripts/
│   └── run-chunkhound.sh         # Multi-location config discovery wrapper
└── skills/
    └── researching-code/
        ├── SKILL.md              # Research execution: depth → pre-flight → execute → synthesize
        └── references/
            └── pre-flight.md     # daemon_status gates, warnings, failure return shape
```

## Component Overview

This plugin provides:
- **MCP Server** via `.mcp.json`: ChunkHound semantic code research tools
- **Skill** via `skills/researching-code/SKILL.md`: Executes code research; picks depth, sequences `code_research`/`search` calls, returns synthesized findings
- **Agent** via `agents/code-researcher.md`: Context-isolated investigations (auto-activates the skill in a clean conversation window)

## MCP Tools Reference

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `mcp__plugin_chunkhound-integration_ChunkHound__code_research` | Deep architectural analysis with LLM synthesis | "How does X work?", multi-file relationships |
| `mcp__plugin_chunkhound-integration_ChunkHound__search` | Pinpoint exact locations via regex or semantic search (`type` parameter) | Known symbol or concept lookup after `code_research` |
| `mcp__plugin_chunkhound-integration_ChunkHound__daemon_status` | Daemon health, scan progress, realtime readiness | Verify MCP connection, check scan completion |

## Key Navigation Points

| Task | Primary File | Key Concepts |
|------|--------------|--------------|
| Change skill auto-activation triggers | `skills/researching-code/SKILL.md` | Frontmatter `description` |
| Change skill tool surface | `skills/researching-code/SKILL.md` | Frontmatter `allowed-tools` — `Read`, scoped `Bash(bfs:*)` and `Bash(ugrep:*)` for native text/file search, and the three ChunkHound MCP tools |
| Change depth-detection or primitive-directive rules | `skills/researching-code/SKILL.md` | Step 1 — explicit directives (depth and primitive), question shape, default; forced `code_research` mode |
| Change per-depth research procedure | `skills/researching-code/SKILL.md` | Step 3 — Surface / Broad / Deep workflows |
| Change `code_research` vs `search` routing | `skills/researching-code/SKILL.md` | Step 3 primitive matrix |
| Change pre-flight gates, warnings, failure shape, or setup diagnostic | `skills/researching-code/references/pre-flight.md` | Hard gates list, embeddings gate (conditional on plan using semantic / `code_research`), warnings list, failure return shape, setup diagnostic (installation/config/database checks + remediation) |
| Modify synthesis output format | `skills/researching-code/SKILL.md` | Step 4 — Overview / Key Components / Architecture Insights / Recommendations / Index health notes |
| Modify subagent invocation trigger | `agents/code-researcher.md` | Frontmatter `description` (the agent body is a thin wrapper around the skill) |
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
2. Pre-flight is *conditional* — it runs only when the plan uses any ChunkHound primitive. Native-only plans skip it entirely. Do not change that to always-run.
3. Do not introduce silent downgrade paths from ChunkHound-dependent plans to native-only when pre-flight fails — pre-flight failures must return the structured failure shape so callers know research did not happen.
4. Pre-flight runs *after* depth detection. Daemon state must not influence the research plan — keep the depth decision (Step 1) independent of `daemon_status`.

**Adding config discovery location** (e.g., `.github/`):
1. Add to `CONFIG_LOCATIONS` array in `scripts/run-chunkhound.sh`.
2. Update README.md config locations table.

**Changing subagent activation**:
1. Edit `agents/code-researcher.md` frontmatter `description` — this is what auto-routes the subagent. The body is a thin wrapper that invokes `researching-code`; do not duplicate skill logic here.

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
- Index: `chunkhound index` in project root
- Config: `.chunkhound.json` with embedding provider

**Embedding Provider** (required for semantic search):
- VoyageAI (`VOYAGEAI_API_KEY`)
- OpenAI (`OPENAI_API_KEY`)
- Ollama (local, no API key)

## Related Documentation

- **User guide**: [README.md](./README.md)
- **ChunkHound docs**: https://chunkhound.github.io/
- **Code Research tool**: https://chunkhound.github.io/code-research/
- **Under the Hood**: https://chunkhound.github.io/under-the-hood/
