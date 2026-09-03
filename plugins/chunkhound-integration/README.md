# ChunkHound Integration

Semantic code research for Claude Code using [ChunkHound's](https://chunkhound.ai/) multi-hop search and LLM synthesis.

## 🔬 What is ChunkHound?

ChunkHound is a code research tool that uses:
- **cAST Algorithm**: Structure-aware code chunking that preserves semantic boundaries
- **Multi-hop BFS Search**: Discovers relationships between code components across files
- **LLM Synthesis**: Generates architectural analysis with precise file:line citations

Unlike simple grep searches, ChunkHound understands code semantically - it can answer questions like "how does authentication work?" by tracing data flows and component relationships.

## 📦 Setup

The quickest way to get started is the interactive setup skill. Install the `plugin-setup` plugin, then ask Claude:

```bash
/plugin install plugin-setup@shopware-ai-coding-tools
```

```
Help me set up chunkhound-integration
```

The `chunkhound-integration-setting-up` skill walks you through installation, embedding provider configuration, indexing, and validation. You can also follow the manual steps below.

## 📦 Prerequisites

### 1. Install ChunkHound

```bash
uv tool install chunkhound
```

### 2. Configure ChunkHound

Create `.chunkhound.json` in one of the supported locations.

**Minimal configuration:**

```json
{
  "embedding": {
    "provider": "voyageai",
    "api_key": "YOUR_VOYAGEAI_KEY"
  },
  "llm": {
    "provider": "claude-code-cli"
  }
}
```

**Complete configuration example:**

```json
{
  "database": {
    "provider": "duckdb",
    "path": ".claude/.chunkhound"
  },
  "llm": {
    "provider": "claude-code-cli",
    "utility_model": "claude-opus-4-5",
    "synthesis_model": "claude-opus-4-5"
  },
  "embedding": {
    "provider": "voyageai",
    "model": "voyage-4-lite",
    "batch_size": 256,
    "api_key": "YOUR_VOYAGEAI_KEY",
    "base_url": "https://api.voyageai.com/v1",
    "rerank_model": "rerank-2.5-lite",
    "rerank_url": "/rerank",
    "rerank_batch_size": 32
  },
  "indexing": {
    "include": ["**/*.php", "**/*.js", "**/*.ts", "**/*.vue"],
    "exclude": ["**/*.md", "**/vendor/**", "**/node_modules/**", "**/.git/**", "**/dist/**"]
  },
  "debug": false
}
```

> [!TIP]
> The example deliberately keeps Markdown out of the index. Documentation drifts from the code it describes, and in documentation-heavy domains indexed docs can outweigh — and outrank — the code evidence in semantic results and LLM synthesis. The `researching-code` skill reads documentation files directly and weights them against code evidence either way (see [Documentation handling](#documentation-handling)), so excluding docs costs little. One caveat: in projects whose runtime behavior lives in Markdown (agent instructions, skill files), keep those specific files indexed with narrower globs — for them, Markdown *is* the code.

**Embedding providers:**
- `voyageai` - Recommended, requires VoyageAI API key
- `openai` - Requires OpenAI API key

#### Configuration File Locations

The plugin auto-discovers `.chunkhound.json` in multiple locations (last match wins):

| Location                    | LLM Tool                         |
|-----------------------------|----------------------------------|
| `.chunkhound.json`          | Project root (native ChunkHound) |
| `.ai/.chunkhound.json`      | Generic AI config                |
| `.aider/.chunkhound.json`   | Aider                            |
| `.cursor/.chunkhound.json`  | Cursor AI                        |
| `.kite/.chunkhound.json`    | Kite                             |
| `.llm/.chunkhound.json`     | Generic LLM config               |
| `.tabnine/.chunkhound.json` | Tabnine                          |
| `.claude/.chunkhound.json`  | Claude Code (highest priority)   |

**Recommended for Claude Code users**: Place config in `.claude/.chunkhound.json` to keep Claude-related files together.

**Environment variable override**: Set `CHUNKHOUND_CONFIG_FILE` to an absolute path for explicit control.

### 3. Index Your Codebase

```bash
cd /path/to/your/project
CHUNKHOUND_DB_EXECUTE_TIMEOUT=120 chunkhound index
```

This creates a `.chunkhound/` directory with the vector database. The `CHUNKHOUND_DB_EXECUTE_TIMEOUT=120` prefix raises ChunkHound's database operation timeout to 120 seconds — see [Database operation timeout](#database-operation-timeout) for why.

### 4. Restart Claude Code

After plugin installation, restart Claude Code to load the MCP server.

## 💡 Usage

### Ask in natural language

The `researching-code` skill auto-activates on architectural and semantic questions. Just ask:

- "How does the order processing system work?"
- "Find all components that use the payment service"
- "What design patterns are used here?"
- "Trace the data flow from the API to the database"
- "I'm new to this codebase, where should I start?"

The skill picks a research depth (surface, broad, or deep), opens the search with the ChunkHound primitive that fits the question shape, and returns synthesized findings with `file:line` citations.

### Force ChunkHound synthesis

To force `code_research` synthesis regardless of question shape, include a directive in the prompt:

- "Use code_research to explain how authentication works"
- "Research this with synthesis: how is caching layered across the request lifecycle"
- "Force code_research: what assumptions does the order pipeline make about inventory"

### Code Research Agent

For investigations that would flood the main conversation with intermediate results, invoke the dedicated agent:

```
Use the code-researcher agent to investigate the authentication architecture
```

### Health check

Ask the skill to run pre-flight and report:

- "Check if ChunkHound is healthy"
- "Run a ChunkHound setup diagnostic"

The skill runs `daemon_status`, surfaces any failed gates, and emits remediation steps (installation check, config discovery, database check, embedding-provider check).

## 🧭 What the skill uses internally

| Query Type                                 | Primitive                       |
|--------------------------------------------|---------------------------------|
| "How does X work?"                         | `code_research`                 |
| "What's the architecture?"                 | `code_research`                 |
| "Trace data flow from A to B"              | `code_research`                 |
| "Where does X happen?" / concept lookup    | `search` semantic               |
| "Find all callers of X"                    | `search` semantic, then sweep script |
| "Search for the exact string 'TODO'"       | `search` regex                  |
| "Show me file.ts"                          | `Read`                          |
| "Find all *.test.ts"                       | `bfs` via Bash                  |
| Exhaustive sweep after ChunkHound narrowed | bundled `sweep.sh` via Bash     |
| Documentation (Markdown) content           | `bfs`/`ugrep` (Markdown-confined) to locate, `Read` |

A ChunkHound primitive opens every code search, with semantic preferred over regex. The bundled sweep script (`skills/researching-code/scripts/sweep.sh`, a fixed `ugrep` ERE wrapper that appends a tool-computed `count:` line) is a complement: it confirms an enumeration is exhaustive after ChunkHound has located the surface, and never opens a query on the grounds that it looks trivial. The wrapper exists because hand-assembled grep calls and hand-tallied result counts are both proven failure modes. (`bfs` is exempt — matching file paths is not searching code.) A word-based search misses indirect callers, dynamic dispatch, container wiring, and string-keyed references — exactly the surface a refactoring must cover.

## 🗂️ Supported Languages

ChunkHound parses a fixed set of languages. The `researching-code` skill knows this set and treats files outside it as a **coverage gap to surface**, not to backfill with native grep — see the skill's `Language scope` rule. When a research topic could touch unsupported files (e.g. `.twig` in Shopware, `.erb` in Rails, `.heex` in Phoenix LiveView), the skill reports them under **Coverage caveats** in the synthesis output so the caller decides how to follow up.

The enumeration lives in [`skills/researching-code/references/supported-languages.md`](./skills/researching-code/references/supported-languages.md) and mirrors the upstream ChunkHound source:

- `Language` enum — [`chunkhound/core/types/common.py`](https://github.com/chunkhound/chunkhound/blob/main/chunkhound/core/types/common.py)
- `EXTENSION_TO_LANGUAGE` map — [`chunkhound/parsers/parser_factory.py`](https://github.com/chunkhound/chunkhound/blob/main/chunkhound/parsers/parser_factory.py)

### Documentation handling

Markdown is in ChunkHound's parser set, but the skill treats documentation as a special case regardless of whether it is indexed — documentation drifts from the code it describes, so it is secondary evidence, never a coverage gap and never a source on par with code. The skill locates doc files with `bfs` (narrowing by content with Markdown-confined `ugrep` where filenames alone cannot identify relevance), reads them directly, and corroborates any doc-derived claim against the code before it enters the findings. Claims land in a dedicated **Documentation evidence** output section labeled corroborated, uncorroborated, or contradicted — contradictions are reported as suspected drift. The full procedure lives in [`skills/researching-code/references/documentation-scope.md`](./skills/researching-code/references/documentation-scope.md), consumed by the skill's `Documentation scope` rule. Because docs are read directly, excluding them from the index (see the configuration tip above) costs little.

## 🧩 Plugin Components

| Component      | Purpose                                                                      |
|----------------|------------------------------------------------------------------------------|
| **MCP Server** | Bundles ChunkHound MCP configuration                                         |
| **Skill**      | `researching-code` — executes code research and returns synthesized findings |
| **Agent**      | `code-researcher` — context-isolated wrapper around the skill                |

## 🩺 Troubleshooting

### "MCP tools not available"

1. Check plugin is enabled: `/plugin list`
2. Verify MCP status: `/mcp`
3. Restart Claude Code (required after plugin installation)

### "No index found"

Run indexing in your project:
```bash
CHUNKHOUND_DB_EXECUTE_TIMEOUT=120 chunkhound index
```

### "Embedding error"

Check your `.chunkhound.json`:
- Verify API key is correct
- Ensure provider is one of: `voyageai`, `openai`

### "code_research returns no results"

- Verify index is up to date: `CHUNKHOUND_DB_EXECUTE_TIMEOUT=120 chunkhound index`
- Check that LLM provider is configured (`"llm": {"provider": "claude-code-cli"}`)
- Try `search` with `type: "semantic"` for simpler queries

## 🗜️ ChunkHound MCP Tools

| Tool                                                           | Description                                                              |
|----------------------------------------------------------------|--------------------------------------------------------------------------|
| `mcp__plugin_chunkhound-integration_ChunkHound__code_research` | Deep code research for architecture, implementations, relationships      |
| `mcp__plugin_chunkhound-integration_ChunkHound__search`        | Pinpoint exact locations via regex or semantic search (`type` parameter) |
| `mcp__plugin_chunkhound-integration_ChunkHound__daemon_status` | Check daemon health, scan progress, and realtime indexing readiness      |

## 🎛️ Configuration Reference

ChunkHound's full configuration schema lives in the [ChunkHound configuration docs](https://chunkhound.ai/docs/configuration/) — provider lists, defaults, environment variables, CLI overrides, and the precedence hierarchy. This section documents only the plugin-specific guidance on top of that.

### Database provider

Use the ChunkHound default `duckdb`. Set `database.path` to `.claude/.chunkhound` to keep all Claude-related files together.

### Database operation timeout

The plugin sets `CHUNKHOUND_DB_EXECUTE_TIMEOUT=120` in the MCP server registration, raising ChunkHound's database operation timeout to 120 seconds. ChunkHound 5.2 introduced DuckDB auto-compaction to prevent the database file from growing beyond reasonable size, and compaction can push individual database operations past the default timeout. The variable was recognized before 5.2 as well, so it does no harm on older ChunkHound versions. When running `chunkhound index` manually, use the same prefix: `CHUNKHOUND_DB_EXECUTE_TIMEOUT=120 chunkhound index`.

### Parallel use

> [!IMPORTANT]
> ChunkHound serializes parallel MCP clients onto a single DuckDB writer connection inside its background daemon. Running multiple ChunkHound queries in parallel (for example, from several subagents at once) does not reduce wall-clock time — the calls queue at the daemon — and consumes extra agent spawn overhead and tokens. Prefer sequential invocations.

The plugin enforces this opinion at runtime via a SessionStart hook that injects a directive instructing the model to dispatch any subagent performing ChunkHound operations sequentially. The directive applies to the bundled `code-researcher` agent and to any other subagent (general-purpose or custom) whose task involves `mcp__plugin_chunkhound-integration_ChunkHound__search` or `mcp__plugin_chunkhound-integration_ChunkHound__code_research`. Use sequential dispatch even when ad-hoc parallelism is technically possible.

### Realtime backend

**Do not set `indexing.realtime_backend`.** ChunkHound auto-selects the right backend per platform (`watchman` on Linux/Windows x86_64, `watchdog` on macOS). Forcing `realtime_backend: watchman` on macOS breaks startup because ChunkHound bundles Watchman binaries only for `linux/x86_64` and `windows/x86_64` and never falls back to a system `watchman` on `PATH`.

## 🔗 Links

- [ChunkHound Documentation](https://chunkhound.ai/)
- [ChunkHound Configuration](https://chunkhound.ai/docs/configuration/)
- [GitHub Repository](https://github.com/chunkhound/chunkhound)
