# Dev Tooling Setup

## Prerequisites

### jq
- **Check**: `jq --version`
- **Install**: https://jqlang.github.io/jq/download/
- **Required by**: All three MCP servers (php-tooling, js-admin-tooling, js-storefront-tooling)

### python3
- **Check**: `python3 --version` (must be ≥ 3.12)
- **Install**: Usually pre-installed on macOS (Monterey+) and Linux. If missing:
  - macOS: `brew install python@3.12`
  - Debian/Ubuntu: `apt install python3`
- **Required by**: Only for LSP support when using a containerized `environment` (docker, docker-compose, vagrant, ddev). Not required for native LSP or when LSP is disabled.

### ENABLE_LSP_TOOL environment variable (Claude Code setting)
- **Check**: `ENABLE_LSP_TOOL=1` must be set in your Claude Code environment for Claude to actively call LSP operations as a tool (e.g., `LSP(operation: "documentSymbol", file: "...")`). Without this flag, Claude Code still consumes LSP diagnostics for passive context enrichment, but the in-session agent cannot invoke `documentSymbol` / `hover` / `definition` / `references` as tool calls.
- **How to set**: Add `ENABLE_LSP_TOOL=1` to your Claude Code settings env list — typically in `~/.claude/settings.json` under the `env` key, or via your shell profile before launching Claude Code. Consult the Claude Code docs for the current recommended location.
- **Required by**: Only matters if you want Claude to actively query LSP operations during conversations. Disabling the LSP entirely (our default) means this variable is irrelevant.

## Configuration Files

### .mcp-php-tooling.json
- **Required**: Yes (the PHP tooling MCP server will not start without it)
- **Location**: Project root (higher-priority override: `.claude/.mcp-php-tooling.json`)
- **Schema reference**: `mcp-server-php/mcp-php-tooling.schema.json` in the dev-tooling plugin

#### Setup Questions

1. **Environment**: What execution environment does your project use for PHP?
   - `native` — PHP is installed directly on your machine
   - `docker` — PHP runs inside a Docker container
   - `vagrant` — PHP runs inside a Vagrant VM
   - `ddev` — You use DDEV for local development

2. **Docker container name** (only if environment = docker): What is the name of your Docker container that runs PHP? This is the container name from `docker ps`, e.g. `shopware_app`.

3. **Docker working directory** (only if environment = docker, optional): What is the working directory inside the Docker container? Default: `/var/www/html`

4. **Vagrant working directory** (only if environment = vagrant, optional): What is the working directory inside the Vagrant VM? Default: `/vagrant`

5. **DDEV working directory** (only if environment = ddev, optional): What is the working directory inside DDEV? Default: `/var/www/html`

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
  "phpstan": {
    "memory_limit": "2G"
  }
}
```

### .mcp-js-tooling.json
- **Required**: No (only needed if you want Administration or Storefront JavaScript tooling: ESLint, Stylelint, Prettier, Jest, TypeScript, Vite, Webpack)
- **Location**: Project root (higher-priority override: `.claude/.mcp-js-tooling.json`)
- **Schema reference**: `shared/mcp-js-tooling.schema.json` in the dev-tooling plugin

#### Setup Questions

1. **Environment**: What execution environment does your project use for JavaScript/Node.js?
   - `native` — Node.js is installed directly on your machine
   - `docker` — Node.js runs inside a Docker container
   - `vagrant` — Node.js runs inside a Vagrant VM
   - `ddev` — You use DDEV for local development

   Note: This is typically the same environment as PHP. If your PHP runs in Docker but you run npm/node natively, choose `native`.

2. **Docker container name** (only if environment = docker): What is the name of your Docker container that runs Node.js? This may be the same container as PHP.

3. **Docker working directory** (only if environment = docker, optional): What is the working directory inside the Docker container? Default: `/var/www/html`

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
  }
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
   - **native** → runs on your host; file URIs pass through unchanged, no Python required
   - **docker** / **docker-compose** / **ddev** / **vagrant** → runs inside the container; requires `python3` ≥ 3.12 on the host and `phpactor` inside the container

3. **Binary path (optional)**
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

### LSP (optional)
- If you enabled LSP, open a `.php` (or `.ts`) file in Claude Code and ask "show the document symbols for this file." The `LSP(operation: "documentSymbol", …)` tool should return a structured outline. If you see `Method not found from plugin:dev-tooling:phpactor`, the LSP is running as the null stub — check that `enabled: true` is set and the binary is available.

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
