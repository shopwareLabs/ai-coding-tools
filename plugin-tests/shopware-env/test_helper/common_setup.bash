#!/bin/bash
# Test fixtures for shopware-env hook and tool testing

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

PLUGIN_DIR="${REPO_ROOT}/plugins/shopware-env"
SCRIPTS_DIR="${PLUGIN_DIR}/hooks/scripts"

setup_config() {
    local prefix="$1"
    local content="$2"
    export CLAUDE_PROJECT_DIR="${BATS_TEST_TMPDIR}"
    printf '%s\n' "$content" > "${BATS_TEST_TMPDIR}/.mcp-${prefix}.json"
}

# Setup for MCP lifecycle tool tests.
# Stubs log/exec_command, sources environment.sh + resolve_env.sh, then
# sources the given tool library.
# Args: $1=library path to source
setup_lifecycle_mcp_env() {
    local lib_path="$1"
    printf '%s\n' '{"environment":"native"}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    LIFECYCLE_HAS_CONFIG="true"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    log() { :; }
    source "${PLUGIN_DIR}/shared/environment.sh"
    exec_command() { printf '%s\n' "$1"; }
    source "${PLUGIN_DIR}/mcp-server-lifecycle/lib/resolve_env.sh"
    source "${lib_path}"
}

setup() {
    setup_config "php-tooling" '{"environment": "native"}'
}

teardown() {
    unset CLAUDE_PROJECT_DIR
}
