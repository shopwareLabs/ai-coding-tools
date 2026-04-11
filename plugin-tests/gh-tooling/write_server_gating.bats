#!/usr/bin/env bats
# bats file_tags=gh-tooling,write-server,gating
# Tests that the write server respects enable_write_server config flag
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/gh-tooling"
SERVER_SCRIPT="${PLUGIN_DIR}/mcp-server-gh/server-write.sh"

# Helper: send a JSON-RPC request
send_jsonrpc() {
    local method="$1"
    local id="${2:-1}"
    local params="${3:-{}}"
    printf '{"jsonrpc":"2.0","id":%d,"method":"%s","params":%s}\n' "$id" "$method" "$params"
}

# Helper: run the server with a config and a request, capture last response
run_server_request() {
    local config_json="$1"
    local method="$2"

    export CLAUDE_PROJECT_DIR="${BATS_TEST_TMPDIR}"
    export PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    if [[ -n "${config_json}" ]]; then
        echo "${config_json}" > "${BATS_TEST_TMPDIR}/.mcp-gh-tooling.json"
    fi

    local requests
    requests=$(send_jsonrpc "initialize" 1)
    requests+=$'\n'
    requests+=$(send_jsonrpc "${method}" 2)

    run bash -c 'echo "$1" | bash "$2" 2>/dev/null | tail -1' _ "${requests}" "${SERVER_SCRIPT}"
}

@test "write server returns empty tools list when enable_write_server is false" {
    run_server_request '{"enable_write_server": false}' "tools/list"
    assert_success
    local tool_count
    tool_count=$(echo "$output" | jq '.result.tools | length')
    [[ "$tool_count" -eq 0 ]]
}

@test "write server returns empty tools list when enable_write_server is absent" {
    run_server_request '{"repo": "shopware/shopware"}' "tools/list"
    assert_success
    local tool_count
    tool_count=$(echo "$output" | jq '.result.tools | length')
    [[ "$tool_count" -eq 0 ]]
}

@test "write server returns tools when enable_write_server is true" {
    run_server_request '{"enable_write_server": true}' "tools/list"
    assert_success
    local tool_count
    tool_count=$(echo "$output" | jq '.result.tools | length')
    [[ "$tool_count" -gt 0 ]]
}

@test "write server returns empty tools list when no config file exists" {
    export CLAUDE_PROJECT_DIR="${BATS_TEST_TMPDIR}/no-config"
    mkdir -p "$CLAUDE_PROJECT_DIR"
    export PROJECT_ROOT="$CLAUDE_PROJECT_DIR"
    local requests
    requests=$(send_jsonrpc "initialize" 1)
    requests+=$'\n'
    requests+=$(send_jsonrpc "tools/list" 2)
    run bash -c 'echo "$1" | bash "$2" 2>/dev/null | tail -1' _ "${requests}" "${SERVER_SCRIPT}"
    assert_success
    local tool_count
    tool_count=$(echo "$output" | jq '.result.tools | length')
    [[ "$tool_count" -eq 0 ]]
}
