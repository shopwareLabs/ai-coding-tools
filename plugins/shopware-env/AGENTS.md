@README.md

## Component Overview

This plugin provides:
- **One MCP Server** via `.mcp.json`:
  - `lifecycle-tooling` — 8 tools for dependencies, database, frontend builds, and plugin management
- **SessionStart Hook** via `hooks/hooks.json`:
  - Injects lifecycle tool directives into conversation context at session start
  - Prompt maintained in `hooks/prompts/mcp-tool-directives.md`
  - Outputs JSON `additionalContext` format
- **PreToolUse Hook** via `hooks/hooks.json`:
  - Blocks bash commands that should use lifecycle MCP tools instead
  - Blocks: `composer install/update`, `npm install/ci`, `bin/console system:install`, `bin/console plugin:create`, `bin/console plugin:install/refresh/activate`, `bin/console bundle:dump`, `bin/console assets:install`, `bin/console feature:dump`, `bin/console framework:schema:dump`, `bin/console theme:compile`
  - Configurable via `enforce_mcp_tools: false` in `.mcp-php-tooling.json`
- **One Skill** (`dev-environment-bootstrapping`):
  - Orchestrates the full first-run setup: detects state, proposes a plan, confirms with the user, executes lifecycle tools
  - Activates automatically when the user asks to bootstrap, set up, or initialize a Shopware environment

## Directory & File Structure

```
plugins/shopware-env/
├── README.md                                      # User documentation
├── AGENTS.md                                      # LLM navigation guide (this file)
├── CLAUDE.md                                      # Points to AGENTS.md
├── CHANGELOG.md                                   # Version history
├── LICENSE                                        # MIT license
├── .mcp.json                                      # MCP server registration (lifecycle-tooling)
│
├── hooks/                                         # HOOKS (MCP tool enforcement)
│   ├── hooks.json                                 # Hook configuration (SessionStart + PreToolUse)
│   ├── prompts/
│   │   └── mcp-tool-directives.md                 # SessionStart prompt: lifecycle tool listing and usage rules
│   └── scripts/
│       ├── session-start.sh                       # SessionStart hook: reads prompt file, checks enforcement, outputs JSON
│       ├── check-lifecycle-tools.sh               # Blocks composer, npm, bin/console lifecycle commands
│       └── lib/
│           └── common.sh                          # Shared: parse_hook_input(), load_mcp_config(), block_tool()
│
├── shared/                                        # SHARED FRAMEWORK (byte-identical to dev-tooling templates)
│   ├── mcpserver_core.sh                          # JSON-RPC 2.0 protocol handler
│   ├── config.sh                                  # Config discovery & merging (CONFIG_PREFIX parameterized)
│   ├── environment.sh                             # Environment detection, command wrapping, noise filtering
│   └── docker-compose.sh                          # Docker Compose environment: call-time container/workdir resolution
│
├── mcp-server-lifecycle/                          # LIFECYCLE TOOLS MCP SERVER
│   ├── server.sh                                  # Entry point — sets CONFIG_PREFIX="php-tooling"
│   ├── config.json                                # Server metadata (name="lifecycle-tooling")
│   ├── tools.json                                 # All 8 tool schemas
│   └── lib/
│       ├── resolve_env.sh                         # resolve_lifecycle_env(): config-wins env resolution
│       ├── dependencies.sh                        # tool_install_dependencies()
│       ├── database.sh                            # tool_database_install(), tool_database_reset()
│       ├── testdb.sh                              # tool_testdb_prepare()
│       ├── frontend.sh                            # tool_frontend_build_admin(), tool_frontend_build_storefront()
│       └── plugin.sh                              # tool_plugin_create(), tool_plugin_setup()
│
└── skills/
    └── dev-environment-bootstrapping/
        └── SKILL.md                               # 5-phase bootstrapping orchestration skill
```

## Architecture

### Config Strategy

The `lifecycle-tooling` server uses `CONFIG_PREFIX="php-tooling"`, which means it reads the same `.mcp-php-tooling.json` config that `dev-tooling`'s PHP server reads. This is intentional: users who already have `dev-tooling` configured get automatic environment resolution in lifecycle tools without any additional setup.

Resolution priority (highest to lowest):

1. `.mcp-php-tooling.json` (any config search location) — `environment`, `docker_service`, `compose_file` read from config
2. Tool call arguments — explicit `environment`, `docker_service`, `compose_file` passed by caller
3. Default — `native` environment, project root as workdir

When a config file is present, tool call arguments for environment settings are silently ignored. The skill handles this by detecting the config file and omitting env args from MCP calls when found.

### Environment Resolution Pattern (`resolve_lifecycle_env`)

Each tool lib file calls `resolve_lifecycle_env` from `lib/resolve_env.sh` before building its command. This function:

1. Calls `load_config` (from shared `config.sh`) to read and merge all config files found in the discovery search path
2. If config has `environment` set, exports `ENVIRONMENT`, `DOCKER_SERVICE`, `COMPOSE_FILE` from config
3. If no config environment, falls back to function arguments
4. Sets `WORKDIR` to the config `cwd` if present, or the process cwd

The result: tools never see "config wins but arg was passed" conflicts — the resolution is centralised and consistent.

### Tool Dispatch Convention

Tools in `tools.json` map to bash functions with `tool_` prefix, sourced from `lib/*.sh`:

```bash
# In server.sh
source "${SERVER_DIR}/lib/dependencies.sh"
source "${SERVER_DIR}/lib/database.sh"
# ...

# Dispatch via mcpserver_core.sh
# tools.json "name": "install_dependencies" → tool_install_dependencies()
```

`mcpserver_core.sh` (shared) routes JSON-RPC `tools/call` requests to functions named `tool_<tool_name>`, where underscores in the tool name map directly to underscores in the function name.

### Hook Flow

```
SessionStart:
  session-start.sh
    → reads hooks/prompts/mcp-tool-directives.md
    → checks enforce_mcp_tools in .mcp-php-tooling.json
    → outputs JSON additionalContext with directive text (or empty if enforcement disabled)

PreToolUse (Bash matcher):
  check-lifecycle-tools.sh
    → parse_hook_input() (from lib/common.sh)
    → load_mcp_config("php-tooling") — reads enforce_mcp_tools flag
    → pattern-matches COMMAND against blocked bash patterns
    → block_tool() outputs JSON decision + message (exit 2) or exit 0
```

Both hooks share `lib/common.sh` which provides `parse_hook_input()`, `load_mcp_config()`, and `block_tool()`.

### Shared Templates Boundary

`shared/` contains four files that are byte-identical to templates in the repository's `templates/mcp-shared/` directory. A sync rule at `.claude/rules/template-sync.md` declares these files as template derivatives. Edits to shared framework behavior must be applied to the templates and then synced to all consumers (dev-tooling and shopware-env). Never edit `shared/*.sh` directly for behavior changes; edit the template and sync.

The hooks `lib/common.sh` is derived from `templates/hooks-shared/common.sh`. Same sync rule applies.

## Tool Reference

| Tool                       | Wrapped Command(s)                                                                                              |
|----------------------------|-----------------------------------------------------------------------------------------------------------------|
| `install_dependencies`     | `composer install` (or `composer update` with `update=true`), `composer init:js` (admin + storefront npm via composer script; falls back to `npm install`/`clean-install` when `update=true`) |
| `database_install`         | `bin/console system:install --drop-database --basic-setup`                                                      |
| `database_reset`           | `bin/console system:install --drop-database --basic-setup` (same as install, different intent)                  |
| `testdb_prepare`           | `bin/console system:install` with test DB flags + migrations                                                    |
| `frontend_build_admin`     | `bundle:dump`, `feature:dump`, `framework:schema:dump`, `entity-schema-types`, `npm build`, `assets:install`    |
| `frontend_build_storefront`| `bundle:dump`, `feature:dump`, npm production build, `theme:compile`, `assets:install`                         |
| `plugin_create`            | `bin/console plugin:create`, `bin/console plugin:refresh`, `bin/console plugin:install --activate`             |
| `plugin_setup`             | `bin/console plugin:refresh`, `bin/console plugin:install --activate`                                           |

All tools accept `environment`, `docker_service`, and `compose_file` arguments that are overridden by `.mcp-php-tooling.json` when present.

## Testing

BATS tests are in `plugin-tests/shopware-env/`:

| Test File               | Coverage                                                                 |
|-------------------------|--------------------------------------------------------------------------|
| `lifecycle_tools.bats`  | Tool command construction for all 8 tools across environments            |
| `config_fallback.bats`  | Config-wins resolution, arg fallback, missing config handling            |
| `session_start.bats`    | SessionStart hook output, enforcement toggle                             |
| `hook_enforcement.bats` | PreToolUse blocking patterns (composer, npm, bin/console commands)       |

Run tests:
```bash
.bats/bats-core/bin/bats plugin-tests/shopware-env/*.bats
```

## Key Navigation Points

| Task                                | File                                         | Key Concepts                                          |
|-------------------------------------|----------------------------------------------|-------------------------------------------------------|
| Add a new lifecycle tool            | `mcp-server-lifecycle/lib/<tool>.sh`         | `tool_<name>()`, `resolve_lifecycle_env()`, `exec_command()` |
| Register new tool schema            | `mcp-server-lifecycle/tools.json`            | JSON Schema Draft 7, `inputSchema`                    |
| Edit SessionStart prompt            | `hooks/prompts/mcp-tool-directives.md`       | Plain markdown, read by `session-start.sh`            |
| Add blocked bash pattern            | `hooks/scripts/check-lifecycle-tools.sh`     | `block_tool()`, grep regex pattern                    |
| Modify shared hook logic            | `hooks/scripts/lib/common.sh`                | `parse_hook_input()`, `load_mcp_config()`, `block_tool()` |
| Disable hook enforcement            | `.mcp-php-tooling.json`                      | `enforce_mcp_tools: false`                            |
| Adjust hook timeout                 | `hooks/hooks.json`                           | `timeout` field (default: 5s)                         |
| Modify config resolution            | `mcp-server-lifecycle/lib/resolve_env.sh`    | `resolve_lifecycle_env()`, config-wins logic          |
| Modify shared framework             | `templates/mcp-shared/` (repo root)          | Edit template, sync to `shared/` — see `.claude/rules/template-sync.md` |
| Modify bootstrapping skill          | `skills/dev-environment-bootstrapping/SKILL.md` | 5-phase flow, user story routing, Phase 5 hard stop |
| Modify server entry point           | `mcp-server-lifecycle/server.sh`             | `CONFIG_PREFIX="php-tooling"`, sourced lib files      |
| Register/change MCP server          | `.mcp.json`                                  | `mcpServers` object, `CLAUDE_PLUGIN_ROOT`             |

## Relationship to dev-tooling

`shopware-env` and `dev-tooling` are independent plugins installed separately. They share:

- The same config file (`.mcp-php-tooling.json`) — shopware-env reads it for environment resolution, dev-tooling reads it for tool configuration
- The same shared framework files (`shared/*.sh`) — byte-identical copies derived from the same templates

They do not share MCP server processes or runtime state. Installing one does not require the other, though the bootstrapping skill's Phase 5 handoff message directs users to install `dev-tooling` after environment setup is complete.

See README for the user-facing integration description.

## External References

- [Bash MCP SDK](https://github.com/muthuishere/mcp-server-bash-sdk) — SDK this server is based on
- [MCP Protocol Specification](https://modelcontextprotocol.io/specification) — JSON-RPC 2.0 protocol details
