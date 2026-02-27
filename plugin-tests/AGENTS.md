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
| Add gh-tooling hook test | `gh-tooling/gh_tools.bats` | `run_hook`, `setup_config` |
| Add gh-tooling MCP tool test | `gh-tooling/mcp_tool_gh.bats` | `gh` stub function, tool functions |
| Add shared core test | `dev-tooling/extra_log_file.bats` or `environment.bats` | Source shared module directly |
| Modify test fixtures | `<plugin>/test_helper/common_setup.bash` | `make_hook_input`, `run_hook` |
| Add tests for new plugin | Create new `<plugin>/` directory | Follow template in README.md |

## Test Helper Functions

### `common_setup.bash` provides:

```bash
# Create JSON input for hook scripts
make_hook_input "command string"
# Returns: {"tool_input": {"command": "command string"}}

# Run hook script with command and capture result
run_hook "script.sh" "command to test"
# Sets: $status, $output

# Create temporary config file (dev-tooling and gh-tooling)
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
| CI test path changes | Edit `.github/workflows/test-hooks.yml` |

## Integration with Plugins

Tests validate scripts and shared modules located in the plugins directory:

| Test Directory | Scripts Under Test |
|----------------|-------------------|
| `plugin-tests/dev-tooling/` | `plugins/dev-tooling/hooks/scripts/`, `plugins/dev-tooling/shared/`, `plugins/dev-tooling/mcp-server-*/lib/` |
| `plugin-tests/gh-tooling/` | `plugins/gh-tooling/hooks/scripts/`, `plugins/gh-tooling/shared/`, `plugins/gh-tooling/mcp-server-gh/lib/` |
