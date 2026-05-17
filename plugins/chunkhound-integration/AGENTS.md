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
│   └── code-researcher.md        # Deep investigation agent for complex queries
├── commands/
│   ├── research.md               # /research <query> - explicit ChunkHound invocation
│   └── chunkhound-status.md      # /chunkhound-status - diagnostics
├── scripts/
│   └── run-chunkhound.sh         # Multi-location config discovery wrapper
└── skills/
    └── code-research-routing/
        └── SKILL.md              # Auto-routing: ChunkHound vs native tools
```

## Component Overview

This plugin provides:
- **MCP Server** via `.mcp.json`: ChunkHound semantic code research tools
- **Skill** via `skills/code-research-routing/SKILL.md`: Auto-routing decisions
- **Agent** via `agents/code-researcher.md`: Context-isolated complex investigations
- **Commands** via `commands/`: `/research` and `/chunkhound-status`

## MCP Tools Reference

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `mcp__plugin_chunkhound-integration_ChunkHound__code_research` | Deep architectural analysis with LLM synthesis | "How does X work?", multi-file relationships |
| `mcp__plugin_chunkhound-integration_ChunkHound__search` | Pinpoint exact locations via regex or semantic search (`type` parameter) | Known symbol or concept lookup after `code_research` |
| `mcp__plugin_chunkhound-integration_ChunkHound__daemon_status` | Daemon health, scan progress, realtime readiness | Verify MCP connection, check scan completion |

## Key Navigation Points

| Task | Primary File | Key Concepts |
|------|--------------|--------------|
| Change when to use ChunkHound | `skills/.../SKILL.md` | Decision framework, query patterns |
| Modify research command output | `commands/research.md` | Output format structure |
| Modify status diagnostics | `commands/chunkhound-status.md` | Diagnostic steps, report format |
| Modify subagent invocation trigger | `agents/code-researcher.md` | Frontmatter `description` (the agent body is a thin wrapper around the skill) |
| Modify synthesis output format | `skills/code-research-routing/SKILL.md` | "Synthesis Output Format" section |
| Add config discovery location | `scripts/run-chunkhound.sh` | `CONFIG_LOCATIONS` array |
| Modify MCP server invocation | `.mcp.json` | Wrapper script path |

## When to Modify What

**Changing routing decisions** (ChunkHound vs native tools):
1. Edit `skills/code-research-routing/SKILL.md`
2. Modify the decision tables and framework

**Adding new ChunkHound use cases**:
1. Add query patterns to `skills/.../SKILL.md` tables — the skill is the single source of routing and output-format logic for both in-thread invocations and the wrapped `code-researcher` subagent.

**Adding config discovery location** (e.g., `.github/`):
1. Add to `CONFIG_LOCATIONS` array in `scripts/run-chunkhound.sh`
2. Update README.md config locations table

**Changing subagent activation**:
1. Edit `agents/code-researcher.md` frontmatter `description` — this is what auto-routes the subagent. The body is a thin wrapper around `code-research-routing`; do not duplicate skill logic here.

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
| Explicit | `/research <query>` | `commands/research.md` |
| Auto-routing | Architectural questions | `skills/.../SKILL.md` |
| Subagent (clean context) | Multi-hop investigations that would flood the main thread | `agents/code-researcher.md` |

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
