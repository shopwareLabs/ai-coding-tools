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
