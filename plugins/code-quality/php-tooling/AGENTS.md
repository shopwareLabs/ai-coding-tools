@README.md

## Directory & File Structure

```
plugins/code-quality/php-tooling/
├── README.md                           # User documentation (usage, configuration, troubleshooting)
├── AGENTS.md                           # LLM navigation guide (this file)
├── CLAUDE.md                           # Points to AGENTS.md
├── CHANGELOG.md                        # Version history
├── LICENSE                             # MIT license
├── .mcp.json                           # MCP server registration for Claude Code
└── mcp-server/
    ├── server.sh                       # Entry point - sources libs, loads config, starts JSON-RPC loop
    ├── mcpserver_core.sh               # JSON-RPC 2.0 protocol handler (process_request, handle_*)
    ├── config.json                     # Server metadata (name, version, capabilities)
    ├── tools.json                      # Tool definitions with JSON Schema Draft 7 inputSchema
    ├── mcp-php-tooling.schema.json     # JSON Schema for .mcp-php-tooling.json config file
    └── lib/
        ├── config.sh                   # Config discovery & merging (load_config, CONFIG_LOCATIONS)
        ├── environment.sh              # detect_environment(), wrap_command(), exec_command()
        ├── phpstan.sh                  # tool_phpstan_analyze() implementation
        ├── ecs.sh                      # tool_ecs_check(), tool_ecs_fix() implementations
        ├── phpunit.sh                  # tool_phpunit_run() implementation
        └── console.sh                  # tool_console_run() implementation
```

## Component Overview

This plugin provides:
- **MCP Server** (`.mcp.json` + `mcp-server/`) - PHP linting tools via Model Context Protocol
- No commands, agents, or skills (pure MCP server plugin)

## MCP Server Architecture

### Protocol Flow

```
Claude Code → stdin → server.sh → mcpserver_core.sh → tool_* function
                                                           ↓
Claude Code ← stdout ← JSON-RPC response ← formatted output
```

### Tool Dispatch Convention

Tools in `tools.json` map to bash functions with `tool_` prefix. Functions receive JSON arguments as `$1`:

```bash
tool_example() {
    local args="$1"
    local paths=$(echo "$args" | jq -r '.paths // []')
    exec_command "some-command $paths"
}
```

### Environment Abstraction

All tools use `exec_command()` from `environment.sh` which wraps commands based on detected environment (native, docker, vagrant, ddev).

## Key Navigation Points

| Task | Primary File | Secondary File | Key Concepts |
|------|--------------|----------------|--------------|
| Modify tool schemas | `mcp-server/tools.json` | - | JSON Schema Draft 7, inputSchema |
| Add new linting tool | `mcp-server/lib/<tool>.sh` | `mcp-server/tools.json` | tool_* function, exec_command() |
| Add config location | `mcp-server/lib/config.sh` | - | CONFIG_LOCATIONS array, load_config() |
| Change config merging | `mcp-server/lib/config.sh` | - | _merge_configs(), jq deep merge |
| Change environment detection | `mcp-server/lib/environment.sh` | - | detect_environment(), config file parsing |
| Modify command wrapping | `mcp-server/lib/environment.sh` | - | wrap_command(), environment-specific execution |
| Change PHPStan logic | `mcp-server/lib/phpstan.sh` | `mcp-server/tools.json` | tool_phpstan_analyze(), format_phpstan_output() |
| Change ECS logic | `mcp-server/lib/ecs.sh` | `mcp-server/tools.json` | tool_ecs_check(), tool_ecs_fix() |
| Change PHPUnit logic | `mcp-server/lib/phpunit.sh` | `mcp-server/tools.json` | tool_phpunit_run() |
| Change Console logic | `mcp-server/lib/console.sh` | `mcp-server/tools.json` | tool_console_run(), tool_console_list() |
| Modify MCP protocol | `mcp-server/mcpserver_core.sh` | - | process_request(), handle_* functions |
| Update server metadata | `mcp-server/config.json` | `.mcp.json` | Server name, version, capabilities |

## When to Modify What

**Adding a new config location** → Edit `CONFIG_LOCATIONS` array in `mcp-server/lib/config.sh` + update README.md

**Adding a new linting tool** (e.g., eslint) → Create `mcp-server/lib/eslint.sh` with `tool_eslint_check()` + add definition to `tools.json` + source in `server.sh` + update README.md

**Changing environment detection logic** → Edit `mcp-server/lib/environment.sh` `detect_environment()` function

**Adding new environment type** → Edit `detect_environment()` detection logic + add case in `wrap_command()` + document in README.md

**Modifying command execution for environment** → Edit `mcp-server/lib/environment.sh` `wrap_command()` function

**Changing tool output formatting** → Edit respective `lib/<tool>.sh` formatting functions

**Changing console command execution** → Edit `mcp-server/lib/console.sh` `tool_console_run()` function

**Adding new MCP protocol methods** → Edit `mcp-server/mcpserver_core.sh` add case in `process_request()`

**Changing tool parameter schema** → Edit `mcp-server/tools.json` inputSchema for the tool

**Modifying tool description** → Edit `mcp-server/tools.json` description field + update README.md

## Integration with Other Plugins

MCP tool names follow pattern: `mcp__php-tooling__<tool_name>`

Other plugins reference tools via frontmatter:
```yaml
tools: mcp__php-tooling__phpstan_analyze, mcp__php-tooling__ecs_check, mcp__php-tooling__phpunit_run, mcp__php-tooling__console_run, mcp__php-tooling__console_list
```

## External References

- [Bash MCP SDK](https://github.com/muthuishere/mcp-server-bash-sdk) - SDK this server is based on
- [MCP Protocol Specification](https://modelcontextprotocol.io/specification) - JSON-RPC 2.0 protocol details
