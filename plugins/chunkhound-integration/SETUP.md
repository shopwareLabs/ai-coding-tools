# ChunkHound Integration Setup

## Prerequisites

### chunkhound
- **Check**: `chunkhound --version`
- **Install**: `uv tool install chunkhound` (requires [uv](https://docs.astral.sh/uv/getting-started/installation/))
- **Required by**: The ChunkHound MCP server (all semantic search and code research operations)

### Embedding provider API key
- **Check**: Depends on the provider you choose:
  - VoyageAI: `echo $VOYAGEAI_API_KEY` (should print a non-empty value)
  - OpenAI: `echo $OPENAI_API_KEY` (should print a non-empty value)
  - Ollama: `ollama list` (should show available models; no API key needed)
- **Install**: Depends on the provider:
  - VoyageAI: Sign up at https://www.voyageai.com/ and set `VOYAGEAI_API_KEY` in your shell profile
  - OpenAI: Get a key from https://platform.openai.com/api-keys and set `OPENAI_API_KEY` in your shell profile
  - Ollama: Install from https://ollama.com/ and pull an embedding model (e.g., `ollama pull nomic-embed-text`)
- **Required by**: ChunkHound's semantic search. Without an embedding provider, ChunkHound cannot generate embeddings for code chunks.

## Configuration Files

### .chunkhound.json
- **Required**: Yes (ChunkHound needs to know which embedding provider to use)
- **Location**: Project root. Also searched in: `.ai/`, `.aider/`, `.cursor/`, `.kite/`, `.llm/`, `.tabnine/`, `.claude/` (last found wins, `.claude/` has highest priority)

#### Setup Questions

1. **Embedding provider**: Which embedding provider do you want to use?
   - `voyageai` — VoyageAI (recommended for code, requires VOYAGEAI_API_KEY)
   - `openai` — OpenAI (requires OPENAI_API_KEY)
   - `ollama` — Ollama (runs locally, no API key needed, requires Ollama installed)

2. **Embedding model** (optional): Which embedding model? Leave empty for the provider's default.
   - VoyageAI default: `voyage-code-3`
   - OpenAI default: `text-embedding-3-small`
   - Ollama default: `nomic-embed-text`

3. **Config location**: Where do you want to store the config file?
   - `.chunkhound.json` (project root, simplest)
   - `.claude/.chunkhound.json` (Claude-specific, keeps project root clean)

#### Minimal Config

```json
{
  "embeddings": {
    "provider": "voyageai"
  }
}
```

#### Full Config Example

```json
{
  "embeddings": {
    "provider": "voyageai",
    "model": "voyage-code-3"
  },
  "database": {
    "path": ".chunkhound"
  }
}
```

## Validation

### ChunkHound Index
After config is created, the codebase must be indexed before semantic search works.

- Run `chunkhound index` via Bash in the project root
- This may take several minutes depending on codebase size
- **Pass**: Output shows files processed and chunks created
- **Fail**: "No config found" (config file missing or in wrong location), "API key not set" (environment variable missing), connection errors (provider unreachable)

### MCP Server Health
- Use the `mcp__plugin_chunkhound-integration_ChunkHound__health_check` tool
- **Pass**: Returns server status information
- **Fail**: Connection error (chunkhound not installed or MCP server not running)

### Index Statistics
- Use the `mcp__plugin_chunkhound-integration_ChunkHound__get_stats` tool
- **Pass**: Returns file count, chunk count, and embedding count (all > 0 after indexing)
- **Fail**: Zero embeddings (index not built or config wrong), connection error

## Post-Setup

- Restart Claude Code after initial setup to load the ChunkHound MCP server.
- The `chunkhound index` command must complete before semantic search works. You can check index health anytime with `/chunkhound-status`.
- Re-index periodically as the codebase changes: `chunkhound index` (incremental, only processes changed files).
