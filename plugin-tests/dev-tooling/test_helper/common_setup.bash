#!/bin/bash
# Test fixtures for dev-tooling hook script testing

# Load shared core helper
load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

# Path to dev-tooling hook scripts
# shellcheck disable=SC2034  # consumed by individual *.bats files
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
    # shellcheck disable=SC2034  # consumed by sourced environment.sh / scope.sh / tool libs
    LINT_ENV="native"
    # shellcheck disable=SC2034  # consumed by sourced environment.sh / tool libs
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    # shellcheck disable=SC2034  # consumed by sourced scope.sh and config.sh
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    # shellcheck disable=SC2329  # stub invoked by sourced tool libs
    log() { :; }
    # shellcheck source=/dev/null
    source "${plugin_dir}/shared/environment.sh"
    # shellcheck source=/dev/null
    source "${plugin_dir}/shared/scope.sh"
    # shellcheck disable=SC2329  # stub invoked by sourced tool libs
    exec_command() { echo "$1"; }
    # shellcheck source=/dev/null
    source "${lib_path}"
}
