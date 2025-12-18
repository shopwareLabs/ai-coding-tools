@README.md

## Directory & File Structure

```
plugins/code-quality/dev-tooling/
├── README.md                           # User documentation (usage, configuration, troubleshooting)
├── AGENTS.md                           # LLM navigation guide (this file)
├── CLAUDE.md                           # Points to AGENTS.md
├── CHANGELOG.md                        # Version history
├── LICENSE                             # MIT license
├── .mcp.json                           # MCP server registration (php-tooling, js-admin-tooling, js-storefront-tooling)
│
├── shared/                             # SHARED FRAMEWORK (language-agnostic)
│   ├── mcpserver_core.sh              # JSON-RPC 2.0 protocol handler
│   ├── config.sh                      # Config discovery & merging (parameterized via CONFIG_PREFIX)
│   ├── environment.sh                 # Environment detection, PHP & JS command wrapping
│   └── mcp-js-tooling.schema.json     # JSON Schema for .mcp-js-tooling.json (shared by JS servers)
│
├── mcp-server-php/                     # PHP TOOLS MCP SERVER
│   ├── server.sh                      # Entry point - sets CONFIG_PREFIX="php-tooling"
│   ├── config.json                    # Server metadata (name="php-tooling")
│   ├── tools.json                     # PHPStan, ECS, PHPUnit, Console tool schemas
│   ├── mcp-php-tooling.schema.json    # JSON Schema for .mcp-php-tooling.json
│   └── lib/
│       ├── phpstan.sh                 # tool_phpstan_analyze()
│       ├── ecs.sh                     # tool_ecs_check(), tool_ecs_fix()
│       ├── phpunit.sh                 # tool_phpunit_run()
│       └── console.sh                 # tool_console_run(), tool_console_list()
│
├── mcp-server-js-admin/                   # ADMIN JS TOOLS MCP SERVER
│   ├── server.sh                      # Entry point - sets CONFIG_PREFIX="js-tooling" (shared)
│   ├── config.json                    # Server metadata (name="js-admin-tooling")
│   ├── tools.json                     # ESLint, Stylelint, Prettier, Jest, TSC, Vite tools
│   └── lib/
│       ├── eslint.sh                  # tool_eslint_check(), tool_eslint_fix()
│       ├── stylelint.sh               # tool_stylelint_check(), tool_stylelint_fix()
│       ├── prettier.sh                # tool_prettier_check(), tool_prettier_fix()
│       ├── jest.sh                    # tool_jest_run()
│       ├── tsc.sh                     # tool_tsc_check()
│       └── build.sh                   # tool_vite_build()
│
└── mcp-server-js-storefront/              # STOREFRONT JS TOOLS MCP SERVER
    ├── server.sh                      # Entry point - sets CONFIG_PREFIX="js-tooling" (shared)
    ├── config.json                    # Server metadata (name="js-storefront-tooling")
    ├── tools.json                     # ESLint, Stylelint, Jest, Webpack tools
    └── lib/
        ├── eslint.sh                  # tool_eslint_check(), tool_eslint_fix()
        ├── stylelint.sh               # tool_stylelint_check(), tool_stylelint_fix()
        ├── jest.sh                    # tool_jest_run()
        └── build.sh                   # tool_webpack_build()
```

## Component Overview

This plugin provides:
- **Three MCP Servers** via `.mcp.json`:
  - `php-tooling` - PHP linting/testing tools
  - `js-admin-tooling` - Administration JavaScript tools (Vue 3/Vite)
  - `js-storefront-tooling` - Storefront JavaScript tools (vanilla JS/Webpack)
- **Shared Framework** in `shared/` - reusable across all servers

## Architecture

### Shared Framework Pattern

All MCP servers source shared framework files:
```bash
source "${SHARED_DIR}/mcpserver_core.sh"  # JSON-RPC protocol
source "${SHARED_DIR}/config.sh"           # Config discovery
source "${SHARED_DIR}/environment.sh"      # Command execution
```

### CONFIG_PREFIX Parameterization

The `config.sh` module uses `CONFIG_PREFIX` to determine:
- Config file name: `.mcp-${CONFIG_PREFIX}.json`
- Environment variable: `MCP_${PREFIX}_CONFIG` (uppercased, hyphens→underscores)

```bash
# In mcp-server-php/server.sh
CONFIG_PREFIX="php-tooling"
source "${SHARED_DIR}/config.sh"
# Looks for: .mcp-php-tooling.json, MCP_PHP_TOOLING_CONFIG

# In mcp-server-js-admin/server.sh
CONFIG_PREFIX="js-tooling"
JS_CONTEXT="admin"
source "${SHARED_DIR}/config.sh"
# Looks for: .mcp-js-tooling.json, MCP_JS_TOOLING_CONFIG
# JS_CONTEXT determines workdir: src/Administration/Resources/app/administration

# In mcp-server-js-storefront/server.sh
CONFIG_PREFIX="js-tooling"
JS_CONTEXT="storefront"
source "${SHARED_DIR}/config.sh"
# Looks for: .mcp-js-tooling.json, MCP_JS_TOOLING_CONFIG
# JS_CONTEXT determines workdir: src/Storefront/Resources/app/storefront
```

### Protocol Flow

```
Claude Code → stdin → server.sh → mcpserver_core.sh → tool_* function
                                                           ↓
Claude Code ← stdout ← JSON-RPC response ← formatted output
```

### Tool Dispatch Convention

Tools in `tools.json` map to bash functions with `tool_` prefix:

```bash
# Admin/Storefront servers - hardcoded npm script names from Shopware package.json
tool_eslint_check() {
    local args="$1"
    local cmd="npm run lint -- ..."  # Admin uses "lint", Storefront uses "lint:js"
    exec_npm_command "${cmd}"
}
```

### Command Execution

- **PHP tools**: Use `exec_command()` which wraps via `wrap_command()`
- **JS tools**: Use `exec_npm_command()` which wraps via `wrap_npm_command()`

Both handle environment-specific execution (native/docker/vagrant/ddev).

## Key Navigation Points

| Task | Primary File | Secondary File | Key Concepts |
|------|--------------|----------------|--------------|
| Add PHP tool | `mcp-server-php/lib/<tool>.sh` | `mcp-server-php/tools.json` | `tool_*()`, `exec_command()` |
| Add Admin JS tool | `mcp-server-js-admin/lib/<tool>.sh` | `mcp-server-js-admin/tools.json` | `tool_*()`, `exec_npm_command()` |
| Add Storefront JS tool | `mcp-server-js-storefront/lib/<tool>.sh` | `mcp-server-js-storefront/tools.json` | `tool_*()`, `exec_npm_command()` |
| Add config location | `shared/config.sh` | - | `CONFIG_LOCATIONS` array |
| Add environment type | `shared/environment.sh` | - | `wrap_command()`, `wrap_npm_command()` |
| Modify protocol | `shared/mcpserver_core.sh` | - | `process_request()`, `handle_*()` |
| Update tool schemas | `mcp-server-*/tools.json` | - | JSON Schema Draft 7 |
| Register new server | `.mcp.json` | - | `mcpServers` object |

## When to Modify What

**Adding a new PHP linting tool:**
1. Create `mcp-server-php/lib/<tool>.sh` with `tool_<name>()`
2. Add tool definition to `mcp-server-php/tools.json`
3. Source in `mcp-server-php/server.sh`
4. Update README.md

**Adding a new Admin JS tool:**
1. Create `mcp-server-js-admin/lib/<tool>.sh` with `tool_<name>()` using hardcoded npm script name
2. Add tool definition to `mcp-server-js-admin/tools.json`
3. Source the file in `mcp-server-js-admin/server.sh`
4. Update README.md

**Adding a new Storefront JS tool:**
1. Create `mcp-server-js-storefront/lib/<tool>.sh` with `tool_<name>()` using hardcoded npm script name
2. Add tool definition to `mcp-server-js-storefront/tools.json`
3. Source the file in `mcp-server-js-storefront/server.sh`
4. Update README.md

**Adding new environment type** (e.g., podman):
1. Edit `shared/environment.sh` `detect_environment()`
2. Add case in `wrap_command()` for PHP
3. Add case in `wrap_npm_command()` for JS
4. Document in README.md

**Adding new config location** (e.g., `.github/`):
1. Add to `CONFIG_LOCATIONS` array in `shared/config.sh`
2. Update README.md

**Adding a third language** (e.g., Python):
1. Create `mcp-server-python/` with same structure
2. Set `CONFIG_PREFIX="python-tooling"` in server.sh
3. Add to `.mcp.json` as `python-tooling` server
4. Optionally add `wrap_python_command()` to environment.sh

## Integration with Other Plugins

MCP tool names follow pattern: `mcp__<server-name>__<tool_name>`

```yaml
# PHP tools
tools: mcp__php-tooling__phpstan_analyze, mcp__php-tooling__ecs_check

# Admin JS tools
tools: mcp__js-admin-tooling__eslint_check, mcp__js-admin-tooling__jest_run

# Storefront JS tools
tools: mcp__js-storefront-tooling__eslint_check, mcp__js-storefront-tooling__webpack_build
```

## External References

- [Bash MCP SDK](https://github.com/muthuishere/mcp-server-bash-sdk) - SDK this server is based on
- [MCP Protocol Specification](https://modelcontextprotocol.io/specification) - JSON-RPC 2.0 protocol details
