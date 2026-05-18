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
- **Install**: Depends on the provider:
  - VoyageAI: Sign up at https://www.voyageai.com/ and set `VOYAGEAI_API_KEY` in your shell profile
  - OpenAI: Get a key from https://platform.openai.com/api-keys and set `OPENAI_API_KEY` in your shell profile
- **Required by**: ChunkHound's semantic search. Without an embedding provider, ChunkHound cannot generate embeddings for code chunks.

## Configuration Files

### .chunkhound.json
- **Required**: Yes (ChunkHound needs to know which embedding provider to use)
- **Location**: Project root. Also searched in: `.ai/`, `.aider/`, `.cursor/`, `.kite/`, `.llm/`, `.tabnine/`, `.claude/` (last found wins, `.claude/` has highest priority)

**Do not set `indexing.realtime_backend`.** ChunkHound auto-selects the right backend per platform (`watchman` on Linux/Windows x86_64, `watchdog` on macOS). Forcing `realtime_backend: watchman` on macOS breaks startup — ChunkHound bundles Watchman binaries only for `linux/x86_64` and `windows/x86_64` and never falls back to a system `watchman` on `PATH`, so the daemon exits and the MCP server fails to connect (`MCP error -32000`).

#### Setup Questions

1. **Embedding provider**: Which embedding provider do you want to use?
   - `voyageai` — VoyageAI (recommended for code, requires VOYAGEAI_API_KEY)
   - `openai` — OpenAI (requires OPENAI_API_KEY)

2. **Embedding model** (optional): Which embedding model? Leave empty for the provider's default.
   - VoyageAI default: `voyage-code-3`
   - OpenAI default: `text-embedding-3-small`

3. **Config location**: Where do you want to store the config file?
   - `.chunkhound.json` (project root, simplest)
   - `.claude/.chunkhound.json` (Claude-specific, keeps project root clean)

#### Minimal Config

```json
{
  "embedding": {
    "provider": "voyageai"
  }
}
```

#### Full Config Example

```json
{
  "database": {
    "provider": "duckdb",
    "path": ".chunkhound"
  },
  "embedding": {
    "provider": "voyageai",
    "model": "voyage-code-3"
  }
}
```

## Permission Groups

### ChunkHound tools
- **Recommended**: allow
- **Optional**: No
- **Description**: All ChunkHound MCP tools — `code_research`, `search`, and `daemon_status`. Every tool is a read-only query against the local ChunkHound index with no remote side effects, so one allow covers the whole plugin.
- **Patterns**:
  - `mcp__plugin_chunkhound-integration_ChunkHound__*`

## Validation

### ChunkHound Index
After config is created, the codebase must be indexed before semantic search works.

- Run `chunkhound index` via Bash in the project root
- This may take several minutes depending on codebase size
- **Pass**: Output shows files processed and chunks created
- **Fail**: "No config found" (config file missing or in wrong location), "API key not set" (environment variable missing), connection errors (provider unreachable)

### Daemon Status
- Use the `mcp__plugin_chunkhound-integration_ChunkHound__daemon_status` tool
- **Pass**: `status` is healthy, `query_ready` is true, and `scan_progress` indicates the initial scan completed
- **Fail**: Connection error (chunkhound not installed or MCP server not running), `query_ready` false (scan still in progress or failed), or `status` indicates degraded state

## Post-Setup

- Restart Claude Code after initial setup to load the ChunkHound MCP server.
- The `chunkhound index` command must complete before semantic search works. You can ask the `researching-code` skill to run pre-flight ("check if ChunkHound is healthy") for a health check at any time.
- Re-index periodically as the codebase changes: `chunkhound index` (incremental, only processes changed files).
