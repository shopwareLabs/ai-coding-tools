@README.md

## Directory Structure

```
plugin-tests/
├── README.md                           # User documentation
├── AGENTS.md                           # LLM navigation guide (this file)
├── code-quality/
│   └── dev-tooling/                    # Tests for dev-tooling plugin hooks
│       ├── php_tools.bats              # PHPStan, ECS, PHPUnit, Console blocking
│       ├── js_admin_tools.bats         # Admin ESLint, Prettier, Jest, TSC blocking
│       ├── js_storefront_tools.bats    # Storefront ESLint, Jest, Webpack blocking
│       └── test_helper/
│           └── common_setup.bash       # Shared fixtures (run_hook, setup_config)
└── test_helper/
    └── common_setup.bash               # Core test helper (REPO_ROOT, make_hook_input)
```

## Testing Framework

Tests use BATS (Bash Automated Testing System) with these libraries:
- **bats-core** - Test runner
- **bats-support** - Helper functions
- **bats-assert** - Assertion library (`assert_success`, `assert_failure`, `assert_output`)

## Key Navigation Points

| Task | Primary File | Key Concepts |
|------|--------------|--------------|
| Add dev-tooling PHP test | `code-quality/dev-tooling/php_tools.bats` | `run_hook`, `setup_config` |
| Add dev-tooling JS test | `code-quality/dev-tooling/js_*.bats` | `run_hook`, `setup_config` |
| Modify test fixtures | `<plugin>/test_helper/common_setup.bash` | `make_hook_input`, `run_hook` |
| Add tests for new plugin | Create new `<category>/<plugin>/` directory | Follow template in README.md |

## Test Helper Functions

### `common_setup.bash` provides:

```bash
# Create JSON input for hook scripts
make_hook_input "command string"
# Returns: {"tool_input": {"command": "command string"}}

# Run hook script with command and capture result
run_hook "script.sh" "command to test"
# Sets: $status, $output

# Create temporary config file (dev-tooling only)
setup_config "php-tooling" '{"environment": "native"}'
# Creates: $BATS_TEST_TMPDIR/.mcp-php-tooling.json
```

### Path Calculation

All test helpers calculate `REPO_ROOT` as 3 levels up from the test directory:

```bash
# Path: plugin-tests/<category>/<plugin> -> 3 levels up
REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
```

Scripts under test are referenced via absolute paths from REPO_ROOT:

```bash
SCRIPTS_DIR="${REPO_ROOT}/plugins/<category>/<plugin>/hooks/scripts"
```

## Exit Codes

Hook scripts use these exit codes:
- `0` - Command allowed (pass through)
- `2` - Command blocked (with error message)

## When to Modify What

| Change | Files to Modify |
|--------|-----------------|
| New test case for existing plugin | Add `@test` block in `.bats` file |
| New plugin tests | Create `plugin-tests/<category>/<plugin>/` with test_helper and .bats files |
| New test fixture helper | Edit `test_helper/common_setup.bash` |
| CI test path changes | Edit `.github/workflows/test-hooks.yml` |

## Integration with Plugins

Tests validate hook scripts located in the plugins directory:

| Test Directory | Scripts Under Test |
|----------------|-------------------|
| `plugin-tests/dev-tooling/` | `plugins/dev-tooling/hooks/scripts/` |

## Running Tests Locally

```bash
# Install BATS (one-time)
./.github/scripts/setup-bats.sh

# Run all tests
.bats/bats-core/bin/bats plugin-tests/**/*.bats

# Run specific plugin tests
.bats/bats-core/bin/bats plugin-tests/code-quality/dev-tooling/*.bats
```
