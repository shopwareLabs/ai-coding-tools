#!/bin/bash
# Test fixtures for gh-tooling hook script testing

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

SCRIPTS_DIR="${REPO_ROOT}/plugins/gh-tooling/hooks/scripts"

setup_config() {
    local prefix="$1"
    local content="$2"
    export CLAUDE_PROJECT_DIR="${BATS_TEST_TMPDIR}"
    echo "$content" > "${BATS_TEST_TMPDIR}/.mcp-${prefix}.json"
}

# Default setup - override CONFIG_PREFIX in test file
setup() {
    setup_config "${CONFIG_PREFIX:-gh-tooling}" '{"enforce_mcp_tools": true}'
}

teardown() {
    unset CLAUDE_PROJECT_DIR
}

# Assert that a hook script blocks a command and suggests a specific MCP tool
# Args: $1=script name, $2=bash command, $3=expected suggestion substring
assert_hook_blocks() {
    local script="$1" command="$2" suggestion="$3"
    run_hook "$script" "$command"
    assert_failure 2
    assert_output --partial "$suggestion"
}
