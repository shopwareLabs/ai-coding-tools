#!/bin/bash
# Test fixtures for dev-tooling hook script testing

# Load shared core helper
load "${BATS_TEST_DIRNAME}/../../test_helper/common_setup"

# Path to dev-tooling hook scripts
SCRIPTS_DIR="${REPO_ROOT}/plugins/code-quality/dev-tooling/hooks/scripts"

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
