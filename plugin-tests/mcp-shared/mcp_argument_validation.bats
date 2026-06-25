#!/usr/bin/env bats
# bats file_tags=mcp-core,argument-validation
# Tests for the shared mcpserver_core argument validator:
#   validate_tool_arguments() and its wiring into handle_tools_call().
# Enforces `required` always, and `additionalProperties: false` when declared.
# Sources the template source of truth (templates/mcp-shared/mcpserver_core.sh);
# every plugin copy is kept byte-identical to it by the template-sync CI check,
# so this one suite covers the validator in all consuming plugins.
bats_require_minimum_version 1.11.0

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

setup() {
    MCP_LOG_FILE="${BATS_TEST_TMPDIR}/server.log"
    MCP_EXTRA_LOG_FILE=""
    MCP_CONFIG_FILE="/dev/null"
    MCP_TOOLS_LIST_FILE="${BATS_TEST_TMPDIR}/tools.json"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    export MCP_LOG_FILE MCP_EXTRA_LOG_FILE MCP_CONFIG_FILE MCP_TOOLS_LIST_FILE PROJECT_ROOT

    # Fixture tool list:
    #   strict — required:[number], additionalProperties:false
    #   loose  — no required, additionalProperties unset (defaults to allowed)
    cat > "${MCP_TOOLS_LIST_FILE}" <<'JSON'
{
  "tools": [
    {
      "name": "strict",
      "inputSchema": {
        "type": "object",
        "required": ["number"],
        "properties": { "number": {"type": "string"}, "repo": {"type": "string"} },
        "additionalProperties": false
      }
    },
    {
      "name": "loose",
      "inputSchema": {
        "type": "object",
        "properties": { "a": {"type": "string"} }
      }
    }
  ]
}
JSON

    source "${REPO_ROOT}/templates/mcp-shared/mcpserver_core.sh"

    # A dispatchable stub that echoes a marker so dispatch can be observed.
    tool_strict() { printf 'DISPATCHED:%s\n' "$1"; }
}

teardown() {
    unset MCP_LOG_FILE MCP_EXTRA_LOG_FILE MCP_CONFIG_FILE MCP_TOOLS_LIST_FILE PROJECT_ROOT
}

# --- validate_tool_arguments: direct unit behavior ---

@test "validate_tool_arguments: missing required field fails with its name" {
    run validate_tool_arguments "strict" '{"repo": "a/b"}'
    assert_failure
    assert_output --partial "Missing required parameter(s): number"
}

@test "validate_tool_arguments: unknown field fails and lists allowed parameters" {
    run validate_tool_arguments "strict" '{"number": "5", "pr": 339}'
    assert_failure
    assert_output --partial "Unknown parameter(s): pr"
    assert_output --partial "Allowed parameters: number, repo"
}

@test "validate_tool_arguments: valid arguments pass with no output" {
    run validate_tool_arguments "strict" '{"number": "5", "repo": "a/b"}'
    assert_success
    assert_output ""
}

@test "validate_tool_arguments: unknown field allowed when additionalProperties is unset" {
    run validate_tool_arguments "loose" '{"a": "x", "anything": "y"}'
    assert_success
    assert_output ""
}

@test "validate_tool_arguments: tool absent from the schema list is not validated" {
    run validate_tool_arguments "nonexistent" '{"whatever": 1}'
    assert_success
    assert_output ""
}

# --- handle_tools_call: wiring (validation runs before dispatch) ---

@test "handle_tools_call: invalid arguments return an isError result, not a dispatch" {
    local params
    params=$(jq -n -c '{name: "strict", arguments: {repo: "a/b"}}')
    run handle_tools_call 1 "$params"
    assert_success
    assert_output --partial '"isError":true'
    assert_output --partial "Missing required parameter(s): number"
    refute_output --partial "DISPATCHED"
}

@test "handle_tools_call: valid arguments are dispatched to the tool" {
    local params
    params=$(jq -n -c '{name: "strict", arguments: {number: "5"}}')
    run handle_tools_call 1 "$params"
    assert_success
    assert_output --partial "DISPATCHED"
    assert_output --partial '"isError":false'
}
