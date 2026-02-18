#!/bin/bash
# Test fixtures for dev-tooling hook script testing

# Load shared core helper
load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

# Path to dev-tooling hook scripts
SCRIPTS_DIR="${REPO_ROOT}/plugins/dev-tooling/hooks/scripts"

# Create temporary MCP config file
setup_config() {
    local prefix="$1"
    local content="$2"
    export CLAUDE_PROJECT_DIR="${BATS_TEST_TMPDIR}"
    echo "$content" > "${BATS_TEST_TMPDIR}/.mcp-${prefix}.json"
}

# Default setup - override CONFIG_PREFIX in test file
setup() {
    setup_config "${CONFIG_PREFIX:-php-tooling}" '{"environment": "native"}'
}

teardown() {
    unset CLAUDE_PROJECT_DIR
}

# Shared setup for PHP MCP tool tests.
# Sets LINT_ENV, LINT_WORKDIR, LINT_CONFIG_FILE, stubs log/exec_command,
# sources environment.sh, then sources the given tool library.
# Args: $1=PLUGIN_DIR path, $2=library path to source
setup_php_mcp_env() {
    local plugin_dir="$1" lib_path="$2"
    echo '{"environment":"native"}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    log() { :; }
    # shellcheck source=/dev/null
    source "${plugin_dir}/shared/environment.sh"
    exec_command() { echo "$1"; }
    # shellcheck source=/dev/null
    source "${lib_path}"
}

# Assert that a hook script blocks a command and suggests a specific MCP tool
# Args: $1=script name, $2=bash command, $3=expected suggestion substring
assert_hook_blocks() {
    local script="$1" command="$2" suggestion="$3"
    run_hook "$script" "$command"
    assert_failure 2
    assert_output --partial "$suggestion"
}
