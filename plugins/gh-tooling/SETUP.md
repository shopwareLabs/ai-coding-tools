# GH Tooling Setup

## Prerequisites

### gh
- **Check**: `gh --version`
- **Install**: https://cli.github.com/
- **Required by**: The gh-tooling MCP server (all GitHub operations)

### gh authentication
- **Check**: `gh auth status`
- **Install**: Run `gh auth login` and follow the prompts
- **Required by**: The gh-tooling MCP server. The CLI must be authenticated with a GitHub account that has access to the repositories you want to work with.

### jq
- **Check**: `jq --version`
- **Install**: https://jqlang.github.io/jq/download/
- **Required by**: The gh-tooling MCP server (JSON processing)

## Configuration Files

### .mcp-gh-tooling.json
- **Required**: No (the MCP server works without it when gh is authenticated. Configuration is only needed to set a default repository or customize hook behavior.)
- **Location**: Project root (higher-priority override: `.claude/.mcp-gh-tooling.json`)
- **Schema reference**: `mcp-server-gh/mcp-gh-tooling.schema.json` in the gh-tooling plugin

#### Setup Questions

1. **Default repository**: Do you want to set a default GitHub repository? If set, you won't need to specify `repo` on every tool call. Enter the repository in `owner/repo` format (e.g., `shopware/shopware`), or leave empty to skip.

2. **Hook enforcement** (optional): The plugin includes hooks that block direct `gh` CLI commands and suggest using MCP tools instead. Do you want to keep this enabled?
   - `true` (default) — Block direct gh commands, suggest MCP tools
   - `false` — Allow direct gh commands alongside MCP tools

#### Minimal Config

```json
{
  "repo": "shopware/shopware"
}
```

#### Full Config Example

```json
{
  "repo": "shopware/shopware",
  "enforce_mcp_tools": true,
  "block_api_commands": true
}
```

## Validation

### MCP Server Connection
- Use the `mcp__plugin_gh-tooling_gh-tooling__pr_list` tool with state "open" and limit 1
- **Pass**: Returns a list (even if empty) of pull requests
- **Fail**: Connection error, authentication error, or "repo required" error
- Common failure causes: gh not authenticated, default repo not set and no repo passed, gh CLI not installed

## Post-Setup

- Restart Claude Code after creating the configuration file. The MCP server is loaded at startup.
- If you created no configuration file (because gh is already authenticated and you don't need a default repo), no restart is necessary. The MCP server works with zero configuration.
