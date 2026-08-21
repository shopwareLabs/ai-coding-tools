@README.md

## 🗂️ Directory & File Structure

```
plugins/dev-tooling/
├── README.md                           # User documentation (usage, configuration, troubleshooting)
├── SETUP.md                            # Setup walkthrough consumed by the plugin-setup plugin
├── docs/                               # User-facing documentation
│   ├── configuration.md                # Config files, environments, troubleshooting
│   ├── mcp-enforcement.md              # Hook enforcement, blocked commands, plugin integration
│   ├── lsp.md                          # LSP setup, phpactor limitations, troubleshooting
│   └── reference.md                    # Full tool parameter docs and examples (30 tools across 3 servers)
├── AGENTS.md                           # LLM navigation guide (this file)
├── CLAUDE.md                           # Points to AGENTS.md
├── CHANGELOG.md                        # Version history
├── LICENSE                             # MIT license
├── .mcp.json                           # MCP server registration (php-tooling, js-admin-tooling, js-storefront-tooling)
├── .lsp.json                           # LSP server configuration (phpactor PHP LSP)
│
├── agents/                             # AGENTS (dev-tooling check/fix executor)
│   └── dev-tooling-runner.md           # Lean runner; given targets + checks/fixes, runs them and returns a pass/fail report (haiku)
│
├── hooks/                              # HOOKS (MCP tool enforcement)
│   ├── hooks.json                      # Hook configuration (SessionStart + PreToolUse + PostToolUse)
│   ├── prompts/
│   │   ├── mcp-tool-directives.md      # SessionStart prompt: MCP tool listing and usage rules
│   │   ├── lsp-directives-header.md    # SessionStart prompt: LSP preamble, emitted when an LSP is enabled
│   │   └── lsp-directives-php.md       # SessionStart prompt: phpactor tool listing and usage rules
│   └── scripts/
│       ├── session-start.sh            # SessionStart hook: reads prompt file, checks enforcement, outputs JSON
│       ├── lsp-directives.sh           # SessionStart hook: emits the LSP directives when .lsp-php-tooling.json enables one
│       ├── check-php-tools.sh          # Blocks PHPStan, ECS, PHPUnit, Rector, bin/console bash commands
│       ├── check-js-admin-tools.sh     # Blocks Administration npm/npx commands (ESLint, Stylelint, Prettier, Jest, TSC, Vite)
│       ├── check-js-storefront-tools.sh # Blocks Storefront npm/npx/composer commands (ESLint, Stylelint, Jest, Vitest, ludtwig, Webpack)
│       ├── check-phpstan-baseline.sh   # PostToolUse hook: warns when analyzed paths appear in phpstan-baseline.neon
│       └── lib/
│           └── common.sh               # Shared: parse_hook_input(), load_mcp_config(), block_tool()
│
├── shared/                             # SHARED FRAMEWORK (language-agnostic)
│   ├── mcpserver_core.sh              # JSON-RPC 2.0 protocol handler + validate_tool_arguments()
│   ├── config.sh                      # Config discovery & merging (parameterized via CONFIG_PREFIX)
│   ├── environment.sh                 # Environment detection, PHP & JS command wrapping, argument quoting, path guards, noise filtering
│   ├── scope.sh                       # Scope resolution: resolve_scope(), scope_get_tool_field()
│   ├── docker-compose.sh              # Docker Compose environment: call-time resolution of container/workdir
│   ├── lsp_bootstrap.sh               # LSP entry point: picks phpactor or the null stub from .lsp-php-tooling.json
│   ├── lsp_null.sh                    # LSP null stub used when no LSP is enabled
│   ├── lsp_proxy.py                   # URI-rewriting LSP proxy for container-hosted phpactor
│   └── mcp-js-tooling.schema.json     # JSON Schema for .mcp-js-tooling.json (shared by JS servers)
│
├── lsp-server-php/                     # PHP LSP SERVER (opt-in)
│   ├── lsp.sh                         # Entry point from .lsp.json; sets CONFIG_PREFIX/LSP_DEFAULT_BINARY, sources the bootstrap
│   └── lib/
│       └── phpactor.sh                # Per-LSP launcher: adjusts LSP_BINARY / args for phpactor
│
├── mcp-server-php/                     # PHP TOOLS MCP SERVER
│   ├── server.sh                      # Entry point - sets CONFIG_PREFIX="php-tooling"
│   ├── config.json                    # Server metadata (name="php-tooling")
│   ├── tools.json                     # PHPStan, ECS, PHPUnit, Console, Rector tool schemas
│   ├── mcp-php-tooling.schema.json    # JSON Schema for .mcp-php-tooling.json
│   └── lib/
│       ├── phpstan.sh                 # tool_phpstan_analyze()
│       ├── ecs.sh                     # tool_ecs_check(), tool_ecs_fix()
│       ├── phpunit.sh                 # tool_phpunit_run()
│       ├── phpunit_coverage.sh        # tool_phpunit_coverage_gaps()
│       ├── rector.sh                  # tool_rector_check(), tool_rector_fix()
│       └── console.sh                 # tool_console_run(), tool_console_list()
│
├── mcp-server-js-admin/                   # ADMIN JS TOOLS MCP SERVER
│   ├── server.sh                      # Entry point - sets CONFIG_PREFIX="js-tooling" (shared)
│   ├── config.json                    # Server metadata (name="js-admin-tooling")
│   ├── tools.json                     # ESLint, Stylelint, Prettier, Jest, TSC, lint_all, lint_twig, unit_setup, Vite tools
│   └── lib/
│       ├── eslint.sh                  # tool_eslint_check(), tool_eslint_fix()
│       ├── stylelint.sh               # tool_stylelint_check(), tool_stylelint_fix()
│       ├── prettier.sh                # tool_prettier_check(), tool_prettier_fix()
│       ├── jest.sh                    # tool_jest_run()
│       ├── tsc.sh                     # tool_tsc_check()
│       ├── lint-all.sh                # tool_lint_all(), tool_lint_twig(), tool_unit_setup()
│       └── build.sh                   # tool_vite_build()
│
└── mcp-server-js-storefront/              # STOREFRONT JS TOOLS MCP SERVER
    ├── server.sh                      # Entry point - sets CONFIG_PREFIX="js-tooling" (shared)
    ├── config.json                    # Server metadata (name="js-storefront-tooling")
    ├── tools.json                     # ESLint, Stylelint, Jest, Vitest, ludtwig, Webpack tools
    └── lib/
        ├── eslint.sh                  # tool_eslint_check(), tool_eslint_fix() — routes paths to eslint:app / eslint:components
        ├── stylelint.sh               # tool_stylelint_check(), tool_stylelint_fix()
        ├── jest.sh                    # tool_jest_run() — app/storefront package suite only
        ├── vitest.sh                  # tool_vitest_run() — views/components component suite
        ├── ludtwig.sh                 # tool_ludtwig_check(), tool_ludtwig_fix()
        └── build.sh                   # tool_webpack_build()
```

## 🧱 Component Overview

This plugin provides:
- **Three MCP Servers** via `.mcp.json`:
  - `php-tooling` - PHP linting/testing tools
  - `js-admin-tooling` - Administration JavaScript tools (Vue 3/Vite)
  - `js-storefront-tooling` - Storefront JavaScript tools (vanilla JS/Webpack): `eslint_check`, `eslint_fix`, `stylelint_check`, `stylelint_fix`, `jest_run`, `vitest_run`, `ludtwig_check`, `ludtwig_fix`, `webpack_build`
- **PHP LSP (phpactor, opt-in)** via `.lsp.json`:
  - Active PHP code discovery: document symbols, hover, go-to-definition, references
  - Runs natively on the host or inside a container (docker, docker-compose, vagrant, ddev) via the URI-rewriting proxy
  - Enabled via `.lsp-php-tooling.json` with `enabled: true`; falls back to the null stub otherwise
  - Requires the `phpactor` binary available where the LSP runs (host or container)
- **Subagent** via `agents/`:
  - `dev-tooling-runner` — executor for dev-tooling checks (and rule-driven fixes); run it to keep verbose output out of the conversation and get back a lean pass/fail report (runs on haiku); see [Agents](#agents)
- **SessionStart Hook** via `hooks/hooks.json`:
  - Injects MCP tool directives into conversation context at session start
  - Prompt maintained in `hooks/prompts/mcp-tool-directives.md`
  - Outputs JSON `additionalContext` format
  - Also steers the active session to delegate heavy dev-tool runs to `dev-tooling-runner`
- **PreToolUse Hooks** via `hooks/hooks.json`:
  - Blocks bash commands that should use MCP tools instead
  - PHP hook: blocks PHPStan, ECS, PHPUnit, Rector, bin/console
  - Admin JS hook: blocks ESLint, Stylelint, Prettier, Jest, TSC, lint_all/lint_twig, Vite commands
  - Storefront JS hook: blocks ESLint, Stylelint, Jest, Vitest, ludtwig, Webpack commands
- **PostToolUse Hook** via `hooks/hooks.json`:
  - `check-phpstan-baseline.sh` warns when a targeted `phpstan_analyze` run covers paths listed in `phpstan-baseline.neon` (or `.php`)
  - Ignores `enforce_mcp_tools` and always runs
- The SessionStart and PreToolUse hook types are configurable via `enforce_mcp_tools: false` in config files
- **Shared Framework** in `shared/` - reusable across all servers

## 🤖 Agents

### dev-tooling-runner

**Purpose**: Executor for Shopware dev-tooling checks and rule-driven fixes. Given explicit targets + check/fix-kinds, it maps each target to its toolchain by path, runs the matching MCP tools, and returns a lean (~1–2k token) pass/fail report. Run it (via the Agent tool or `claude --agent dev-tooling-runner`) to keep verbose tool output out of the conversation. Unlike the `test-writing` agents, it is meant to be invoked directly.

**Scope ownership**: none. It acts only on the targets and checks it is given — no git diffing, file discovery, or blast-radius guessing — and never decides on its own to fix something it was told only to check. Deciding what to check (paths + any affected tests) and whether to apply a fix is the caller's job.

**Bounded mutation, not freeform editing**: the three dev-tooling servers are granted by wildcard, so the rule-driven fixers (`ecs_fix`, `rector_fix`, `eslint_fix`, `stylelint_fix`, `prettier_fix`, `ludtwig_fix`) are available — the agent does not choose *what* changes, the linter ruleset does. It has no `Edit`/`Write`, so it cannot freeform-edit; its only file changes come from those deterministic fixers. `console_run`, `console_list`, and `unit_setup` are subtracted via `disallowedTools` (applied before `tools`, so the wildcard cannot re-add them). No `Bash`/`Glob`/`Grep` — scope discovery is the caller's job; `Read` is the only non-MCP tool, for quoting a flagged line.

**Model**: Haiku | **Mutation boundary**: enforced via `tools` + `disallowedTools` — no `Edit`/`Write`, no `console_*` / `unit_setup` (`permissionMode` is ignored for plugin subagents)

**Tools**: `Read`, `mcp__plugin_dev-tooling_php-tooling__*`, `mcp__plugin_dev-tooling_js-admin-tooling__*`, `mcp__plugin_dev-tooling_js-storefront-tooling__*` (`console_run` / `console_list` / `unit_setup` removed via `disallowedTools`)

## 🏗️ Architecture

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

Both handle environment-specific execution (native/docker/docker-compose/vagrant/ddev).

## 🧭 Key Navigation Points

| Task | Primary File | Secondary File | Key Concepts |
|------|--------------|----------------|--------------|
| Add PHP tool | `mcp-server-php/lib/<tool>.sh` | `mcp-server-php/tools.json` | `tool_*()`, `exec_command()` |
| Add Admin JS tool | `mcp-server-js-admin/lib/<tool>.sh` | `mcp-server-js-admin/tools.json` | `tool_*()`, `exec_npm_command()` |
| Add Storefront JS tool | `mcp-server-js-storefront/lib/<tool>.sh` | `mcp-server-js-storefront/tools.json` | `tool_*()`, `exec_npm_command()` |
| Edit SessionStart prompt | `hooks/prompts/mcp-tool-directives.md` | `hooks/scripts/session-start.sh` | Plain markdown, read by script |
| Edit dev-tooling runner agent | `agents/dev-tooling-runner.md` | - | `tools`/`disallowedTools` (no Edit/Write, no console_*/unit_setup), check/fix-kind→tool table, report template |
| Add blocked PHP command | `hooks/scripts/check-php-tools.sh` | - | `block_tool()`, grep pattern |
| Add blocked Admin JS command | `hooks/scripts/check-js-admin-tools.sh` | - | `block_tool()`, `is_admin_context()` |
| Add blocked Storefront JS command | `hooks/scripts/check-js-storefront-tools.sh` | - | `block_tool()`, `is_storefront_context()` |
| Modify shared hook logic | `hooks/scripts/lib/common.sh` | - | `parse_hook_input()`, `load_mcp_config()`, `block_tool()` |
| Disable hook enforcement | `.mcp-*-tooling.json` | - | `enforce_mcp_tools: false` |
| Adjust hook timeout | `hooks/hooks.json` | - | `timeout` field (default: 5s) |
| Add config location | `shared/config.sh` | - | `CONFIG_LOCATIONS` array |
| Add environment type | `shared/environment.sh` | - | `wrap_command()`, `wrap_npm_command()` |
| Configure docker-compose | `shared/docker-compose.sh` | `shared/environment.sh` | `_compose_*()`, call-time resolution |
| Add noise filter pattern | `shared/environment.sh` | - | `ENV_NOISE_PATTERNS` array, `_filter_env_noise()` |
| Modify protocol | `shared/mcpserver_core.sh` | - | `process_request()`, `handle_*()` |
| Update tool schemas | `mcp-server-*/tools.json` | - | JSON Schema Draft 7 |
| Register new server | `.mcp.json` | - | `mcpServers` object |

## ✏️ When to Modify What

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
1. For complex types (like `docker-compose`), create a separate module in `shared/`
2. Edit `shared/environment.sh` — add case in `_set_workdir_from_config()`, `wrap_command()`, `wrap_npm_command()`
3. Document in README.md

**Adding new config location** (e.g., `.github/`):
1. Add to `CONFIG_LOCATIONS` array in `shared/config.sh`
2. Update README.md

**Adding a third language** (e.g., Python):
1. Create `mcp-server-python/` with same structure
2. Set `CONFIG_PREFIX="python-tooling"` in server.sh
3. Add to `.mcp.json` as `python-tooling` server
4. Optionally add `wrap_python_command()` to environment.sh

## 🔗 Integration with Other Plugins

MCP tool names follow pattern: `mcp__<server-name>__<tool_name>`

```yaml
# PHP tools
tools: mcp__php-tooling__phpstan_analyze, mcp__php-tooling__ecs_check

# Admin JS tools
tools: mcp__js-admin-tooling__eslint_check, mcp__js-admin-tooling__jest_run

# Storefront JS tools
tools: mcp__js-storefront-tooling__eslint_check, mcp__js-storefront-tooling__webpack_build
```

## 🧪 Testing

BATS tests are in `plugin-tests/dev-tooling/`:

| Test File                        | Coverage                                                                          |
|----------------------------------|-------------------------------------------------------------------------------------|
| `php_tools.bats`                 | PHP tool blocking (PHPStan, ECS, PHPUnit, Rector, bin/console)                    |
| `js_admin_tools.bats`            | Admin JS tool blocking (ESLint, Stylelint, Prettier, Jest, TSC, Vite)             |
| `js_storefront_tools.bats`       | Storefront JS tool blocking (ESLint, Stylelint, Jest, Vitest, ludtwig, Webpack)   |
| `phpstan_baseline.bats`          | PostToolUse baseline-overlap warning                                              |
| `session_start.bats`             | SessionStart directive output and enforcement flags                               |
| `environment.bats`               | Environment wrapping, argument quoting, `parse_paths_json`, path guards           |
| `docker_compose.bats`            | Docker Compose call-time container/workdir resolution                             |
| `extra_log_file.bats`            | Extra log file configuration and dual-write log()                                 |
| `mcp_tool_console.bats`          | Console tool command construction                                                 |
| `mcp_tool_ecs.bats`              | ECS tool command construction                                                     |
| `mcp_tool_rector.bats`           | Rector tool command construction                                                  |
| `mcp_tool_js_admin.bats`         | Admin JS MCP tool command construction                                            |
| `mcp_tool_js_storefront.bats`    | Storefront JS MCP tool command construction (ESLint routing, Jest, Vitest, ludtwig) |
| `mcp_tool_phpstan.bats`          | PHPStan tool command construction                                                 |
| `mcp_tool_phpunit.bats`          | PHPUnit tool command construction (coverage, config, drivers)                     |
| `mcp_tool_phpunit_coverage.bats` | PHPUnit coverage gap parsing (clover XML, filtering, ranges)                      |
| `scope_resolution.bats`          | `resolve_scope()` and scope field lookup                                          |
| `scope_wrap.bats`                | Scope-aware command wrapping per environment                                      |
| `scope_php_tools.bats`           | Scope handling in the PHP MCP tools                                               |
| `scope_js_tools.bats`            | Scope handling in the JS MCP tools                                                |
| `scope_session_start.bats`       | Scope surfacing in the SessionStart output                                        |
| `config_lsp_prefix.bats`         | `.lsp-` config prefix discovery                                                   |
| `lsp_bootstrap.bats`             | LSP bootstrap: binary preflight, direct vs proxy dispatch                         |
| `lsp_null.bats`                  | LSP null stub protocol behavior                                                   |

Run tests:
```bash
.bats/bats-core/bin/bats plugin-tests/dev-tooling/*.bats
```

## 📖 External References

- [Bash MCP SDK](https://github.com/muthuishere/mcp-server-bash-sdk) - SDK this server is based on
- [MCP Protocol Specification](https://modelcontextprotocol.io/specification) - JSON-RPC 2.0 protocol details
