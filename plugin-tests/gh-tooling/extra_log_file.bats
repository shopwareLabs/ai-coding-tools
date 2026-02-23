#!/usr/bin/env bats
# bats file_tags=gh-tooling,extra-log
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/gh-tooling"

setup() {
    MCP_LOG_FILE="${BATS_TEST_TMPDIR}/server.log"
    MCP_EXTRA_LOG_FILE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    MCP_CONFIG_FILE="/dev/null"
    MCP_TOOLS_LIST_FILE="/dev/null"
    export MCP_LOG_FILE MCP_EXTRA_LOG_FILE PROJECT_ROOT MCP_CONFIG_FILE MCP_TOOLS_LIST_FILE
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/shared/mcpserver_core.sh"
}

teardown() {
    unset MCP_LOG_FILE MCP_EXTRA_LOG_FILE PROJECT_ROOT MCP_CONFIG_FILE MCP_TOOLS_LIST_FILE
}

# --- _configure_extra_log_file ---

@test "_configure_extra_log_file: empty path is a no-op" {
    _configure_extra_log_file ""
    [[ -z "$MCP_EXTRA_LOG_FILE" ]]
}

@test "_configure_extra_log_file: relative path resolves against PROJECT_ROOT" {
    mkdir -p "${BATS_TEST_TMPDIR}/subdir"
    _configure_extra_log_file "subdir/debug.log"
    [[ "$MCP_EXTRA_LOG_FILE" == "${BATS_TEST_TMPDIR}/subdir/debug.log" ]]
}

@test "_configure_extra_log_file: absolute path used as-is" {
    _configure_extra_log_file "/tmp/bats-test-mcp.log"
    [[ "$MCP_EXTRA_LOG_FILE" == "/tmp/bats-test-mcp.log" ]]
}

@test "_configure_extra_log_file: non-existent parent dir warns and skips" {
    _configure_extra_log_file "nonexistent/debug.log"
    [[ -z "$MCP_EXTRA_LOG_FILE" ]]
    run grep "WARN" "${BATS_TEST_TMPDIR}/server.log"
    assert_success
    assert_output --partial "log_file parent directory does not exist"
}

# --- log() dual-write ---

@test "log: writes to both files when extra log configured" {
    local extra="${BATS_TEST_TMPDIR}/extra.log"
    MCP_EXTRA_LOG_FILE="$extra"
    log "INFO" "dual write test"
    run grep "dual write test" "${BATS_TEST_TMPDIR}/server.log"
    assert_success
    run grep "dual write test" "$extra"
    assert_success
}

@test "log: writes only to MCP_LOG_FILE when no extra log" {
    local extra="${BATS_TEST_TMPDIR}/extra.log"
    MCP_EXTRA_LOG_FILE=""
    log "INFO" "single write test"
    run grep "single write test" "${BATS_TEST_TMPDIR}/server.log"
    assert_success
    [[ ! -f "$extra" ]]
}
