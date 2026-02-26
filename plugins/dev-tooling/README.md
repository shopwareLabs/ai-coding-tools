# Dev Tooling

Development tools for PHP and JavaScript operations via MCP (Model Context Protocol), plus **Shopware LSP** for intelligent code completion. Provides PHPStan, ECS, PHPUnit, Symfony Console, ESLint, Stylelint, Prettier, Jest, TypeScript, and build tools. Supports multiple development environments with auto-detection.

> **Note**: GitHub CLI tools were extracted to the standalone `gh-tooling` plugin in v3.0.0. Install separately: `/plugin install gh-tooling@shopware-plugins`

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
/plugin install dev-tooling@shopware-plugins
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
    "config": "phpstan.neon",
    "memory_limit": "2G"
  },
  "ecs": {
    "config": "ecs.php"
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

## PHP Tools Reference

### `phpstan_analyze`

Run PHPStan static analysis.

```
Use phpstan_analyze with paths ["src/Core/"] and level 8
```

**Parameters:**
- `paths` (array, optional): File paths or directories to analyze
- `level` (integer 0-9, optional): Analysis strictness level
- `error_format` (string, optional): Output format (`json`, `table`, `raw`)

### `ecs_check` / `ecs_fix`

Check or fix PHP coding standard violations.

```
Use ecs_check to check src/Core/Content/Product/
Use ecs_fix to fix src/Core/Content/Product/ProductEntity.php
```

### `phpunit_run`

Run PHPUnit tests.

```
Use phpunit_run with testsuite "unit"
Use phpunit_run with paths ["tests/unit/Core/Checkout/"]
Use phpunit_run with filter "testAddProduct"
```

**Parameters:**
- `testsuite` (string): Test suite to run (`unit`, `integration`, etc.)
- `paths` (array): Specific test file(s) or directories
- `filter` (string): Filter tests by name pattern
- `coverage` (boolean): Generate code coverage report
- `coverage_format` (string): Coverage output format — use `clover` to identify which specific lines are not covered (per-line XML with hit counts), `html` for a visual line-by-line report, `text` for aggregate percentages only (does not identify uncovered lines). All file-based formats (`clover`, `cobertura`, `html`) also emit a text summary to the console. Default: `text`.
- `coverage_path` (string): Output path for the coverage report. Defaults: `clover`/`cobertura` → `coverage.xml`, `html` → `coverage/`. Not used for `text` format.
- `coverage_driver` (string): Coverage driver — `xdebug` injects `XDEBUG_MODE=coverage` (required for Xdebug 3), `pcov` relies on the pcov extension loaded in php.ini. Omit to use PHPUnit's own detection.
- `output_format` (string): Test output format — `default` (standard), `testdox` (human-readable descriptions), `result-only` (suppresses per-test progress and detailed results, showing only the final summary; PHPUnit 10+)
- `stop_on_failure` (boolean): Stop on first failure

### `phpunit_coverage_gaps`

Discover uncovered lines and methods from a Clover XML coverage report. Shows per-file coverage percentage, uncovered method names, and line ranges (worst coverage first). Paths are relative to the project root. Run `phpunit_run` with `coverage: true, coverage_format: "clover"` first.

```
Use phpunit_coverage_gaps
Use phpunit_coverage_gaps with source_filter "src/Core/Content/"
Use phpunit_coverage_gaps with clover_path "build/coverage.xml"
```

**Parameters:**
- `clover_path` (string, optional): Path to the Clover XML file generated by `phpunit_run`. Default: `coverage.xml`
- `source_filter` (string, optional): Only report files whose path contains this substring. Filters out framework base classes that leak into coverage (e.g., `AbstractFieldSerializer`, `CloneTrait`)

**Workflow:**
```
1. Use phpunit_run with coverage true, coverage_format "clover"
2. Use phpunit_coverage_gaps with source_filter "src/Core/"
```

### `console_run` / `console_list`

Execute Symfony console commands.

```
Use console_run with command "cache:clear"
Use console_run with command "plugin:install" arguments ["SwagPayPal"] options {"activate": true}
Use console_list with namespace "cache"
```

## Administration Tools Reference

Tools are available via the `js-admin-tooling` MCP server. No context parameter needed.

### `eslint_check` / `eslint_fix`

Run ESLint linting or auto-fix.

```
Use js-admin-tooling eslint_check
Use js-admin-tooling eslint_fix with paths ["src/app/component/"]
```

**Parameters:**
- `paths` (array): File paths or directories to lint
- `output_format` (string): `stylish`, `json`, or `compact`

### `stylelint_check` / `stylelint_fix`

Run Stylelint SCSS linting or auto-fix.

```
Use js-admin-tooling stylelint_check
Use js-admin-tooling stylelint_fix with paths ["src/**/*.scss"]
```

### `prettier_check` / `prettier_fix`

Check or auto-format with Prettier. Uses `npm run format` / `npm run format:fix` which runs with project-configured paths.

```
Use js-admin-tooling prettier_check
Use js-admin-tooling prettier_fix
```

### `jest_run`

Run Jest unit tests (single run, watch mode not supported).

```
Use js-admin-tooling jest_run
Use js-admin-tooling jest_run with testPathPattern "component"
Use js-admin-tooling jest_run with coverage true
```

**Parameters:**
- `testPathPattern` (string): Regex pattern for test file paths
- `testNamePattern` (string): Regex pattern for test names
- `coverage` (boolean): Generate code coverage report
- `updateSnapshots` (boolean): Update Jest snapshots

### `tsc_check`

Run TypeScript type checking. Uses `npm run lint:types` which runs with project tsconfig.

```
Use js-admin-tooling tsc_check
```

### `lint_all`

Run ALL lint checks (TypeScript, ESLint, Stylelint, Prettier) in one command. Ideal for pre-commit validation.

```
Use js-admin-tooling lint_all
```

### `lint_twig`

ESLint check for Twig templates (.html.twig files). Validates Admin Vue component templates.

```
Use js-admin-tooling lint_twig
```

### `unit_setup`

Regenerate component import resolver map. Run this when Jest tests fail with import/module resolution errors.

```
Use js-admin-tooling unit_setup
```

### `vite_build`

Build Administration assets with Vite.

```
Use js-admin-tooling vite_build
Use js-admin-tooling vite_build with mode "development"
```

**Parameters:**
- `mode` (string): `development` or `production`

## Storefront Tools Reference

Tools are available via the `js-storefront-tooling` MCP server. No context parameter needed.

> **Note**: Prettier and TypeScript tools are not available for Storefront (no npm scripts in package.json).

### `eslint_check` / `eslint_fix`

Run ESLint linting or auto-fix.

```
Use js-storefront-tooling eslint_check
Use js-storefront-tooling eslint_fix with paths ["src/plugin/"]
```

### `stylelint_check` / `stylelint_fix`

Run Stylelint SCSS linting or auto-fix.

```
Use js-storefront-tooling stylelint_check
Use js-storefront-tooling stylelint_fix with paths ["src/**/*.scss"]
```

### `jest_run`

Run Jest unit tests (single run, watch mode not supported).

```
Use js-storefront-tooling jest_run
Use js-storefront-tooling jest_run with testPathPattern "plugin"
```

### `webpack_build`

Build Storefront assets with Webpack.

```
Use js-storefront-tooling webpack_build
Use js-storefront-tooling webpack_build with mode "development"
```

**Parameters:**
- `mode` (string): `development` or `production`

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

This plugin includes PreToolUse hooks that block bash commands in favor of MCP tools. The hooks ensure Claude uses the proper MCP tools which handle environment detection, project configuration, and directory context automatically.

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
