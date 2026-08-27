# Plugin Tests

BATS tests for Claude Code plugin hook scripts, MCP tool functions, and shared modules.

## ⚡ Quick Start

### Setup

```bash
./.github/scripts/setup-bats.sh
```

### Run Tests

```bash
# All tests
.bats/bats-core/bin/bats plugin-tests/**/*.bats

# Specific plugin
.bats/bats-core/bin/bats plugin-tests/dev-tooling/*.bats

# With timing
.bats/bats-core/bin/bats --timing plugin-tests/**/*.bats

# Filter by tag
.bats/bats-core/bin/bats --filter-tags blocking plugin-tests/
```

### Available Tags

| Tag        | Description                            |
|------------|----------------------------------------|
| `blocking` | Tests that verify commands are blocked |
| `allow`    | Tests that verify commands are allowed |
| `config`   | Tests for configuration behavior       |
| `context`  | Tests for context detection            |

## 🗂️ Directory Structure

```
plugin-tests/
├── test_helper/
│   └── common_setup.bash               # Shared core fixtures
├── mcp-shared/                          # Suites for templates/mcp-shared/ modules
│   ├── docker_compose.bats             # Docker Compose call-time container/workdir resolution
│   ├── environment.bats                 # Environment wrapping
│   ├── extra_log_file.bats             # Extra log file and dual-write log()
│   ├── mcp_argument_validation.bats    # MCP JSON-RPC argument validation
│   └── scope_wrap.bats                 # Scope-aware command wrapping per environment
├── dev-tooling/
│   ├── php_tools.bats                  # PHP hook blocking
│   ├── js_admin_tools.bats            # Admin JS hook blocking
│   ├── js_storefront_tools.bats       # Storefront JS hook blocking
│   ├── mcp_tool_console.bats          # Console tool tests
│   ├── mcp_tool_ecs.bats             # ECS tool tests
│   ├── mcp_tool_js_admin.bats        # Admin JS MCP tool tests
│   ├── mcp_tool_js_storefront.bats   # Storefront JS MCP tool tests
│   ├── mcp_tool_phpstan.bats         # PHPStan tool tests
│   ├── mcp_tool_phpunit.bats         # PHPUnit tool tests
│   ├── mcp_tool_phpunit_coverage.bats # PHPUnit coverage gap analysis tests
│   ├── fixtures/
│   │   └── coverage/                  # XML fixtures for coverage gap tests
│   │       ├── two_files.xml          # Two files with partial coverage
│   │       ├── all_covered.xml        # Fully covered file
│   │       ├── method_lines.xml       # Uncovered method-type lines
│   │       └── mixed_coverage.xml     # Mix of covered and uncovered files
│   └── test_helper/
│       └── common_setup.bash          # Plugin-specific fixtures
├── shopware-env/
│   ├── config_fallback.bats
│   ├── hook_enforcement.bats
│   ├── lifecycle_tools.bats
│   ├── session_start.bats
│   └── test_helper/
│       └── common_setup.bash
├── test-writing/
│   ├── build_rule_package.bats
│   ├── build-run-script.bats
│   ├── review_unit.bats
│   ├── selection_equivalence.bats
│   ├── validate_review_unit_script.bats
│   └── test_helper/
│       └── common_setup.bash
├── shopware-documentation/
│   ├── measure_cli.bats
│   ├── measure_links.bats
│   ├── measure_size.bats
│   ├── fixtures/
│   └── test_helper/
│       └── common_setup.bash
└── chunkhound-integration/
    ├── sweep.bats
    └── test_helper/
        └── common_setup.bash
```

## 🏗️ Adding Tests

1. Create directory: `plugin-tests/<plugin-name>/`
2. Create helper: `test_helper/common_setup.bash`
3. Add test files: `<feature>.bats`

### Helper Template

```bash
#!/bin/bash
load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"
SCRIPTS_DIR="${REPO_ROOT}/plugins/<plugin-name>/hooks/scripts"
```

### Test Template

```bash
#!/usr/bin/env bats
# bats file_tags=<plugin-name>

load 'test_helper/common_setup'

# bats test_tags=blocking
@test "blocks forbidden command" {
    run_hook "check-script.sh" "forbidden-command"
    assert_failure 2
    assert_output --partial "Use proper tool"
}
```

## 🔄 CI

Tests run via GitHub Actions (`.github/workflows/ci.yml`) on changes to `plugins/**`, `plugin-tests/**`, `pyproject.toml`, `uv.lock`, `.shellcheckrc`, `.github/workflows/ci.yml`, or `.github/scripts/**`.

## 📌 Dependencies

- bash (4.0+)
- jq
- git
- ugrep
