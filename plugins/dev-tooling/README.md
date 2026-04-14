# Dev Tooling

Development tools for PHP and JavaScript operations via MCP (Model Context Protocol), plus an optional **PHP language server** (phpactor) for active code discovery. Provides PHPStan, ECS, PHPUnit, Symfony Console, ESLint, Stylelint, Prettier, Jest, TypeScript, and build tools. Supports multiple development environments with auto-detection.

## 🧩 Features

### PHP Tools (php-tooling MCP Server)
- **PHPStan** static analysis via `phpstan_analyze`
- **ECS** code style checking via `ecs_check` and `ecs_fix`
- **PHPUnit** test execution via `phpunit_run`
- **PHPUnit Coverage Gaps** uncovered line discovery via `phpunit_coverage_gaps`
- **Symfony Console** command execution via `console_run` and `console_list`
- **Rector** automated refactoring via `rector_fix` and `rector_check`

### Administration Tools (js-admin-tooling MCP Server)
- **ESLint** linting via `eslint_check` and `eslint_fix`
- **Stylelint** SCSS linting via `stylelint_check` and `stylelint_fix`
- **Prettier** formatting via `prettier_check` and `prettier_fix`
- **TypeScript** type checking via `tsc_check`
- **All Lints** combined via `lint_all` (TypeScript + ESLint + Stylelint + Prettier)
- **Twig** template linting via `lint_twig`
- **Jest** testing via `jest_run`
- **Unit Setup** import resolver via `unit_setup`
- **Vite build** via `vite_build`

### Storefront Tools (js-storefront-tooling MCP Server)
- **ESLint** linting via `eslint_check` and `eslint_fix`
- **Stylelint** SCSS linting via `stylelint_check` and `stylelint_fix`
- **Jest** testing via `jest_run`
- **Webpack build** via `webpack_build`

> [!NOTE]
> Prettier and TypeScript tools are NOT available for Storefront because the Shopware 6 Storefront `package.json` does not include these scripts.

### Shared Features
- **Multi-environment support**: native, docker, vagrant, ddev
- **Environment noise filtering**: automatically strips known runtime warnings (e.g., Xdebug Step Debug connection failures) from all tool output, keeping results clean without hiding errors
- **Flexible configuration**: environment variable, project root, or LLM tool directories
- **Cross-tool support**: config discovery in `.claude/`, `.cursor/`, `.windsurf/`, `.zed/`, `.cline/`, `.aiassistant/`, `.amazonq/`, `.kiro/`
- **Config merging**: multiple config files are deep-merged (later locations override earlier)

### LSP Support (opt-in)

Optional Language Server Protocol integration for active code discovery. When enabled, Claude Code can call LSP operations (`documentSymbol`, `hover`, `definition`, `references`, diagnostics) on PHP files as tool invocations.

- **PHP:** [phpactor](https://github.com/phpactor/phpactor) — MIT-licensed, pure-PHP language server
- **Containerized execution:** a Python URI-rewriting proxy (`shared/lsp_proxy.py`) translates `file://` URIs between host and container on every LSP frame, so the LSP running inside docker/docker-compose/ddev/vagrant sees paths that exist in its filesystem
- **Opt-in by default:** without an LSP config file or with `enabled: false`, the dispatcher runs a minimal null stub so Claude Code doesn't crash-and-retry on unsupported capabilities
- **Preflight check:** before spawning a containerized LSP, the dispatcher verifies the binary is actually available inside the container and falls back to the null stub on failure

> [!NOTE]
> For Claude to invoke LSP operations as tool calls, `ENABLE_LSP_TOOL=1` must be set in your Claude Code environment. See [LSP Installation](#-lsp-installation) below for setup.

## ⚡ Quick Start

### Installation

```bash
/plugin install dev-tooling@shopware-ai-coding-tools
```

> [!IMPORTANT]
> Restart Claude Code after installation for the MCP servers to initialize.

### Interactive Setup

After restarting, ask Claude to help you set up the plugin:

```
Help me set up dev-tooling
```

The `setting-up` skill checks prerequisites, walks you through config file creation, and validates the result. You can also configure manually — see [Configuration](#-configuration) below.

### Verification

After restarting, verify the MCP servers are running:

```bash
/mcp
```

You should see `php-tooling`, `js-admin-tooling`, and `js-storefront-tooling` listed as connected servers.

### Recommended Setup (shopware/shopware)

For development in the `shopware/shopware` repository, use the `docker-compose` environment. It reads the container name and working directory directly from your `compose.yaml` (including any `compose.override.yaml`):

```json
{
  "environment": "docker-compose"
}
```

This is all you need. The server auto-detects the `web` service and its `/var/www/html` bind mount. Docker does not need to be running when Claude Code starts — resolution happens when a tool is called.

To customize, all fields are optional:

```json
{
  "environment": "docker-compose",
  "docker-compose": {
    "file": "docker/compose.yaml",
    "service": "app",
    "workdir": "/app"
  }
}
```

## 🎛️ Configuration

### PHP Configuration: `.mcp-php-tooling.json`

```json
{
  "environment": "docker-compose",
  "phpstan": {
    "memory_limit": "2G"
  },
  "phpunit": {
    "testsuite": "unit",
    "config": "phpunit.xml.dist"
  },
  "console": {
    "env": "dev",
    "verbosity": "normal",
    "no_debug": false,
    "no_interaction": true
  },
  "rector": {
    "config": "rector.php"
  }
}
```

#### Tool Options

| Field                     | Type    | Default | Description                                                                  |
|---------------------------|---------|---------|------------------------------------------------------------------------------|
| `phpstan.config`          | string  | -       | PHPStan configuration file path                                              |
| `phpstan.memory_limit`    | string  | -       | PHP memory limit (e.g., `2G`, `512M`)                                        |
| `ecs.config`              | string  | -       | ECS/PHP-CS-Fixer configuration file path                                     |
| `phpunit.testsuite`       | string  | -       | Default test suite to run                                                    |
| `phpunit.config`          | string  | -       | PHPUnit configuration file path                                              |
| `phpunit.coverage_driver` | string  | -       | Default coverage driver: `xdebug` (injects `XDEBUG_MODE=coverage`) or `pcov` |
| `console.env`             | string  | -       | Default Symfony environment (`dev`, `prod`, `test`)                          |
| `console.verbosity`       | string  | -       | Output verbosity (`quiet`, `normal`, `verbose`, `very-verbose`, `debug`)     |
| `console.no_debug`        | boolean | -       | Disable debug mode by default                                                |
| `console.no_interaction`  | boolean | -       | Non-interactive mode by default                                              |
| `rector.config`           | string  | -       | Rector configuration file path                                               |
| `log_file`                | string  | -       | Additional log file path. Relative paths resolve against the project root.   |

### JavaScript Configuration: `.mcp-js-tooling.json`

Shared configuration for both `js-admin-tooling` and `js-storefront-tooling` MCP servers.

```json
{
  "environment": "native"
}
```

Docker Compose example (recommended for shopware/shopware):

```json
{
  "environment": "docker-compose"
}
```

Manual Docker example (non-compose setups):

```json
{
  "environment": "docker",
  "docker": {
    "container": "shopware_app",
    "workdir": "/var/www/html"
  }
}
```

### Configuration Priority

Configuration is loaded in the following priority order:

1. **Environment variable**: `MCP_PHP_TOOLING_CONFIG` / `MCP_JS_TOOLING_CONFIG`
2. **Config file discovery** (checked in order, deep-merged if multiple exist):
   - `.mcp-<prefix>.json` (project root, base config)
   - `.aiassistant/.mcp-<prefix>.json` (JetBrains AI Assistant)
   - `.amazonq/.mcp-<prefix>.json` (Amazon Q Developer)
   - `.cline/.mcp-<prefix>.json` (Cline)
   - `.cursor/.mcp-<prefix>.json` (Cursor AI)
   - `.kiro/.mcp-<prefix>.json` (Kiro)
   - `.windsurf/.mcp-<prefix>.json` (Windsurf/Codeium)
   - `.zed/.mcp-<prefix>.json` (Zed editor)
   - `.claude/.mcp-<prefix>.json` (override, highest priority)

### Environment Options

| Field                    | Type   | Default                     | Description                                                                |
|--------------------------|--------|-----------------------------|----------------------------------------------------------------------------|
| `environment`            | string | **required**                | `docker-compose`, `native`, `docker`, `vagrant`, or `ddev`                 |
| `docker-compose.file`    | string | Compose CLI discovery       | Path to compose file, relative to project root                             |
| `docker-compose.service` | string | `web`                       | Compose service name to exec into                                          |
| `docker-compose.workdir` | string | auto-detect from bind mount | Working directory override inside container                                |
| `docker.container`       | string | **required for docker**     | Docker container name                                                      |
| `docker.workdir`         | string | `/var/www/html`             | Working directory in container                                             |
| `vagrant.workdir`        | string | `/vagrant`                  | Working directory in VM                                                    |
| `ddev.workdir`           | string | `/var/www/html`             | Working directory in DDEV                                                  |
| `log_file`               | string | -                           | Additional log file path. Relative paths resolve against the project root. |

## 🗜️ Tools Reference

25 tools across 3 MCP servers. See [REFERENCE.md](./REFERENCE.md) for full parameter docs and examples.

| Server                  | Tools                                                                                                                                                                            |
|-------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `php-tooling`           | `phpstan_analyze`, `ecs_check`, `ecs_fix`, `phpunit_run`, `phpunit_coverage_gaps`, `console_run`, `console_list`, `rector_fix`, `rector_check`                                   |
| `js-admin-tooling`      | `eslint_check`, `eslint_fix`, `stylelint_check`, `stylelint_fix`, `prettier_check`, `prettier_fix`, `jest_run`, `tsc_check`, `lint_all`, `lint_twig`, `unit_setup`, `vite_build` |
| `js-storefront-tooling` | `eslint_check`, `eslint_fix`, `stylelint_check`, `stylelint_fix`, `jest_run`, `webpack_build`                                                                                    |

## 🚫 Watch Mode / Long-Running Tasks

**Watch mode is not supported via MCP tools.**

MCP servers use a synchronous request-response model. Watch tasks (like `npm run hot` or `jest --watch`) run indefinitely, which would hang the MCP server and block all subsequent requests.

### Running Watch Tasks

Run watch tasks directly in a separate terminal:

```bash
# Storefront hot reload (Webpack)
cd src/Storefront/Resources/app/storefront && npm run hot

# Administration hot reload (Vite)
cd src/Administration/Resources/app/administration && npm run dev

# Jest watch mode
cd src/Administration/Resources/app/administration && npm run unit-watch
cd src/Storefront/Resources/app/storefront && npm run unit-watch
```

Use MCP tools for **one-time operations** (builds, linting, testing), not continuous watching.

## 🛡️ MCP Tool Enforcement

This plugin enforces MCP tool usage through two hook layers:

- **SessionStart hook** — Injects a directive at the start of every conversation listing all available MCP tools and instructing Claude to use them instead of bash commands. The prompt is maintained in `hooks/prompts/mcp-tool-directives.md`.
- **PreToolUse hooks** — Block bash commands that match known tool patterns and redirect to the corresponding MCP tool. Acts as a safety net when the SessionStart directive is not followed.
- **PostToolUse hook** — After `phpstan_analyze` runs on specific files, checks whether those files have entries in the PHPStan baseline (`phpstan-baseline.neon` or `phpstan-baseline.php`). If matches are found, injects a warning prompting verification of stale baseline entries. Skips silently for full-project runs where PHPStan validates the baseline natively.

The SessionStart and PreToolUse hooks respect the `enforce_mcp_tools` setting and are disabled when set to `false`. The PostToolUse baseline check always runs (it is not affected by `enforce_mcp_tools`).

### Disabling Enforcement

To allow direct CLI invocations, set `enforce_mcp_tools` to `false` in your config:

```json
{
  "environment": "native",
  "enforce_mcp_tools": false
}
```

This applies per-config file (`.mcp-php-tooling.json` or `.mcp-js-tooling.json`).

### Blocked PHP Commands

| Bash Command                                                | MCP Tool                                         |
|-------------------------------------------------------------|--------------------------------------------------|
| `vendor/bin/phpstan`, `composer phpstan`                    | `mcp__php-tooling__phpstan_analyze`              |
| `vendor/bin/ecs`, `vendor/bin/php-cs-fixer`, `composer ecs` | `mcp__php-tooling__ecs_check` / `ecs_fix`        |
| `vendor/bin/phpunit`, `composer phpunit`                    | `mcp__php-tooling__phpunit_run`                  |
| `bin/console`, `php bin/console`                            | `mcp__php-tooling__console_run` / `console_list` |
| `vendor/bin/rector`, `composer rector`                      | `mcp__php-tooling__rector_fix` / `rector_check`  |

### Blocked JavaScript Commands

The JS hook detects context (Administration vs Storefront) from path patterns in the command and recommends the appropriate MCP server.

| Bash Command                         | Admin MCP Tool    | Storefront MCP Tool |
|--------------------------------------|-------------------|---------------------|
| `npm run lint`, `npx eslint`         | `eslint_check`    | `eslint_check`      |
| `npm run lint:fix`                   | `eslint_fix`      | `eslint_fix`        |
| `npm run lint:scss`, `npx stylelint` | `stylelint_check` | `stylelint_check`   |
| `npm run format`, `npx prettier`     | `prettier_check`  | N/A (Admin only)    |
| `npm run unit`, `npx jest`           | `jest_run`        | `jest_run`          |
| `npm run lint:types`, `npx tsc`      | `tsc_check`       | N/A (Admin only)    |
| `npm run build`                      | `vite_build`      | N/A                 |
| `npm run production/development`     | N/A               | `webpack_build`     |

### Commands NOT Blocked

- `npm install`, `composer install` (setup commands)
- `npm run hot`, `npm run unit-watch` (watch mode - not supported by MCP)
- Custom npm scripts not matching known patterns

**Testing:** BATS tests for hooks are in `plugin-tests/dev-tooling/`.

## 🔗 Integration with Other Plugins

Other plugins can use these tools by referencing them in their tool lists:

```markdown
---
tools: mcp__php-tooling__phpstan_analyze, mcp__php-tooling__ecs_check, mcp__js-admin-tooling__eslint_check
---

After generating code, run PHPStan analysis, ECS check, and ESLint check.
```

## 🩺 Troubleshooting

### MCP Server Not Starting

1. Ensure Claude Code was restarted after plugin installation
2. Check `/mcp` for connection status
3. Verify `jq` is installed: `which jq`

### Docker Environment Not Detected

1. Verify `docker-compose.yml` exists in project root
2. Check container name matches configuration
3. Ensure container is running: `docker ps`

### JS Tools Not Finding Files

1. Ensure npm dependencies are installed in the target directory
2. Verify the npm script names exist in your package.json

### Docker Compose Service Not Found

1. Verify the service name matches your `compose.yaml`: default is `web`
2. Override with `"docker-compose": {"service": "your-service"}` in config

### Docker Compose Container Not Running

1. Start the containers: `docker compose up -d`
2. Verify the service is running: `docker compose ps`
3. If using a custom compose file: set `"docker-compose": {"file": "path/to/compose.yaml"}`

### Docker Compose Workdir Not Detected

1. Ensure your compose service has a bind mount mapping your project root
2. Override with `"docker-compose": {"workdir": "/your/path"}` in config

## 📌 Dependencies

- **bash** (4.0+)
- **jq** (JSON processor)

### PHP Tools
- PHPStan, PHP-CS-Fixer/ECS, PHPUnit (installed in project)

### JavaScript Tools
- Node.js (20+), npm
- ESLint, Stylelint, Prettier, Jest, TypeScript (installed in project)

## 📦 LSP Installation

LSP support is **opt-in**. Create `.lsp-php-tooling.json` in your project root (or any supported tool directory like `.claude/`) with `"enabled": true` to activate. The `setting-up` skill walks you through this interactively.

### PHP — phpactor

Install [phpactor](https://phpactor.readthedocs.io/) wherever the LSP will run — on the host for `environment: native`, inside the container for `docker` / `docker-compose` / `ddev` / `vagrant`.

```bash
# macOS host install
brew install phpactor

# Containerized — add to your image or install via composer
composer require --dev phpactor/phpactor
```

Minimal `.lsp-php-tooling.json` (docker-compose):

```json
{
  "environment": "docker-compose",
  "docker-compose": {
    "service": "web",
    "workdir": "/var/www/html"
  },
  "enabled": true
}
```

### Python 3.12 (containerized LSPs only)

The URI-rewriting proxy is pure-stdlib Python 3.12+. Pre-installed on macOS (Monterey+) and most Linux distros — verify with `python3 --version`. Not required for `environment: native`: the dispatcher `exec`s directly into the binary in that case.

### Enabling the LSP tool in Claude Code

For Claude to actively invoke `LSP(operation: "documentSymbol", ...)` as a tool call, set `ENABLE_LSP_TOOL=1` in your Claude Code environment (typically in `~/.claude/settings.json` under the `env` key). Without this flag, LSP diagnostics still surface passively in context but the agent can't call LSP operations directly.

### PHP LSP limitations

Phpactor implements a subset of the LSP spec. The `LSP` tool in Claude Code exposes nine operations; against phpactor they break down as follows.

**Supported:**

- `documentSymbol` — list symbols in a file
- `workspaceSymbol` — workspace-wide symbol search (see bug below)
- `hover` — signature and type info at a position
- `goToDefinition` — jump to symbol definition
- `goToImplementation` — jump to interface/abstract implementations
- `findReferences` — find all usages of a symbol

**Not supported by phpactor:**

- `prepareCallHierarchy`, `incomingCalls`, `outgoingCalls` — phpactor has no call-hierarchy handler. Walk call chains manually with `findReferences` + `goToDefinition`.

**Known issues:**

- `workspaceSymbol` currently caps at 250 results and ignores the query string — it returns the first 250 symbols regardless of what you ask for. Prefer `documentSymbol` on a specific file, or fall back to Grep for workspace-wide identifier search.

**First-request latency:** the first LSP request against a PHP file can take 10–30s while phpactor parses it and resolves its dependencies. Subsequent requests against the same file are fast. There is no cache warmup today.

The dev-tooling plugin injects these limitations as SessionStart context via `hooks/scripts/lsp-directives.sh`, so Claude won't attempt unsupported operations when the PHP LSP is enabled in your project.

### Troubleshooting LSP

**`Method not found from plugin:dev-tooling:phpactor`** — the dispatcher fell back to the null stub. Common causes:
- `enabled` is missing or `false` in the LSP config
- For containerized environments: the container wasn't running when Claude Code spawned the LSP. LSPs start lazily on first matching file open; start the container before launching Claude Code, then restart Claude Code if you already hit this.
- The binary (`phpactor`) isn't installed inside the container
- `python3` is not on the host PATH (required for containerized LSPs only)

**LSP not loading at all** — check the `/plugin` Errors tab. Also verify `ENABLE_LSP_TOOL=1` is set in your Claude Code environment.

**LSP servers accumulating inside the container** — if you run containerized LSPs and kill Claude Code (or let it timeout on an in-flight tool call) without a clean LSP shutdown, the container-side language server process is not reaped. This is a `docker exec -i` signal-propagation limitation ([moby/moby#9098](https://github.com/moby/moby/issues/9098)): when the host-side exec process dies, the container-side child is not killed. Each new session spawns another server alongside the old one, which can add up over a working day. Workarounds until this is fixed in the plugin:

- Restart the container periodically: `docker compose restart <service>`
- Or kill the stale servers manually: `docker compose exec <service> pkill -f phpactor.phar` (scope the pattern to the binary you use)
- Parallel Claude Code sessions on the same container are a valid use case and should not use a blanket `pkill` — only kill stale processes you know belong to sessions that have already exited

## ⚖️ License

MIT
