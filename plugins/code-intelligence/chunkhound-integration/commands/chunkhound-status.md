---
name: chunkhound-status
description: Check ChunkHound setup and index health
---

Run these diagnostics to verify ChunkHound is properly configured:

## Diagnostic Steps

1. **Check installation**: Run `chunkhound --version` via Bash to verify chunkhound is installed

2. **Check configuration**: Look for `.chunkhound.json` in priority order (last wins): project root, `.ai/`, `.aider/`, `.cursor/`, `.kite/`, `.llm/`, `.tabnine/`, `.claude/`. Read the highest-priority config found.

3. **Check database exists**: Check for the database at the configured `database.path` (defaults to `.chunkhound` if unspecified). Use Bash `ls -la` on the actual path from config.

4. **Test MCP connection**: Use `mcp__ChunkHound__health_check` to verify server status, then `mcp__ChunkHound__get_stats` to check index statistics

## Report Format

Summarize findings as:

| Component | Status | Details |
|-----------|--------|---------|
| Installation | OK/Missing | Version or error message |
| Index | OK/Missing | Path and last modified |
| Config | OK/Missing | Provider configured |
| MCP Tools | OK/Unavailable | Tool availability |

## Common Issues

If **index is missing**, instruct user:
```bash
cd /path/to/project
chunkhound index
```

If **config is missing**, provide template:
```json
{
  "embedding": {
    "provider": "voyageai",
    "api_key": "YOUR_API_KEY"
  },
  "llm": {
    "provider": "claude-code-cli"
  }
}
```

If **MCP tools unavailable**, remind user to restart Claude Code after plugin installation.
