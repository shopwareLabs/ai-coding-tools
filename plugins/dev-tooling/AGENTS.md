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
│   └── reference.md                    # Full tool parameter docs and examples
├── AGENTS.md                           # LLM navigation guide (this file)
├── CLAUDE.md                           # Points to AGENTS.md
├── CHANGELOG.md                        # Version history
├── .claude-plugin/                     # Claude Code plugin manifest (plugin.json: name, version, metadata)
├── .codex-plugin/                      # Codex plugin manifest (plugin.json: same name and version; mcpServers points at codex.mcp.json)
├── .mcp.json                           # MCP server registration for Claude Code (php-tooling, js-admin-tooling, js-storefront-tooling)
├── codex.mcp.json                      # MCP server registration for Codex: same three servers, each launched with `cwd` "." relative to the plugin root
├── .lsp.json                           # LSP server configuration (phpactor PHP LSP; Claude Code only)
│
├── agents/                             # AGENTS (dev-tooling check/fix executor)
│   └── dev-tooling-runner.md           # Lean runner; given targets + checks/fixes, runs them and returns a pass/fail report (haiku)
│
├── hooks/                              # HOOKS (MCP tool enforcement)
│   ├── hooks.json                      # Hook configuration (SessionStart + PreToolUse + PostToolUse)
│   ├── prompts/
│   │   ├── mcp-tool-directives.md      # SessionStart prompt for Claude Code: MCP tool listing and usage rules
│   │   ├── mcp-tool-directives-codex.md # SessionStart prompt for Codex: the same tool listing, without the runner agent and EnterWorktree/ExitWorktree guidance
│   │   ├── lsp-directives-header.md    # SessionStart prompt: LSP preamble, emitted when an LSP is enabled
│   │   └── lsp-directives-php.md       # SessionStart prompt: phpactor tool listing and usage rules
│   └── scripts/
│       ├── session-start.sh            # SessionStart hook: picks the prompt file by host, checks enforcement, outputs JSON
│       ├── lsp-directives.sh           # SessionStart hook: emits the LSP directives when .lsp-php-tooling.json enables one
│       ├── check-php-tools.sh          # Blocks PHPStan, ECS, PHPUnit, Rector, bin/console bash commands
│       ├── check-js-admin-tools.sh     # Blocks Administration npm/npx commands (ESLint, Stylelint, Prettier, Jest, TSC, Vite)
│       ├── check-js-storefront-tools.sh # Blocks Storefront npm/npx/composer commands (ESLint, Stylelint, Jest, Vitest, ludtwig, Webpack)
│       ├── check-phpstan-baseline.sh   # PostToolUse hook: warns when analyzed paths appear in phpstan-baseline.neon
│       ├── worktree-directives.sh      # PostToolUse hook on EnterWorktree|ExitWorktree: set_project_root reminder; on enter also the repair command for an absolute gitdir pointer and the worktree.baseRef warning
│       └── lib/
│           └── common.sh               # Shared (template-synced from templates/hooks-shared/common.sh): parse_hook_input(), load_mcp_config(), resolve_project_dir(), block_tool()
│
├── shared/                             # SHARED FRAMEWORK (language-agnostic)
│   ├── mcpserver_core.sh              # JSON-RPC 2.0 protocol handler + validate_tool_arguments()
│   ├── config.sh                      # Config discovery & merging (parameterized via CONFIG_PREFIX)
│   ├── launch.sh                      # Launch mode: bound, or unbound when the host started the server in this plugin's own directory (dev-tooling-owned, not templated)
│   ├── environment.sh                 # Environment detection, PHP & JS command wrapping, argument quoting, path guards, environment-side path mapping, noise filtering
│   ├── worktree.sh                    # Per-call root resolution and worktree validation: worktree_enter(), set_project_root, cwd (dev-tooling-owned, not templated)
│   ├── server_run.sh                  # Shared server tail: run_mcp_server() call and why it is not isolated in a subshell (dev-tooling-owned, not templated)
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
│       ├── console.sh                 # tool_console_run(), tool_console_list()
│       └── prepare.sh                 # tool_worktree_prepare() — composer install for a fresh worktree
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
│       ├── build.sh                   # tool_vite_build()
│       └── prepare.sh                 # tool_worktree_prepare() — npm ci for a fresh worktree
│
└── mcp-server-js-storefront/              # STOREFRONT JS TOOLS MCP SERVER
    ├── server.sh                      # Entry point - sets CONFIG_PREFIX="js-tooling" (shared)
    ├── config.json                    # Server metadata (name="js-storefront-tooling")
    ├── tools.json                     # ESLint, Stylelint, Jest, Vitest, ludtwig, Webpack tools
    └── lib/
        ├── eslint.sh                  # tool_eslint_check(), tool_eslint_fix() — routes paths to the app tree / the components tree
        ├── stylelint.sh               # tool_stylelint_check(), tool_stylelint_fix()
        ├── jest.sh                    # tool_jest_run() — app/storefront package suite only
        ├── vitest.sh                  # tool_vitest_run() — views/components component suite
        ├── ludtwig.sh                 # tool_ludtwig_check(), tool_ludtwig_fix()
        ├── build.sh                   # tool_webpack_build()
        └── prepare.sh                 # tool_worktree_prepare() — npm ci for a fresh worktree
```

## 🧱 Component Overview

This plugin provides:
- **Three MCP Servers**, registered in `.mcp.json` for Claude Code and in `codex.mcp.json` for Codex — the same three servers, but the Codex file launches each one with `cwd` `.`, so it starts unbound against the plugin directory:
  - `php-tooling` - PHP linting/testing tools
  - `js-admin-tooling` - Administration JavaScript tools (Vue 3/Vite)
  - `js-storefront-tooling` - Storefront JavaScript tools (vanilla JS/Webpack): `eslint_check`, `eslint_fix`, `stylelint_check`, `stylelint_fix`, `jest_run`, `vitest_run`, `ludtwig_check`, `ludtwig_fix`, `webpack_build`, `worktree_prepare`
- **Codex packaging**: `.codex-plugin/plugin.json` (same name, version and other shared metadata as the Claude Code manifest, but a description and keywords without the Claude Code only components; `mcpServers` pointing at `codex.mcp.json` and no `hooks` field, so Codex loads `hooks/hooks.json` itself) plus, at the repository root, `.agents/plugins/marketplace.json`, which lists `dev-tooling` as an available local plugin for `codex plugin marketplace add`. Codex reads that marketplace before `.claude-plugin/marketplace.json` and resolves a plugin's `.codex-plugin/plugin.json` before `.claude-plugin/plugin.json`. `codex.mcp.json` repeats the three servers with a relative `command` and `cwd` `.`, because Codex does not expand `${CLAUDE_PLUGIN_ROOT}`, and a Codex MCP server receives only a small default environment (`HOME`, `PATH`, `SHELL`, `USER`, `TMPDIR` and a few more) plus the variables its entry declares — so each entry lists what to forward: `PROJECT_ROOT`, the server's `MCP_*_TOOLING_CONFIG` override, `MCP_LOG_STDERR`, `MCP_EXTRA_LOG_FILE`, the `DOCKER_*` set, the docker compose selectors `COMPOSE_PROJECT_NAME`, `COMPOSE_FILE`, `COMPOSE_PROFILES` and `COMPOSE_PATH_SEPARATOR`, the Vagrant settings `VAGRANT_CWD`, `VAGRANT_HOME`, `VAGRANT_DOTFILE_PATH`, `VAGRANT_VAGRANTFILE` and `VAGRANT_DEFAULT_PROVIDER`, and `SSH_AUTH_SOCK`.
- **PHP LSP (phpactor, opt-in)** via `.lsp.json` (Claude Code only — Codex reads no `.lsp.json`):
  - Active PHP code discovery: document symbols, hover, go-to-definition, references
  - Runs natively on the host or inside a container (docker, docker-compose, vagrant, ddev) via the URI-rewriting proxy
  - Enabled via `.lsp-php-tooling.json` with `enabled: true`; falls back to the null stub otherwise
  - Requires the `phpactor` binary available where the LSP runs (host or container)
- **Subagent** via `agents/` (Claude Code only — the Codex plugin manifest has no agents field):
  - `dev-tooling-runner` — executor for dev-tooling checks (and rule-driven fixes); run it to keep verbose output out of the conversation and get back a lean pass/fail report (runs on haiku); see [Agents](#agents)
- **SessionStart Hooks** via `hooks/hooks.json`:
  - `session-start.sh` injects MCP tool directives into conversation context at session start; prompt maintained in `hooks/prompts/mcp-tool-directives.md` when `CLAUDE_PROJECT_DIR` is set and in `hooks/prompts/mcp-tool-directives-codex.md` when it is not; outputs JSON `additionalContext` format; the Claude Code prompt also steers the active session to delegate heavy dev-tool runs to `dev-tooling-runner`, the Codex prompt does not. When `enforce_mcp_tools` is off but the host names the session directory only in the hook input's `.cwd` (Codex sets no `CLAUDE_PROJECT_DIR`), it still injects a short hint naming the directory and telling the model to call `set_project_root` on a server that reports no project root
  - `lsp-directives.sh` injects LSP usage directives, only when `.lsp-php-tooling.json` enables a language server (Claude Code only)
- **PreToolUse Hooks** via `hooks/hooks.json`:
  - Blocks bash commands that should use MCP tools instead; the block message names the tool and its server, e.g. ``Use `phpstan_analyze` on the `php-tooling` MCP server instead!``, so it reads the same on Claude Code and Codex, which spell the tool name differently
  - PHP hook: blocks PHPStan, ECS, PHPUnit, Rector, bin/console
  - Admin JS hook: blocks ESLint, Stylelint, Prettier, Jest, TSC, lint_all/lint_twig, Vite commands
  - Storefront JS hook: blocks ESLint, Stylelint, Jest, Vitest, ludtwig, Webpack commands
- **PostToolUse Hooks** via `hooks/hooks.json`:
  - `check-phpstan-baseline.sh` warns when a targeted `phpstan_analyze` run covers paths listed in `phpstan-baseline.neon` (or `.php`). Its matcher carries both host spellings of the tool name — `mcp__plugin_dev-tooling_php-tooling__phpstan_analyze` on Claude Code and `mcp__php_tooling__phpstan_analyze` on Codex, which replaces the dashes in the server name
  - `worktree-directives.sh` fires on `EnterWorktree`/`ExitWorktree` and reminds the session to call `set_project_root` on all three servers; on enter it also names the repair command when the worktree's `.git` file carries an absolute gitdir pointer, and warns that a native worktree branches from the default remote branch unless `worktree.baseRef` is `head` (Claude Code only — those tools do not exist on Codex)
  - Both ignore `enforce_mcp_tools` and always run
- `session-start.sh` and every PreToolUse hook are configurable via `enforce_mcp_tools: false` in config files; `lsp-directives.sh` and both PostToolUse hooks read no such flag
- **Shared Framework** in `shared/` - reusable across all servers

## 🤖 Agents

### dev-tooling-runner

**Purpose**: Executor for Shopware dev-tooling checks and rule-driven fixes. Given explicit targets + check/fix-kinds, it maps each target to its toolchain by path, runs the matching MCP tools, and returns a lean (~1–2k token) pass/fail report. Run it (via the Agent tool or `claude --agent dev-tooling-runner`) to keep verbose tool output out of the conversation. Unlike the `test-writing` agents, it is meant to be invoked directly.

**Scope ownership**: none. It acts only on the targets and checks it is given — no git diffing, file discovery, or blast-radius guessing — and never decides on its own to fix something it was told only to check. Deciding what to check (paths + any affected tests) and whether to apply a fix is the caller's job.

**Bounded mutation, not freeform editing**: the three dev-tooling servers are granted by wildcard, so the rule-driven fixers (`ecs_fix`, `rector_fix`, `eslint_fix`, `stylelint_fix`, `prettier_fix`, `ludtwig_fix`) are available — the agent does not choose *what* changes, the linter ruleset does. It has no `Edit`/`Write`, so it cannot freeform-edit; its only file changes come from those deterministic fixers. `console_run`, `console_list`, `unit_setup`, `worktree_prepare` (on all three servers), and `set_project_root` (on all three servers) are subtracted via `disallowedTools` (applied before `tools`, so the wildcard cannot re-add them). `worktree_prepare` is subtracted because it rewrites `vendor/`/`node_modules` — a setup mutation outside the fixer boundary, and one the dependency refusals would otherwise steer the agent into. `set_project_root` is subtracted because its value is sticky and outlives the call that set it — an agent call would otherwise redirect every later tool call in the session that spawned it; the agent still reaches a worktree by passing `project_root` on the individual call. No `Bash`/`Glob`/`Grep` — scope discovery is the caller's job; `Read` is the only non-MCP tool, for quoting a flagged line.

**Model**: Haiku | **Mutation boundary**: enforced via `tools` + `disallowedTools` — no `Edit`/`Write`, no `console_*` / `unit_setup` / `worktree_prepare` / `set_project_root` (`permissionMode` is ignored for plugin subagents)

**Tools**: `Read`, `mcp__plugin_dev-tooling_php-tooling__*`, `mcp__plugin_dev-tooling_js-admin-tooling__*`, `mcp__plugin_dev-tooling_js-storefront-tooling__*` (`console_run` / `console_list` / `unit_setup` / `worktree_prepare` / `set_project_root` removed via `disallowedTools`)

## 🏗️ Architecture

### Shared Framework Pattern

All MCP servers source shared framework files:
```bash
source "${SHARED_DIR}/mcpserver_core.sh"  # JSON-RPC protocol
source "${SHARED_DIR}/config.sh"           # Config discovery
source "${SHARED_DIR}/launch.sh"           # Launch mode: bound, or unbound in the plugin directory
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
# Admin/Storefront servers - hardcoded npm script names from Shopware package.json.
# Two routes per tool, selected by whether the caller supplied paths: appending
# to the aggregate script only ever widens it (npm appends `--` args to the end
# of the whole script body), so a path-scoped call runs without it.
tool_eslint_check() {
    local args="$1"
    # No paths: aggregate script's own targets stay authoritative.
    local cmd="npm run lint -- ..."  # Admin uses "lint", Storefront uses "lint:js"
    # Paths supplied: the given paths are the ONLY targets. Admin ESLint runs
    # the target-less script "lint:debugging" and refuses when it is unusable.
    # Admin Stylelint and Prettier and both Storefront linters run the
    # package's own binary through `npm exec --no -- <binary> <flags> <paths>`,
    # with the flags of the aggregate script's body, and refuse when
    # node_modules/.bin/<binary> is missing. The Storefront components tree
    # runs `npm exec --no -c "cd ../.. && eslint ..."`, as "lint:js" does.
    # Stylelint and Prettier get a directory path as the quoted pattern
    # `<dir>/**/*.<extensions>`, so only the extensions the aggregate lints
    # are read; under ddev on a worktree they refuse directory and glob paths.
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
| Edit SessionStart prompt | `hooks/prompts/mcp-tool-directives.md` (Claude Code), `hooks/prompts/mcp-tool-directives-codex.md` (Codex) | `hooks/scripts/session-start.sh` | Plain markdown, read by script; the prompt is picked by whether `CLAUDE_PROJECT_DIR` is set |
| Edit dev-tooling runner agent | `agents/dev-tooling-runner.md` | - | `tools`/`disallowedTools` (no Edit/Write, no console_*/unit_setup/worktree_prepare/set_project_root), check/fix-kind→tool table, report template |
| Add blocked PHP command | `hooks/scripts/check-php-tools.sh` | - | `block_tool()`, grep pattern |
| Add blocked Admin JS command | `hooks/scripts/check-js-admin-tools.sh` | - | `block_tool()`, `is_admin_context()` |
| Add blocked Storefront JS command | `hooks/scripts/check-js-storefront-tools.sh` | - | `block_tool()`, `is_storefront_context()` |
| Modify shared hook logic | `templates/hooks-shared/common.sh` (edit template, sync per `.claude/rules/template-sync.md`) | - | `parse_hook_input()`, `load_mcp_config()`, `resolve_project_dir()`, `block_tool(server, description, tool...)` |
| Disable hook enforcement | `.mcp-*-tooling.json` | - | `enforce_mcp_tools: false` |
| Adjust hook timeout | `hooks/hooks.json` | - | `timeout` field (default: 5s) |
| Add config location | `templates/mcp-shared/config.sh` (edit template, sync per `.claude/rules/template-sync.md`) | - | `CONFIG_LOCATIONS` array |
| Add environment type | `templates/mcp-shared/environment.sh` (edit template, sync per `.claude/rules/template-sync.md`) | - | `wrap_command()`, `wrap_npm_command()` |
| Configure docker-compose | `templates/mcp-shared/docker-compose.sh` (edit template, sync per `.claude/rules/template-sync.md`) | `templates/mcp-shared/environment.sh` | `_compose_*()`, call-time resolution |
| Add noise filter pattern | `templates/mcp-shared/environment.sh` (edit template, sync per `.claude/rules/template-sync.md`) | - | `ENV_NOISE_PATTERNS` array, `_filter_env_noise()` |
| Modify protocol | upstream `shopwareLabs/bash-mcp-sdk` (release pinned in `.mcp-sdk.lock`; never edit `shared/mcpserver_core.sh` in place) | - | `process_request()`, `handle_*()` |
| Update tool schemas | `mcp-server-*/tools.json` | - | JSON Schema Draft 7 |
| Register new server | `.mcp.json` for Claude Code; `codex.mcp.json` for Codex | - | `mcpServers` object; the Codex file needs a relative `command` and `cwd` `.` |
| Package the plugin for Codex | `.codex-plugin/plugin.json` | `codex.mcp.json`, repo `.agents/plugins/marketplace.json` | name, version and shared metadata equal to `.claude-plugin/plugin.json`, description and keywords differing (equality of the rest asserted by `codex_manifest.bats`, which also asserts the description and keywords omit the LSP), no `hooks` field |
| Change launch or bind behavior | `shared/launch.sh` | `shared/worktree.sh` (`worktree_launch_hydrate`, `_worktree_launch_bind`) | `LAUNCH_MODE`, the `launch` record in the state file, `worktree_state_cleanup` removing the merged config |

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

On Claude Code, a plugin-provided MCP server's tools are named `mcp__plugin_<plugin>_<server>__<tool_name>`. On Codex they keep the plain MCP form `mcp__<server>__<tool_name>`, with every character outside `[A-Za-z0-9_]` in the server name replaced by `_` — so `php-tooling` becomes `php_tooling`.

```yaml
# PHP tools
tools: mcp__plugin_dev-tooling_php-tooling__phpstan_analyze, mcp__plugin_dev-tooling_php-tooling__ecs_check

# Admin JS tools
tools: mcp__plugin_dev-tooling_js-admin-tooling__eslint_check, mcp__plugin_dev-tooling_js-admin-tooling__jest_run

# Storefront JS tools
tools: mcp__plugin_dev-tooling_js-storefront-tooling__eslint_check, mcp__plugin_dev-tooling_js-storefront-tooling__webpack_build
```

## 🧪 Testing

This plugin's own suites are in `plugin-tests/dev-tooling/`:

| Test File                        | Coverage                                                                            |
|----------------------------------|-------------------------------------------------------------------------------------|
| `php_tools.bats`                 | PHP tool blocking (PHPStan, ECS, PHPUnit, Rector, bin/console)                      |
| `js_admin_tools.bats`            | Admin JS tool blocking (ESLint, Stylelint, Prettier, Jest, TSC, Vite)               |
| `js_storefront_tools.bats`       | Storefront JS tool blocking (ESLint, Stylelint, Jest, Vitest, ludtwig, Webpack)     |
| `phpstan_baseline.bats`          | PostToolUse baseline-overlap warning                                                |
| `session_start.bats`             | SessionStart directive output and enforcement flags                                 |
| `mcp_tool_console.bats`          | Console tool command construction                                                   |
| `mcp_tool_ecs.bats`              | ECS tool command construction                                                       |
| `mcp_tool_rector.bats`           | Rector tool command construction                                                    |
| `mcp_tool_js_admin.bats`         | Admin JS MCP tool command construction, and the Stylelint and Prettier commands and the local-binary probe executed through the native, docker, docker-compose, vagrant and ddev wrappers |
| `mcp_tool_js_storefront.bats`    | Storefront JS MCP tool command construction (ESLint routing, Jest, Vitest, ludtwig), and the ESLint and Stylelint commands and the local-binary probe executed through the native, docker, docker-compose, vagrant and ddev wrappers |
| `mcp_tool_phpstan.bats`          | PHPStan tool command construction                                                   |
| `mcp_tool_phpunit.bats`          | PHPUnit tool command construction (coverage, config, drivers)                       |
| `mcp_tool_phpunit_coverage.bats` | PHPUnit coverage gap parsing (clover XML, filtering, ranges)                        |
| `tool_schema.bats`               | Every server's `tools.json` refuses an undeclared parameter                          |
| `scope_resolution.bats`          | `resolve_scope()` and scope field lookup                                            |
| `scope_php_tools.bats`           | Scope handling in the PHP MCP tools                                                 |
| `scope_js_tools.bats`            | Scope handling in the JS MCP tools                                                  |
| `scope_session_start.bats`       | Scope surfacing in the SessionStart output                                          |
| `lsp_bootstrap.bats`             | LSP bootstrap: binary preflight, direct vs proxy dispatch                           |
| `lsp_null.bats`                  | LSP null stub protocol behavior                                                     |
| `worktree_resolution.bats`       | Worktree resolution, identity, linkage, charset, probe, config, deps, path guard   |
| `worktree_state.bats`            | State file: sticky read-back, reset, a removed root, probe cache, atomic writes    |
| `worktree_hook.bats`             | `worktree-directives.sh`: the `PostToolUse` JSON envelope, enter/exit directive text read out of the decoded `additionalContext`, the `.cwd` fallback, the no-path diagnostic, exit 0 on malformed input |
| `worktree_php_tools.bats`        | `phpunit_coverage_gaps`: clover paths relative to the mapped workdir, refused read |
| `worktree_js_tools.bats`         | `project_root` reaching the JS package directory, which the conformance scan does not capture |
| `worktree_conformance.bats`      | Every enumerated `tool_*` function runs in the named worktree and runs nothing against a refused one, with the enumeration reconciled against `tools.json` |
| `codex_launch.bats`              | Launch mode and the bind: a server started in its plugin directory lists tools and refuses every other call, `set_project_root` binds it (exercised under `native`, `docker-compose` and `ddev`) and refuses a bad root, `cwd` reports both states, and a server started in a project directory runs a tool there with no bind |
| `codex_manifest.bats`            | Codex packaging: `.codex-plugin/plugin.json` version and shared-metadata equality with the Claude Code manifest and a description and keywords free of the LSP, `codex.mcp.json` server launch and forwarded variables, the `.agents/plugins/marketplace.json` entry, and that both directive prompts (Claude Code and Codex) list each server's `tools.json` tools and name a server at every tool mention; the Codex prompt carries no runner-agent or `EnterWorktree`/`ExitWorktree` guidance |

Four non-suite entries sit alongside them: `test_helper/common_setup.bash` — the shared helpers `setup_config()`/`setup()`, `setup_php_mcp_env()` (which stubs `log()` and `exec_command()` before sourcing a tool library), the worktree git fixtures `worktree_gitdir_relative()` and `_absolute_path_relative_to()`, the probe stubs `stub_worktree_probe()` / `worktree_test_guard_probe()`, `shopware_trunk_script_body()`, which answers an `npm pkg get "scripts.<name>"` probe from the trunk fixtures, and `js_execute_in_env()`, which runs a command a JS tool built through `wrap_npm_command` for one environment against fake `npm`, `docker`, `vagrant` and `ddev` and fake linter binaries; `fixtures/coverage/` — Clover XML samples for `mcp_tool_phpunit_coverage.bats`; `fixtures/shopware-trunk/` — the `scripts` blocks of the Administration and Storefront `package.json` files, copied verbatim from shopware/shopware trunk, which the JS tool suites answer script probes from; and `lsp_proxy/` — the Python `pytest` suite for `shared/lsp_proxy.py`, run outside BATS.

The modules this plugin consumes from `templates/mcp-shared/` are covered once, for every consuming plugin, in `plugin-tests/mcp-shared/`:

| Test File                     | Coverage                                                                |
|-------------------------------|---------------------------------------------------------------------------|
| `environment.bats`            | Environment wrapping, argument quoting, `parse_paths_json`, path guards   |
| `docker_compose.bats`         | Docker Compose call-time container/workdir resolution                     |
| `scope_wrap.bats`             | Scope-aware command wrapping per environment                              |
| `config.bats`                 | Config filename and env-var prefix parameterization, including `.lsp-`    |

Run tests:
```bash
.bats/bats-core/bin/bats plugin-tests/dev-tooling/*.bats plugin-tests/mcp-shared/*.bats
```

## 📖 External References

- [bash-mcp-sdk](https://github.com/shopwareLabs/bash-mcp-sdk) - the server's protocol handler is vendored from here
- [MCP Protocol Specification](https://modelcontextprotocol.io/specification) - JSON-RPC 2.0 protocol details
