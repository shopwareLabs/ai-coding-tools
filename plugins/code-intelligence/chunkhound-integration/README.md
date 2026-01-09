# ChunkHound Integration

Semantic code research for Claude Code using [ChunkHound's](https://chunkhound.github.io/) multi-hop search and LLM synthesis.

## What is ChunkHound?

ChunkHound is a code research tool that uses:
- **cAST Algorithm**: Structure-aware code chunking that preserves semantic boundaries
- **Multi-hop BFS Search**: Discovers relationships between code components across files
- **LLM Synthesis**: Generates architectural analysis with precise file:line citations

Unlike simple grep searches, ChunkHound understands code semantically - it can answer questions like "how does authentication work?" by tracing data flows and component relationships.

## Prerequisites

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
    "model": "voyage-3.5",
    "batch_size": 256,
    "api_key": "YOUR_VOYAGEAI_KEY",
    "base_url": "https://api.voyageai.com/v1",
    "rerank_model": "rerank-2.5-lite",
    "rerank_url": "/rerank",
    "rerank_batch_size": 32
  },
  "indexing": {
    "include": ["**/*.php", "**/*.js", "**/*.ts", "**/*.vue", "**/*.md"],
    "exclude": ["**/vendor/**", "**/node_modules/**", "**/.git/**", "**/dist/**"]
  },
  "debug": false
}
```

**Embedding providers:**
- `voyageai` - Recommended, requires VoyageAI API key
- `openai` - Requires OpenAI API key
- `ollama` - Local embeddings, no API key needed

#### Configuration File Locations

The plugin auto-discovers `.chunkhound.json` in multiple locations (last match wins):

| Location | LLM Tool |
|----------|----------|
| `.chunkhound.json` | Project root (native ChunkHound) |
| `.ai/.chunkhound.json` | Generic AI config |
| `.aider/.chunkhound.json` | Aider |
| `.cursor/.chunkhound.json` | Cursor AI |
| `.kite/.chunkhound.json` | Kite |
| `.llm/.chunkhound.json` | Generic LLM config |
| `.tabnine/.chunkhound.json` | Tabnine |
| `.claude/.chunkhound.json` | Claude Code (highest priority) |

**Recommended for Claude Code users**: Place config in `.claude/.chunkhound.json` to keep Claude-related files together.

**Environment variable override**: Set `CHUNKHOUND_CONFIG_FILE` to an absolute path for explicit control.

### 3. Index Your Codebase

```bash
cd /path/to/your/project
chunkhound index
```

This creates a `.chunkhound/` directory with the vector database.

### 4. Restart Claude Code

After plugin installation, restart Claude Code to load the MCP server.

## Usage

### Explicit Research Command

```
/research how does authentication work in this codebase?
/research find all components that use the payment service
/research what design patterns are used here?
```

### Automatic Skill Routing

The plugin teaches Claude when to use ChunkHound vs native tools. Simply ask architectural questions:

- "How does the order processing system work?"
- "What patterns are used in this codebase?"
- "Help me understand the data flow"
- "I'm new to this codebase, where should I start?"

### Code Research Agent

For complex investigations, invoke the dedicated agent:

```
Use the code-researcher agent to investigate the authentication architecture
```

### Status Check

```
/chunkhound-status
```

Diagnoses installation, index health, and MCP connectivity.

## When to Use ChunkHound

| Query Type | Best Tool |
|------------|-----------|
| "How does X work?" | ChunkHound |
| "Find all usages of Y" | ChunkHound |
| "What's the architecture?" | ChunkHound |
| "Trace data flow from A to B" | ChunkHound |
| "Show me file.ts" | Native Read |
| "Search for 'TODO'" | Native Grep |
| "Find all *.test.ts" | Native Glob |

## Plugin Components

| Component | Purpose |
|-----------|---------|
| **MCP Server** | Bundles ChunkHound MCP configuration |
| **Skill** | Teaches Claude when to route queries to ChunkHound |
| **Agent** | Context-isolated research for complex investigations |
| **Commands** | `/research` for explicit invocation, `/chunkhound-status` for diagnostics |
| **Hook** | PreToolUse hook suggests ChunkHound for architectural Grep queries |

## Troubleshooting

### "MCP tools not available"

1. Check plugin is enabled: `/plugin list`
2. Verify MCP status: `/mcp`
3. Restart Claude Code (required after plugin installation)

### "No index found"

Run indexing in your project:
```bash
chunkhound index
```

### "Embedding error"

Check your `.chunkhound.json`:
- Verify API key is correct
- Ensure provider is one of: `voyageai`, `openai`, `ollama`

### "code_research returns no results"

- Verify index is up to date: `chunkhound index`
- Check that LLM provider is configured (`"llm": {"provider": "claude-code-cli"}`)
- Try `search_semantic` for simpler queries

## ChunkHound MCP Tools

| Tool | Description |
|------|-------------|
| `mcp__ChunkHound__code_research` | Deep code research for architecture, implementations, relationships |
| `mcp__ChunkHound__search_semantic` | Find code by meaning/concept (understands intent beyond literal text) |
| `mcp__ChunkHound__search_regex` | Find exact code patterns using regex |
| `mcp__ChunkHound__health_check` | Check server health status |
| `mcp__ChunkHound__get_stats` | Get database statistics (file, chunk, embedding counts) |

## Configuration Reference

### Database Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `database.provider` | string | `duckdb` | Database provider (currently only `duckdb` supported) |
| `database.path` | string | `.chunkhound` | Database storage location relative to project root |

**Tip**: Set `database.path` to `.claude/.chunkhound` to keep all Claude-related files together.

### LLM Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `llm.provider` | string | - | LLM provider: `claude-code-cli`, `openai`, `ollama` |
| `llm.utility_model` | string | - | Model for utility tasks (follow-up questions) |
| `llm.synthesis_model` | string | - | Model for synthesis/analysis tasks |

### Embedding Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `embedding.provider` | string | - | Embedding provider: `voyageai`, `openai`, `ollama` |
| `embedding.model` | string | - | Embedding model name (e.g., `voyage-3.5`) |
| `embedding.api_key` | string | - | API key for embedding provider |
| `embedding.batch_size` | integer | - | Batch size for embedding requests |
| `embedding.base_url` | string | - | Base URL for embedding API |
| `embedding.rerank_model` | string | - | Reranking model (e.g., `rerank-2.5-lite`) |
| `embedding.rerank_url` | string | - | Reranking endpoint path |
| `embedding.rerank_batch_size` | integer | - | Batch size for reranking requests |

### Indexing Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `indexing.include` | array | - | Glob patterns for files to index |
| `indexing.exclude` | array | - | Glob patterns for files to exclude |

**Common include patterns:**
```json
["**/*.php", "**/*.js", "**/*.ts", "**/*.tsx", "**/*.vue", "**/*.html", "**/*.twig", "**/*.md", "**/*.json", "**/*.yaml", "**/*.yml", "**/*.xml", "**/*.css", "**/*.scss"]
```

**Common exclude patterns:**
```json
["**/vendor/**", "**/node_modules/**", "**/.git/**", "**/dist/**", "**/build/**", "**/*.min.js", "**/*.min.css", "**/package-lock.json", "**/yarn.lock"]
```

### Other Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `debug` | boolean | `false` | Enable debug output |

## Links

- [ChunkHound Documentation](https://chunkhound.github.io/)
- [Code Research Tool](https://chunkhound.github.io/code-research/)
- [Under the Hood](https://chunkhound.github.io/under-the-hood/)
- [GitHub Repository](https://github.com/chunkhound/chunkhound)
