# Dev Tooling

Development tools for PHP and JavaScript via MCP (Model Context Protocol). Provides PHPStan, ECS, PHPUnit, Symfony Console, ESLint, Stylelint, Prettier, Jest, TypeScript, and build tools. Supports multiple development environments with auto-detection.

## Features

### PHP Tools (php-tooling MCP Server)
- **PHPStan** static analysis via `phpstan_analyze`
- **ECS** code style checking via `ecs_check` and `ecs_fix`
- **PHPUnit** test execution via `phpunit_run`
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
| `console.env` | string | - | Default Symfony environment (`dev`, `prod`, `test`) |
| `console.verbosity` | string | - | Output verbosity (`quiet`, `normal`, `verbose`, `very-verbose`, `debug`) |
| `console.no_debug` | boolean | - | Disable debug mode by default |
| `console.no_interaction` | boolean | - | Non-interactive mode by default |

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
- `stop_on_failure` (boolean): Stop on first failure

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

## License

MIT
