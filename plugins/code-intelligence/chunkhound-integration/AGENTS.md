@README.md

## Directory Structure

```
plugins/code-intelligence/chunkhound-integration/
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
├── hooks/
│   └── hooks.json                # PreToolUse hook for Grep (suggests ChunkHound)
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
- **Hook** via `hooks/hooks.json`: Suggests ChunkHound for architectural Grep queries

## MCP Tools Reference

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `mcp__plugin_chunkhound-integration_ChunkHound__code_research` | Deep architectural analysis with LLM synthesis | "How does X work?", multi-file relationships |
| `mcp__plugin_chunkhound-integration_ChunkHound__search_semantic` | Find code by meaning/concept | "authentication logic", concept search |
| `mcp__plugin_chunkhound-integration_ChunkHound__search_regex` | Find exact code patterns | Function names, imports, specific syntax |
| `mcp__plugin_chunkhound-integration_ChunkHound__health_check` | Server health status | Verify MCP connection |
| `mcp__plugin_chunkhound-integration_ChunkHound__get_stats` | Database statistics (files, chunks, embeddings) | Check index health |

## Key Navigation Points

| Task | Primary File | Key Concepts |
|------|--------------|--------------|
| Change when to use ChunkHound | `skills/.../SKILL.md` | Decision framework, query patterns |
| Modify research command output | `commands/research.md` | Output format structure |
| Modify status diagnostics | `commands/chunkhound-status.md` | Diagnostic steps, report format |
| Add agent tools | `agents/code-researcher.md` | Frontmatter `tools:` field |
| Modify agent output format | `agents/code-researcher.md` | "Output Format" section |
| Change hook suggestion behavior | `hooks/hooks.json` | Prompt text, conservative threshold |
| Add config discovery location | `scripts/run-chunkhound.sh` | `CONFIG_LOCATIONS` array |
| Modify MCP server invocation | `.mcp.json` | Wrapper script path |

## When to Modify What

**Changing routing decisions** (ChunkHound vs native tools):
1. Edit `skills/code-research-routing/SKILL.md`
2. Modify the decision tables and framework

**Adding new ChunkHound use cases**:
1. Add query patterns to `skills/.../SKILL.md` tables
2. Update agent approach in `agents/code-researcher.md`

**Adding config discovery location** (e.g., `.github/`):
1. Add to `CONFIG_LOCATIONS` array in `scripts/run-chunkhound.sh`
2. Update README.md config locations table

**Modifying hook behavior**:
1. Edit `hooks/hooks.json` prompt text
2. Adjust when to suggest ChunkHound vs proceed with Grep

**Changing agent tools**:
1. Edit `agents/code-researcher.md` frontmatter `tools:` field
2. Update tool references in agent body

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
| Agent | Complex investigations | `agents/code-researcher.md` |
| Hook suggestion | Grep for architectural queries | `hooks/hooks.json` |

## Integration with Other Plugins

Other plugins can reference ChunkHound tools:

```yaml
---
tools:
  - mcp__plugin_chunkhound-integration_ChunkHound__code_research
  - mcp__plugin_chunkhound-integration_ChunkHound__search_semantic
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
