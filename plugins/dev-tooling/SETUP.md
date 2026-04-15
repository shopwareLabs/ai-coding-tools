# Dev Tooling Setup

## Prerequisites

### jq
- **Check**: `jq --version`
- **Install**: https://jqlang.github.io/jq/download/
- **Required by**: All three MCP servers (php-tooling, js-admin-tooling, js-storefront-tooling)

### python3
- **Check**: `python3 --version`
- **Install**: Usually pre-installed on macOS (Monterey+) and Linux. If missing:
  - macOS: `brew install python@3.12`
  - Debian/Ubuntu: `apt install python3`
- **Required by**: Only for PHP LSP support when using a containerized `environment` (docker, docker-compose, vagrant, ddev). Not required for native LSP or when LSP is disabled. Must be version 3.12 or newer.

### phpactor (optional)
- **Check**: `phpactor --version`
- **Install**: https://phpactor.readthedocs.io/en/master/usage/installation.html — `brew install phpactor`, the phar release, or `composer require --dev phpactor/phpactor` (the latter inside the container when running a containerized LSP)
- **Required by**: Optional PHP LSP integration (document symbols, hover, go-to-definition, references). The MCP servers work without it. For containerized environments the binary must be available inside the container; the host check can be skipped.

## Configuration Files

### .mcp-php-tooling.json
- **Required**: Yes (the PHP tooling MCP server will not start without it)
- **Location**: Project root. Also discovered from `.claude/`, `.cursor/`, `.windsurf/`, `.zed/`, `.cline/`, `.aiassistant/`, `.amazonq/`, and `.kiro/` — multiple files are deep-merged. See `docs/configuration.md` for the full discovery order.
- **Schema reference**: `mcp-server-php/mcp-php-tooling.schema.json` in the dev-tooling plugin

#### Setup Questions

1. **Environment**: What execution environment does your project use for PHP?
   - `native` — PHP is installed directly on your machine
   - `docker` — PHP runs inside a standalone Docker container
   - `docker-compose` — PHP runs as a service in a `docker-compose.yml` stack (recommended for the `shopware/shopware` repo)
   - `vagrant` — PHP runs inside a Vagrant VM
   - `ddev` — You use DDEV for local development

2. **Docker container name** (only if environment = docker): What is the name of your Docker container that runs PHP? This is the container name from `docker ps`, e.g. `shopware_app`.

3. **Docker working directory** (only if environment = docker, optional): What is the working directory inside the Docker container? Default: `/var/www/html`

4. **Compose service name** (only if environment = docker-compose): Which service in your `docker-compose.yml` runs PHP? Default: `web`

5. **Compose working directory** (only if environment = docker-compose, optional): Working directory inside the compose service. Leave blank to use the service's default `WORKDIR`.

6. **Compose file** (only if environment = docker-compose, optional): Path to a specific compose file. Leave blank to let `docker compose` auto-discover `docker-compose.yml` / `compose.yml` from the project root.

7. **Vagrant working directory** (only if environment = vagrant, optional): What is the working directory inside the Vagrant VM? Default: `/vagrant`

8. **DDEV working directory** (only if environment = ddev, optional): What is the working directory inside DDEV? Default: `/var/www/html`

9. **MCP tool enforcement**: Should PreToolUse hooks redirect direct CLI invocations of PHPStan, ECS, PHPUnit, and `bin/console` to the MCP tools?
   - `true` (default, recommended) — bash commands like `vendor/bin/phpstan analyze …` are blocked with a hint to use the MCP tool instead. See `docs/mcp-enforcement.md` for the full redirect list.
   - `false` — direct CLI invocations are allowed. Choose this if you rely on the CLI output format, run tools inside long bash pipelines, or find the redirect intrusive.
   Stored as `enforce_mcp_tools` in the config.

10. **Set tool defaults?** (optional gate): Do you want to set default config paths or per-tool options for PHPStan, ECS, Rector, PHPUnit, or Symfony Console? Most projects can skip this — the underlying tools auto-discover their config files and every MCP tool accepts per-call overrides.
    - `no` (default) → skip the rest of this section
    - `yes` → continue with questions 11–14

11. **PHPStan memory limit** (only if set-tool-defaults = yes, optional): Override the PHP memory limit used for PHPStan runs? Large Shopware projects typically need `2G`. Leave blank to use the PHP default. Stored as `phpstan.memory_limit`.

12. **PHPStan config path** (only if set-tool-defaults = yes, optional): Path to a non-default `phpstan.neon` / `phpstan.dist.neon`. Leave blank to let PHPStan auto-discover. Stored as `phpstan.config`.

13. **PHPUnit defaults** (only if set-tool-defaults = yes, optional): If you want a default test suite, coverage driver, or non-default `phpunit.xml`, provide them. Leave any field blank to skip. Stored under `phpunit.testsuite`, `phpunit.coverage_driver` (`xdebug` or `pcov`), `phpunit.config`.

14. **ECS and Rector config paths** (only if set-tool-defaults = yes, optional): Paths to non-default `ecs.php` and `rector.php`. Leave blank to auto-discover. Stored as `ecs.config` and `rector.config`.

Symfony Console defaults (`console.env`, `console.verbosity`, `console.no_debug`, `console.no_interaction`) are configurable but almost never need project-wide defaults — the `console_run` tool takes them per call. Add them to the config by hand if you need them; see the schema for the full list.

#### Minimal Config

```json
{
  "environment": "native"
}
```

#### Full Config Example

```json
{
  "environment": "docker",
  "docker": {
    "container": "shopware_app",
    "workdir": "/var/www/html"
  },
  "enforce_mcp_tools": true,
  "phpstan": {
    "memory_limit": "2G"
  }
}
```

### .mcp-js-tooling.json
- **Required**: No (only needed if you want Administration or Storefront JavaScript tooling: ESLint, Stylelint, Prettier, Jest, TypeScript, Vite, Webpack)
- **Location**: Project root. Discovery rules match `.mcp-php-tooling.json` — see `docs/configuration.md` for the full list.
- **Schema reference**: `shared/mcp-js-tooling.schema.json` in the dev-tooling plugin

#### Setup Questions

1. **Environment**: What execution environment does your project use for JavaScript/Node.js?
   - `native` — Node.js is installed directly on your machine
   - `docker` — Node.js runs inside a standalone Docker container
   - `docker-compose` — Node.js runs as a service in a `docker-compose.yml` stack
   - `vagrant` — Node.js runs inside a Vagrant VM
   - `ddev` — You use DDEV for local development

   Note: This is typically the same environment as PHP. If your PHP runs in a container but you run npm/node natively, choose `native`.

2. **Docker container name** (only if environment = docker): What is the name of your Docker container that runs Node.js? This may be the same container as PHP.

3. **Docker working directory** (only if environment = docker, optional): What is the working directory inside the Docker container? Default: `/var/www/html`

4. **Compose service name** (only if environment = docker-compose): Which service in your `docker-compose.yml` runs Node.js? Default: `web`

5. **Compose working directory** (only if environment = docker-compose, optional): Working directory inside the compose service. Leave blank to use the service's default `WORKDIR`.

6. **Compose file** (only if environment = docker-compose, optional): Path to a specific compose file. Leave blank to let `docker compose` auto-discover `docker-compose.yml` / `compose.yml` from the project root.

7. **Vagrant working directory** (only if environment = vagrant, optional): Working directory inside the Vagrant VM. Default: `/vagrant`

8. **DDEV working directory** (only if environment = ddev, optional): Working directory inside DDEV. Default: `/var/www/html`

9. **MCP tool enforcement**: Should PreToolUse hooks redirect direct CLI invocations of ESLint, Stylelint, Prettier, Jest, TSC, Vite, and Webpack to the MCP tools?
   - `true` (default, recommended) — bash commands like `npm run lint` are blocked with a hint to use the MCP tool instead. The hook scopes by context (admin vs storefront), so it only blocks the commands your JS work actually runs. See `docs/mcp-enforcement.md` for the full redirect list.
   - `false` — direct CLI invocations are allowed.
   Stored as `enforce_mcp_tools` in the config.

#### Minimal Config

```json
{
  "environment": "native"
}
```

#### Full Config Example

```json
{
  "environment": "docker",
  "docker": {
    "container": "shopware_app",
    "workdir": "/var/www/html"
  },
  "enforce_mcp_tools": true
}
```

### .lsp-php-tooling.json

**Required:** No — only create this file if you want PHP LSP support (phpactor).

**Location:** Project root or any supported tool directory (`.claude/`, `.cursor/`, etc.) — same discovery rules as `.mcp-php-tooling.json`.

**Prerequisite binary:** `phpactor` must be installed where the LSP will run:
- Native: on your host — `brew install phpactor` or install via the phar release
- Containerized: inside the container — usually via `composer require --dev phpactor/phpactor` or a base image that includes it

#### Setup Questions

1. **Do you want PHP LSP support enabled?**
   - Yes → continue with this section
   - No → skip this section entirely

2. **Where should the LSP run?**
   - `native` → runs on your host; file URIs pass through unchanged, no Python required
   - `docker` / `docker-compose` / `ddev` / `vagrant` → runs inside the container; requires `python3` ≥ 3.12 on the host and `phpactor` inside the container

3. **Docker container name** (only if environment = docker): Container name from `docker ps`, e.g. `shopware_app`.

4. **Docker working directory** (only if environment = docker, optional): Default `/var/www/html`.

5. **Compose service name** (only if environment = docker-compose): Which service in your `docker-compose.yml` runs phpactor? Default: `web`

6. **Compose working directory** (only if environment = docker-compose, optional): Working directory inside the compose service. Leave blank to use the service's default `WORKDIR`.

7. **Compose file** (only if environment = docker-compose, optional): Path to a specific compose file. Leave blank to auto-discover from the project root.

8. **Vagrant working directory** (only if environment = vagrant, optional): Default `/vagrant`.

9. **DDEV working directory** (only if environment = ddev, optional): Default `/var/www/html`.

10. **Binary path (optional)**
    - Leave blank to look up `phpactor` in `$PATH`
    - Or provide an absolute path (e.g., `/opt/phpactor/bin/phpactor`)

#### Minimal Config

Native:

```json
{
  "environment": "native",
  "enabled": true
}
```

Containerized (docker-compose, matches a typical Shopware setup):

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

## Permission Groups

### PHP tooling
- **Recommended**: allow
- **Optional**: Yes (skip if `.mcp-php-tooling.json` was not created)
- **Description**: All PHP MCP tools — PHPStan, ECS, PHPUnit, coverage gap analysis, Symfony Console, and Rector. These are local analysis and test operations with no remote side effects.
- **Patterns**:
  - `mcp__plugin_dev-tooling_php-tooling__*`

### Administration JS tooling
- **Recommended**: allow
- **Optional**: Yes (skip if `.mcp-js-tooling.json` was not created)
- **Description**: ESLint, Stylelint, Prettier, Jest, TypeScript, `lint_all`, `lint_twig`, `unit_setup`, and Vite build for the Administration app.
- **Patterns**:
  - `mcp__plugin_dev-tooling_js-admin-tooling__*`

### Storefront JS tooling
- **Recommended**: allow
- **Optional**: Yes (skip if `.mcp-js-tooling.json` was not created)
- **Description**: ESLint, Stylelint, Jest, and Webpack build for the Storefront app.
- **Patterns**:
  - `mcp__plugin_dev-tooling_js-storefront-tooling__*`

## Validation

### PHP Tooling
- Use the `mcp__php-tooling__phpstan_analyze` tool to analyze any PHP file in the project (e.g., `src/Kernel.php` or any file that exists)
- **Pass**: PHPStan output with analysis results (errors or "No errors")
- **Fail**: Connection error, "missing config file" error, or "container not found" error
- Common failure causes: wrong container name, container not running, PHP not installed

### JS Admin Tooling (only if .mcp-js-tooling.json was created)
- Use the `mcp__js-admin-tooling__eslint_check` tool on any JS or Vue file in `src/Administration/Resources/app/administration/`
- **Pass**: ESLint output with results
- **Fail**: Connection error or "command not found" error
- Common failure causes: node_modules not installed, wrong container

### JS Storefront Tooling (only if .mcp-js-tooling.json was created)
- Use the `mcp__js-storefront-tooling__eslint_check` tool on any JS file in `src/Storefront/Resources/app/storefront/`
- **Pass**: ESLint output with results
- **Fail**: Connection error or "command not found" error

### PHP LSP (only if .lsp-php-tooling.json was created)
- Run the dispatcher in dry-run mode against the current project:
  ```bash
  LSP_DISPATCH_DRY_RUN=1 PROJECT_ROOT="$(pwd)" \
    bash "${CLAUDE_SKILL_DIR}/../../lsp-server-php/lsp.sh"
  ```
- **Pass**: output contains `target=direct-exec` (native) or `target=python-proxy` (containerized). The dispatcher resolved config, enabled flag, environment, and the phpactor preflight.
- **Fail**: output contains `target=null-stub reason=...`. Read the reason:
  - `no .lsp-php-tooling.json found` — config missing or unreadable
  - `enabled=false` — flip `enabled` to `true`
  - `preflight failed: phpactor not found in <env> context` — install phpactor inside the container (or on the host for native)
  - `unsupported environment` — environment value is not one of `native|docker|docker-compose|vagrant|ddev`
  - `failed to resolve docker-compose workdir` — the compose service can't be resolved; check `service`, `file`, and that the stack is up
- Note: this check validates dispatch only. Live LSP behavior (document symbols, hover, etc.) can only be exercised by opening a `.php` file in Claude Code after restart. The `Method not found from plugin:dev-tooling:phpactor` error at runtime means the null stub was selected — rerun the dry-run check to diagnose.

## Post-Setup

- Restart Claude Code after creating configuration files. The MCP servers are loaded at startup and will not pick up new config files until restart.
- If you change a configuration file later, you also need to restart Claude Code.
- After restart, the dev-tooling MCP tools will appear in your tool list. You can verify by asking Claude to run PHPStan on a file.

### Containerized LSP lifecycle

If you enabled an LSP with a containerized `environment` (docker, docker-compose, vagrant, ddev), **the container must be running before you open Claude Code**. Language servers start lazily — Claude Code spawns the LSP process the first time a matching file is opened in the session. If the container is down at that moment, the dispatcher's preflight check fails, falls back to the null stub, and the session continues without LSP support until you quit and restart Claude Code.

Practical recipe:

1. `docker compose up -d` (or `ddev start`, etc.)
2. `claude` (start Claude Code)
3. Open a file to trigger LSP lazy spawn

If you ever see `Method not found from plugin:dev-tooling:phpactor` when you expected real LSP behavior, the most likely cause is the container wasn't up at startup. Restart Claude Code after starting the container.
