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
.bats/bats-core/bin/bats --filter-tags blocking -r plugin-tests/
```

`plugin-tests/` holds no `.bats` file directly, so a run that names the directory needs `-r` to descend into the per-plugin subdirectories. Without it bats reports `1..0` and exits 0 — a filter that selects nothing looks exactly like a filter that passed.

### Tags

Tags come in two kinds, and `--filter-tags` matches both.

| Kind        | Declared                        | Scope                    | Convention                                                                                        |
|-------------|---------------------------------|--------------------------|---------------------------------------------------------------------------------------------------|
| `file_tags` | `# bats file_tags=a,b` in the header, above `bats_require_minimum_version` | Every `@test` in the file | Owning plugin plus subject — `dev-tooling,scope`, `test-writing,review-unit`. Suites under `mcp-shared/` use `mcp-core` in place of a plugin name, because their subject belongs to no single plugin. |
| `test_tags` | `# bats test_tags=a,b` directly above one `@test` | That `@test` only        | The behavior class being exercised, not the subject                                               |

Current `test_tags` vocabulary: `allow`, `base-scripts`, `blocking`, `config`, `context`, `cwd`, `neon-baseline`, `output`, `paths`, `php-baseline`, `priority`, `skip`.

`file_tags` values track the tree and are not listed here. Enumerate the live set with:

```bash
ugrep -rho '# bats file_tags=.*' plugin-tests | cut -d= -f2 | tr ',' '\n' | sort -u
```

## 🗂️ Directory Structure

```
plugin-tests/
├── test_helper/
│   └── common_setup.bash               # Shared core fixtures
├── mcp-shared/                          # Suites for templates/mcp-shared/ modules
│   ├── config.bats                      # Config filename and env-var prefix parameterization
│   ├── docker_compose.bats             # Docker Compose call-time container/workdir resolution
│   ├── environment.bats                 # Environment wrapping
│   ├── extra_log_file.bats             # Extra log file and dual-write log()
│   ├── mcp_argument_validation.bats    # MCP JSON-RPC argument validation
│   └── scope_wrap.bats                 # Scope-aware command wrapping per environment
├── dev-tooling/
│   ├── php_tools.bats                  # PHP hook blocking
│   ├── js_admin_tools.bats            # Admin JS hook blocking
│   ├── js_storefront_tools.bats       # Storefront JS hook blocking
│   ├── lsp_bootstrap.bats             # LSP bootstrap: null stub, direct exec or python proxy
│   ├── lsp_null.bats                  # The minimal LSP stub used when an LSP is disabled
│   ├── mcp_tool_console.bats          # Console tool tests
│   ├── mcp_tool_ecs.bats             # ECS tool tests
│   ├── mcp_tool_js_admin.bats        # Admin JS MCP tool tests
│   ├── mcp_tool_js_storefront.bats   # Storefront JS MCP tool tests
│   ├── mcp_tool_phpstan.bats         # PHPStan tool tests
│   ├── mcp_tool_phpunit.bats         # PHPUnit tool tests
│   ├── mcp_tool_phpunit_coverage.bats # PHPUnit coverage gap analysis tests
│   ├── mcp_tool_rector.bats           # Rector tool tests
│   ├── phpstan_baseline.bats          # PHPStan .php and .neon baseline entry matching
│   ├── scope_js_tools.bats            # Scoped runs of the JS tools
│   ├── scope_php_tools.bats           # Scoped runs of the PHP tools
│   ├── scope_resolution.bats          # Scope declaration, validation and refusal
│   ├── scope_session_start.bats       # Scope reporting from the session-start hook
│   ├── session_start.bats             # Session-start hook JSON output
│   ├── lsp_proxy/                     # pytest suite for shared/lsp_proxy.py
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
│   ├── surviving_tests.bats
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

Every `.bats` file declares `bats_require_minimum_version 1.11.0` below the tag header — all 38 on disk do, and the tag syntax the suite relies on is only guaranteed from that version.

```bash
#!/usr/bin/env bats
# bats file_tags=<plugin-name>,<feature>
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

# bats test_tags=blocking
@test "blocks forbidden command" {
    run_hook "check-script.sh" "forbidden-command"
    assert_failure 2
    assert_output --partial "Use proper tool"
}
```

Suites under `mcp-shared/` differ in two places, because that directory has no helper of its own and its subject belongs to no single plugin:

```bash
#!/usr/bin/env bats
# bats file_tags=mcp-core,<feature>
bats_require_minimum_version 1.11.0

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

setup() {
    log() { :; }
    source "${REPO_ROOT}/templates/mcp-shared/<file>.sh"
}
```

Source the template at `templates/mcp-shared/<file>.sh` directly, never a plugin copy. The template-sync check in `.github/workflows/validate.yml` keeps every copy byte-identical, so one suite covers the module in all consuming plugins.

## 🔄 CI

Tests run via GitHub Actions (`.github/workflows/ci.yml`) on changes to `plugins/**`, `plugin-tests/**`, `pyproject.toml`, `uv.lock`, `.shellcheckrc`, `.github/workflows/ci.yml`, or `.github/scripts/**`.

## 📌 Dependencies

- bash (4.0+)
- jq
- git
- ugrep
