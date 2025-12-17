# PHP Tooling

PHPStan, ECS (Easy Coding Standard), PHPUnit, and Symfony Console tools via MCP (Model Context Protocol). Supports multiple development environments with auto-detection.

## Features

- **PHPStan** static analysis via `phpstan_analyze` tool
- **ECS** code style checking via `ecs_check` and `ecs_fix` tools
- **PHPUnit** test execution via `phpunit_run` tool
- **Symfony Console** command execution via `console_run` tool
- **Multi-environment support**: native, docker, vagrant, ddev
- **Flexible configuration**: environment variable, project root, or LLM tool directories
- **Cross-tool support**: config discovery in `.claude/`, `.cursor/`, `.windsurf/`, `.zed/`, `.cline/`, `.aiassistant/`, `.amazonq/`, `.kiro/`
- **Config merging**: multiple config files are deep-merged (later locations override earlier)

## Quick Start

### Installation

```bash
/plugin install php-tooling@shopware-plugins
```

**IMPORTANT**: Restart Claude Code after installation for the MCP server to initialize.

### Verification

After restarting, verify the MCP server is running:

```bash
/mcp
```

You should see `php-tooling` listed as a connected server.

## Usage

### PHPStan Analysis

Run static analysis on PHP code:

```
Use the phpstan_analyze tool to check src/Core/Content/Product/ProductEntity.php
```

With options:
```
Use phpstan_analyze with paths ["src/Core/"] and level 8
```

### ECS Code Style Check

Check for coding standard violations (dry-run):

```
Use the ecs_check tool to check src/Core/Content/Product/
```

### ECS Fix

Auto-fix coding standard violations:

```
Use the ecs_fix tool to fix src/Core/Content/Product/ProductEntity.php
```

### PHPUnit Tests

Run unit tests:

```
Use the phpunit_run tool with testsuite "unit"
```

Run integration tests:

```
Use the phpunit_run tool with testsuite "integration"
```

Run specific test file:

```
Use phpunit_run with paths ["tests/unit/Core/Checkout/Cart/CartServiceTest.php"]
```

Run tests matching a pattern:

```
Use phpunit_run with filter "testAddProduct"
```

### Symfony Console Commands

Run any Symfony console command:

```
Use the console_run tool with command "cache:clear"
```

With options:
```
Use console_run with command "theme:compile" and options {"sync": true}
```

Install a plugin:
```
Use console_run with command "plugin:install" arguments ["SwagPayPal"] and options {"activate": true}
```

Run in production environment:
```
Use console_run with command "cache:clear" env "prod" and no_debug true
```

### Discover Available Commands

List all available console commands:

```
Use the console_list tool
```

Filter by namespace:
```
Use console_list with namespace "cache"
```

Get commands in JSON format:
```
Use console_list with namespace "plugin" and format "json"
```

## Configuration

### Configuration Priority

Configuration is loaded in the following priority order:

1. **Environment variable**: `MCP_PHP_TOOLING_CONFIG` (absolute path to config file)
2. **Config file discovery** (checked in order, deep-merged if multiple exist):
   - `.mcp-php-tooling.json` (project root, base config)
   - `.aiassistant/.mcp-php-tooling.json` (JetBrains AI Assistant)
   - `.amazonq/.mcp-php-tooling.json` (Amazon Q Developer)
   - `.cline/.mcp-php-tooling.json` (Cline)
   - `.cursor/.mcp-php-tooling.json` (Cursor AI)
   - `.kiro/.mcp-php-tooling.json` (Kiro)
   - `.windsurf/.mcp-php-tooling.json` (Windsurf/Codeium)
   - `.zed/.mcp-php-tooling.json` (Zed editor)
   - `.claude/.mcp-php-tooling.json` (override, highest priority)

If multiple config files exist, they are deep-merged: nested objects are recursively merged, with later files overriding earlier ones.

### Config File

Create `.mcp-php-tooling.json` at project root or in any supported LLM tool directory (e.g., `.claude/`, `.cursor/`, `.windsurf/`).

This file should NOT be committed (add to `.gitignore`).

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

### Configuration Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `environment` | string | **required** | `native`, `docker`, `vagrant`, or `ddev` |
| `docker.container` | string | **required** | Docker container name |
| `docker.workdir` | string | `/var/www/html` | Working directory in container |
| `vagrant.workdir` | string | `/vagrant` | Working directory in VM |
| `ddev.workdir` | string | `/var/www/html` | Working directory in DDEV |
| `phpstan.config` | string | - | PHPStan config file |
| `phpstan.memory_limit` | string | - | Memory limit for PHPStan |
| `ecs.config` | string | - | ECS/PHP-CS-Fixer config file |
| `phpunit.testsuite` | string | - | Default test suite to run |
| `phpunit.config` | string | - | PHPUnit config file |
| `console.env` | string | - | Default Symfony environment (`dev`, `prod`, `test`) |
| `console.verbosity` | string | - | Default verbosity (`quiet`, `normal`, `verbose`, `very-verbose`, `debug`) |
| `console.no_debug` | boolean | - | Disable debug mode by default |
| `console.no_interaction` | boolean | - | Non-interactive mode by default |

## Tools Reference

### `phpstan_analyze`

Run PHPStan static analysis.

**Parameters:**
- `paths` (array, optional): File paths or directories to analyze
- `level` (integer 0-9, optional): Analysis strictness level
- `error_format` (string, optional): Output format (`json`, `table`, `raw`)

**Example:**
```json
{
  "paths": ["src/Core/Content/Product/"],
  "level": 8,
  "error_format": "json"
}
```

### `ecs_check`

Check PHP files for coding standard violations.

**Parameters:**
- `paths` (array, optional): File paths or directories to check
- `output_format` (string, optional): Output format (`text`, `json`)

### `ecs_fix`

Fix PHP coding standard violations.

**Parameters:**
- `paths` (array, optional): File paths or directories to fix

### `phpunit_run`

Run PHPUnit tests with support for multiple test suites, filtering, and coverage.

**Parameters:**
- `testsuite` (string, optional): Test suite to run. Falls back to `.mcp-php-tooling.json` `phpunit.testsuite` if not provided. Options: `unit`, `integration`, `migration`, `devops`, `core-framework-batch1`, `core-framework-batch2`, `core-framework-batch3`
- `paths` (array, optional): Specific test file(s) or directories. Overrides testsuite when provided
- `filter` (string, optional): Filter tests by name pattern (--filter)
- `config` (string, optional): PHPUnit config file path. Falls back to `.mcp-php-tooling.json` `phpunit.config` if not provided
- `stop_on_failure` (boolean, optional): Stop execution on first failure
- `coverage` (boolean, optional): Generate code coverage report (requires PCOV/Xdebug)
- `coverage_format` (string, optional): Coverage output format. Options: `text`, `html`, `clover`, `cobertura`
- `output_format` (string, optional): Test output format. Options: `default`, `testdox`

**Examples:**
```json
// Run unit tests (requires testsuite in .mcp-php-tooling.json or explicit parameter)
{"testsuite": "unit"}

// Run integration tests
{"testsuite": "integration"}

// Run specific test file
{"paths": ["tests/unit/Core/Checkout/Cart/CartServiceTest.php"]}

// Run multiple test files
{"paths": ["tests/unit/Core/Checkout/Cart/CartServiceTest.php", "tests/unit/Core/Checkout/Cart/LineItemTest.php"]}

// Run all tests in a directory
{"paths": ["tests/unit/Core/Checkout/"]}

// Run tests in multiple directories
{"paths": ["tests/unit/Core/Checkout/", "tests/unit/Core/Content/"]}

// Filter by test method name
{"testsuite": "unit", "filter": "testAddProduct"}

// Filter by test class name
{"testsuite": "unit", "filter": "CartServiceTest"}

// Filter with regex pattern (methods starting with "testAdd")
{"testsuite": "unit", "filter": "testAdd.*"}

// Combine paths with filter
{"paths": ["tests/unit/Core/Checkout/"], "filter": "testCalculate"}

// Run with stop on failure
{"testsuite": "integration", "stop_on_failure": true}

// Generate coverage report
{"testsuite": "unit", "coverage": true, "coverage_format": "text"}

// Use custom config file
{"testsuite": "unit", "config": "phpunit.xml.dist"}
```

### `console_run`

Execute Symfony console commands with full argument and option support.

**Parameters:**
- `command` (string, required): Console command name (e.g., `cache:clear`, `theme:compile`)
- `arguments` (array, optional): Positional arguments for the command
- `options` (object, optional): Command options as key-value pairs
  - Boolean `true` becomes `--flag`
  - String becomes `--key=value`
  - Array becomes multiple `--key=value1 --key=value2`
- `env` (string, optional): Symfony environment (`dev`, `prod`, `test`)
- `verbosity` (string, optional): Output verbosity (`quiet`, `normal`, `verbose`, `very-verbose`, `debug`)
- `no_debug` (boolean, optional): Disable debug mode
- `no_interaction` (boolean, optional): Non-interactive mode

**Examples:**
```json
// Clear cache
{"command": "cache:clear"}

// Clear cache in production without debug
{"command": "cache:clear", "env": "prod", "no_debug": true}

// Compile theme with sync option
{"command": "theme:compile", "options": {"sync": true}}

// Install a plugin
{"command": "plugin:install", "arguments": ["MyPlugin"], "options": {"activate": true}}

// Run migrations with verbose output
{"command": "database:migrate", "options": {"all": true}, "verbosity": "verbose"}

// Generate entities for specific bundle
{"command": "dal:create:entities", "arguments": ["MyCustomBundle"]}

// Refresh plugins with activation
{"command": "plugin:refresh", "no_interaction": true}

// Scheduled task with specific task
{"command": "scheduled-task:run", "arguments": ["scheduled_task_name"]}

// Change theme for all sales channels
{"command": "theme:change", "options": {"sync": true, "all": true}, "arguments": ["Storefront"]}
```

**Configuration:**
Add console defaults to `.mcp-php-tooling.json`:
```json
{
  "console": {
    "env": "dev",
    "no_interaction": true
  }
}
```

### `console_list`

List available Symfony console commands with optional namespace filtering. Returns concise LLM-optimized output by default.

**Parameters:**
- `namespace` (string, optional): Filter by command namespace (e.g., `cache`, `theme`, `plugin`, `database`)
- `format` (string, optional): Output format. Default: `llm`
  - `llm` - Concise grouped format optimized for LLM consumption (default)
  - `txt` - Symfony text format (human-readable)
  - `json` - Full JSON with all command metadata
  - `xml` - XML format
  - `md` - Markdown format

**LLM Format Output:**
```
[cache]
  cache:clear: Clear the cache
  cache:warmup: Warm up an empty cache

[theme]
  theme:compile: Compile the theme
  theme:change: Change active theme
```

**Examples:**
```json
// List all commands (LLM-optimized format)
{}

// List cache commands only
{"namespace": "cache"}

// List plugin commands in raw JSON format
{"namespace": "plugin", "format": "json"}

// List theme commands
{"namespace": "theme"}

// List all commands in Symfony text format
{"format": "txt"}
```

## Integration with Other Plugins

Other plugins can use the PHP linting tools by referencing them in their tool lists:

```markdown
---
tools: mcp__php-tooling__phpstan_analyze, mcp__php-tooling__ecs_check, mcp__php-tooling__ecs_fix, mcp__php-tooling__phpunit_run, mcp__php-tooling__console_run, mcp__php-tooling__console_list
---

After generating code, run PHPStan analysis, ECS check, PHPUnit tests, and console commands.
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

### Command Execution Fails

1. Verify the environment configuration in `.mcp-php-tooling.json`
2. Verify the detected command wrapper is correct
3. Check if tools are installed in the target environment

## Dependencies

- **bash** (4.0+)
- **jq** (JSON processor)
- **PHPStan** (installed in project)
- **PHP-CS-Fixer/ECS** (installed in project)
- **PHPUnit** (installed in project)

## License

MIT
