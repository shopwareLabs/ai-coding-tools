# Plugin Tests

BATS tests for Claude Code plugin hook scripts.

## Quick Start

### Setup

```bash
./.github/scripts/setup-bats.sh
```

### Run Tests

```bash
# All tests
.bats/bats-core/bin/bats plugin-tests/**/*.bats

# Specific plugin
.bats/bats-core/bin/bats plugin-tests/code-quality/dev-tooling/*.bats

# With timing
.bats/bats-core/bin/bats --timing plugin-tests/**/*.bats

# Filter by tag
.bats/bats-core/bin/bats --filter-tags blocking plugin-tests/
```

### Available Tags

| Tag | Description |
|-----|-------------|
| `blocking` | Tests that verify commands are blocked |
| `allow` | Tests that verify commands are allowed |
| `config` | Tests for configuration behavior |
| `context` | Tests for context detection |

## Directory Structure

```
plugin-tests/
├── test_helper/
│   └── common_setup.bash           # Shared core fixtures
├── code-quality/
│   └── dev-tooling/
│       ├── php_tools.bats
│       ├── js_admin_tools.bats
│       ├── js_storefront_tools.bats
│       └── test_helper/
│           └── common_setup.bash   # Plugin-specific fixtures
└── test_helper/
    └── common_setup.bash           # Core test helper
```

## Adding Tests

1. Create directory: `plugin-tests/<category>/<plugin-name>/`
2. Create helper: `test_helper/common_setup.bash`
3. Add test files: `<feature>.bats`

### Helper Template

```bash
#!/bin/bash
load "${BATS_TEST_DIRNAME}/../../test_helper/common_setup"
SCRIPTS_DIR="${REPO_ROOT}/plugins/<category>/<plugin-name>/hooks/scripts"
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

## CI

Tests run via GitHub Actions on changes to `plugins/**/hooks/**` or `plugin-tests/**`.

## Dependencies

- bash (4.0+)
- jq
- git
