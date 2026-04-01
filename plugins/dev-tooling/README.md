# Dev Tooling

Development tools for PHP and JavaScript operations via MCP (Model Context Protocol), plus **Shopware LSP** for intelligent code completion. Provides PHPStan, ECS, PHPUnit, Symfony Console, ESLint, Stylelint, Prettier, Jest, TypeScript, and build tools. Supports multiple development environments with auto-detection.

## Features

### PHP Tools (php-tooling MCP Server)
- **PHPStan** static analysis via `phpstan_analyze`
- **ECS** code style checking via `ecs_check` and `ecs_fix`
- **PHPUnit** test execution via `phpunit_run`
- **PHPUnit Coverage Gaps** uncovered line discovery via `phpunit_coverage_gaps`
- **Symfony Console** command execution via `console_run` and `console_list`

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

> **Note**: Prettier and TypeScript tools are NOT available for Storefront because the Shopware 6 Storefront `package.json` does not include these scripts.

### Shared Features
- **Multi-environment support**: native, docker, vagrant, ddev
- **Environment noise filtering**: automatically strips known runtime warnings (e.g., Xdebug Step Debug connection failures) from all tool output, keeping results clean without hiding errors
- **Flexible configuration**: environment variable, project root, or LLM tool directories
- **Cross-tool support**: config discovery in `.claude/`, `.cursor/`, `.windsurf/`, `.zed/`, `.cline/`, `.aiassistant/`, `.amazonq/`, `.kiro/`
- **Config merging**: multiple config files are deep-merged (later locations override earlier)

### Shopware LSP (Language Server Protocol)

Intelligent code completion and navigation for Shopware 6 development:

- **Service ID completion**: PHP, XML, and YAML files with navigation and code lens
- **Twig template support**: completion, navigation, icon previews for `sw_icon` tags
- **Snippet handling**: validation, completion, and diagnostics for missing snippets
- **Route completion**: route name completion with parameter support
- **Feature flags**: detection and completion

**Supported file types**: PHP, XML, YAML, Twig (`.twig`, `.html.twig`)

> **Note**: LSP requires the `shopware-lsp` binary to be installed separately. See [Shopware LSP Installation](#shopware-lsp-installation) below.

## Quick Start

### Installation

```bash
/plugin install dev-tooling@shopware-ai-coding-tools
```

**IMPORTANT**: Restart Claude Code after installation for the MCP servers to initialize.

### Verification

After restarting, verify the MCP servers are running:

```bash
/mcp
```

You should see `php-tooling`, `js-admin-tooling`, and `js-storefront-tooling` listed as connected servers.

## Configuration

### PHP Configuration: `.mcp-php-tooling.json`

```json
{
  "environment": "docker",
  "docker": {
    "container": "shopware_app",
    "workdir": "/var/www/html"
  },
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
  }
}
```

#### Tool Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `phpstan.config` | string | - | PHPStan configuration file path |
| `phpstan.memory_limit` | string | - | PHP memory limit (e.g., `2G`, `512M`) |
| `ecs.config` | string | - | ECS/PHP-CS-Fixer configuration file path |
| `phpunit.testsuite` | string | - | Default test suite to run |
| `phpunit.config` | string | - | PHPUnit configuration file path |
| `phpunit.coverage_driver` | string | - | Default coverage driver: `xdebug` (injects `XDEBUG_MODE=coverage`) or `pcov` |
| `console.env` | string | - | Default Symfony environment (`dev`, `prod`, `test`) |
| `console.verbosity` | string | - | Output verbosity (`quiet`, `normal`, `verbose`, `very-verbose`, `debug`) |
| `console.no_debug` | boolean | - | Disable debug mode by default |
| `console.no_interaction` | boolean | - | Non-interactive mode by default |
| `log_file` | string | - | Additional log file path. Relative paths resolve against the project root. |

### JavaScript Configuration: `.mcp-js-tooling.json`

Shared configuration for both `js-admin-tooling` and `js-storefront-tooling` MCP servers.

```json
{
  "environment": "native"
}
```

Docker example:

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

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `environment` | string | **required** | `native`, `docker`, `vagrant`, or `ddev` |
| `docker.container` | string | **required for docker** | Docker container name |
| `docker.workdir` | string | `/var/www/html` | Working directory in container |
| `vagrant.workdir` | string | `/vagrant` | Working directory in VM |
| `ddev.workdir` | string | `/var/www/html` | Working directory in DDEV |
| `log_file` | string | - | Additional log file path. Relative paths resolve against the project root. |

## Tools Reference

25 tools across 3 MCP servers. See [REFERENCE.md](./REFERENCE.md) for full parameter docs and examples.

| Server | Tools |
|--------|-------|
| `php-tooling` | `phpstan_analyze`, `ecs_check`, `ecs_fix`, `phpunit_run`, `phpunit_coverage_gaps`, `console_run`, `console_list` |
| `js-admin-tooling` | `eslint_check`, `eslint_fix`, `stylelint_check`, `stylelint_fix`, `prettier_check`, `prettier_fix`, `jest_run`, `tsc_check`, `lint_all`, `lint_twig`, `unit_setup`, `vite_build` |
| `js-storefront-tooling` | `eslint_check`, `eslint_fix`, `stylelint_check`, `stylelint_fix`, `jest_run`, `webpack_build` |

## Watch Mode / Long-Running Tasks

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

## MCP Tool Enforcement

This plugin enforces MCP tool usage through two hook layers:

- **SessionStart hook** — Injects a directive at the start of every conversation listing all available MCP tools and instructing Claude to use them instead of bash commands. The prompt is maintained in `hooks/prompts/mcp-tool-directives.md`.
- **PreToolUse hooks** — Block bash commands that match known tool patterns and redirect to the corresponding MCP tool. Acts as a safety net when the SessionStart directive is not followed.

Both hooks respect the `enforce_mcp_tools` setting and are disabled when set to `false`.

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

| Bash Command | MCP Tool |
|--------------|----------|
| `vendor/bin/phpstan`, `composer phpstan` | `mcp__php-tooling__phpstan_analyze` |
| `vendor/bin/ecs`, `vendor/bin/php-cs-fixer`, `composer ecs` | `mcp__php-tooling__ecs_check` / `ecs_fix` |
| `vendor/bin/phpunit`, `composer phpunit` | `mcp__php-tooling__phpunit_run` |
| `bin/console`, `php bin/console` | `mcp__php-tooling__console_run` / `console_list` |

### Blocked JavaScript Commands

The JS hook detects context (Administration vs Storefront) from path patterns in the command and recommends the appropriate MCP server.

| Bash Command | Admin MCP Tool | Storefront MCP Tool |
|--------------|----------------|---------------------|
| `npm run lint`, `npx eslint` | `eslint_check` | `eslint_check` |
| `npm run lint:fix` | `eslint_fix` | `eslint_fix` |
| `npm run lint:scss`, `npx stylelint` | `stylelint_check` | `stylelint_check` |
| `npm run format`, `npx prettier` | `prettier_check` | N/A (Admin only) |
| `npm run unit`, `npx jest` | `jest_run` | `jest_run` |
| `npm run lint:types`, `npx tsc` | `tsc_check` | N/A (Admin only) |
| `npm run build` | `vite_build` | N/A |
| `npm run production/development` | N/A | `webpack_build` |

### Commands NOT Blocked

- `npm install`, `composer install` (setup commands)
- `npm run hot`, `npm run unit-watch` (watch mode - not supported by MCP)
- Custom npm scripts not matching known patterns

**Testing:** BATS tests for hooks are in `plugin-tests/dev-tooling/`.

## Integration with Other Plugins

Other plugins can use these tools by referencing them in their tool lists:

```markdown
---
tools: mcp__php-tooling__phpstan_analyze, mcp__php-tooling__ecs_check, mcp__js-admin-tooling__eslint_check
---

After generating code, run PHPStan analysis, ECS check, and ESLint check.
```

## Troubleshooting

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

## Dependencies

- **bash** (4.0+)
- **jq** (JSON processor)

### PHP Tools
- PHPStan, PHP-CS-Fixer/ECS, PHPUnit (installed in project)

### JavaScript Tools
- Node.js (20+), npm
- ESLint, Stylelint, Prettier, Jest, TypeScript (installed in project)

## Shopware LSP Installation

The Shopware LSP binary must be installed manually and available in your PATH.

### Download

Download the appropriate binary for your platform from [GitHub Releases](https://github.com/shopwareLabs/shopware-lsp/releases):

| Platform | File |
|----------|------|
| macOS ARM64 (Apple Silicon) | `shopware-lsp_0.0.13_darwin_arm64.zip` |
| macOS Intel | `shopware-lsp_0.0.13_darwin_amd64.zip` |
| Linux x86-64 | `shopware-lsp_0.0.13_linux_amd64.zip` |
| Linux ARM64 | `shopware-lsp_0.0.13_linux_arm64.zip` |

### Installation Steps

```bash
# macOS ARM64 example - adjust filename for your platform
curl -LO https://github.com/shopwareLabs/shopware-lsp/releases/download/v0.0.13/shopware-lsp_0.0.13_darwin_arm64.zip

# Extract
unzip shopware-lsp_0.0.13_darwin_arm64.zip

# Move to PATH
mkdir -p ~/.local/bin
mv shopware-lsp ~/.local/bin/
chmod +x ~/.local/bin/shopware-lsp

# Add to PATH if needed (add to ~/.zshrc or ~/.bashrc)
export PATH="$HOME/.local/bin:$PATH"

# Verify installation
shopware-lsp --version
```

### Verification

After installing and enabling LSP, verify it's working:

1. Open a Shopware project with Claude Code
2. Edit a PHP file that uses services
3. Claude should have access to go-to-definition, find-references, and hover information

### Troubleshooting LSP

**"Executable not found in $PATH"**
- Ensure `shopware-lsp` is in your PATH: `which shopware-lsp`
- Restart Claude Code after adding to PATH

**LSP not loading**
- Check `/plugin` Errors tab for LSP errors
- Note: LSP support may have issues in Claude Code versions ~2.0.69+

## License

MIT
