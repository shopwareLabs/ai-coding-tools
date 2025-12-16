# PHP Tooling

PHPStan, ECS (Easy Coding Standard), and PHPUnit tools via MCP (Model Context Protocol). Supports multiple development environments with auto-detection.

## Features

- **PHPStan** static analysis via `phpstan_analyze` tool
- **ECS** code style checking via `ecs_check` and `ecs_fix` tools
- **PHPUnit** test execution via `phpunit_run` tool
- **Multi-environment support**: native, docker, vagrant, ddev
- **Configuration** via `.lintrc.local.json` (required)

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

## Configuration

### `.lintrc.local.json`

Create this file in your project root to configure the linting environment. This file should NOT be committed (add to `.gitignore`).

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
- `testsuite` (string, optional): Test suite to run. Falls back to `.lintrc.local.json` `phpunit.testsuite` if not provided. Options: `unit`, `integration`, `migration`, `devops`, `core-framework-batch1`, `core-framework-batch2`, `core-framework-batch3`
- `paths` (array, optional): Specific test file(s) or directories. Overrides testsuite when provided
- `filter` (string, optional): Filter tests by name pattern (--filter)
- `config` (string, optional): PHPUnit config file path. Falls back to `.lintrc.local.json` `phpunit.config` if not provided
- `stop_on_failure` (boolean, optional): Stop execution on first failure
- `coverage` (boolean, optional): Generate code coverage report (requires PCOV/Xdebug)
- `coverage_format` (string, optional): Coverage output format. Options: `text`, `html`, `clover`, `cobertura`
- `output_format` (string, optional): Test output format. Options: `default`, `testdox`

**Examples:**
```json
// Run unit tests (requires testsuite in .lintrc.local.json or explicit parameter)
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

## Integration with Other Plugins

Other plugins can use the PHP linting tools by referencing them in their tool lists:

```markdown
---
tools: mcp__php-tooling__phpstan_analyze, mcp__php-tooling__ecs_check, mcp__php-tooling__ecs_fix, mcp__php-tooling__phpunit_run
---

After generating code, run PHPStan analysis, ECS check, and PHPUnit tests.
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

1. Verify the environment configuration in `.lintrc.local.json`
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
