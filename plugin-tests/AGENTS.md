@README.md

## Testing Framework

Tests use BATS (Bash Automated Testing System) with these libraries:
- **bats-core** - Test runner
- **bats-support** - Helper functions
- **bats-assert** - Assertion library (`assert_success`, `assert_failure`, `assert_output`)

## Key Navigation Points

| Task | Primary File | Key Concepts |
|------|--------------|--------------|
| Add dev-tooling hook test | `dev-tooling/php_tools.bats` or `js_*.bats` | `run_hook`, `setup_config` |
| Add dev-tooling MCP tool test | `dev-tooling/mcp_tool_*.bats` | `setup_php_mcp_env`, tool function stubs |
| Add coverage gap test fixture | `dev-tooling/fixtures/coverage/*.xml` | Clover XML format, loaded via `$(< file)` in `setup()` |
| Add shared core test | `mcp-shared/extra_log_file.bats` or `mcp-shared/environment.bats` | Source `templates/mcp-shared/<file>` directly |
| Modify test fixtures | `<plugin>/test_helper/common_setup.bash` | `run_hook`, `assert_hook_blocks` |
| Add tests for new plugin | Create new `<plugin>/` directory | Follow template in README.md |

## Test Helper Functions

### `common_setup.bash` provides:

```bash
# Run hook script with command and capture result
# Note: SCRIPTS_DIR must be set by the plugin-specific helper
run_hook "script.sh" "command to test"
# Sets: $status, $output

# Assert a hook script blocks a command with an expected suggestion
assert_hook_blocks "script.sh" "command to test" "expected suggestion"
# Asserts: exit status 2, output contains the suggestion

# Create temporary config file (dev-tooling)
setup_config "php-tooling" '{"environment": "native"}'
# Creates: $BATS_TEST_TMPDIR/.mcp-php-tooling.json
```

### Path Calculation

Test helpers calculate `REPO_ROOT` by walking up from the test directory until `.bats/` is found:

```bash
_get_repo_root() {
    local test_dir="${BATS_TEST_DIRNAME}"
    while [[ ! -d "${test_dir}/.bats" ]] && [[ "${test_dir}" != "/" ]]; do
        test_dir="$(dirname "$test_dir")"
    done
    echo "$test_dir"
}
```

Scripts under test are referenced via absolute paths from REPO_ROOT:

```bash
SCRIPTS_DIR="${REPO_ROOT}/plugins/<plugin>/hooks/scripts"
```

## Exit Codes

Hook scripts use these exit codes:
- `0` - Command allowed (pass through)
- `2` - Command blocked (with error message)

## When to Modify What

| Change | Files to Modify |
|--------|-----------------|
| New test case for existing plugin | Add `@test` block in `.bats` file |
| New plugin tests | Create `plugin-tests/<plugin>/` with test_helper and .bats files |
| New test fixture helper | Edit `test_helper/common_setup.bash` |
| CI test path changes | Edit `.github/workflows/ci.yml` |

## Integration with Plugins

Tests validate scripts and shared modules located in the plugins directory:

| Test Directory            | Scripts Under Test                                                                                     |
|---------------------------|--------------------------------------------------------------------------------------------------------|
| `plugin-tests/dev-tooling/` | `plugins/dev-tooling/hooks/scripts/`, `plugins/dev-tooling/shared/`, `plugins/dev-tooling/mcp-server-*/lib/` |
| `plugin-tests/mcp-shared/`  | `templates/mcp-shared/` — sourced directly, never a plugin copy, so one suite covers every consumer      |
