#!/usr/bin/env bats
# bats file_tags=mcp-core,argument-validation
# Tests for the shared mcpserver_core argument validator:
#   validate_tool_arguments() and its wiring into handle_tools_call().
# Enforces `required` always, `additionalProperties: false` when declared,
# and `enum` on any property present in the call's arguments.
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
    #   strict — required:[number], additionalProperties:false, repo/mode carry enums
    #   loose  — no required, additionalProperties unset (defaults to allowed)
    cat > "${MCP_TOOLS_LIST_FILE}" <<'JSON'
{
  "tools": [
    {
      "name": "strict",
      "inputSchema": {
        "type": "object",
        "required": ["number"],
        "properties": {
          "number": {"type": "string"},
          "repo": {"type": "string", "enum": ["a/b", "c/d"]},
          "mode": {"type": "string", "enum": ["development", "production"]}
        },
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

    # Dispatchable stubs that echo a marker so dispatch can be observed.
    tool_strict() { printf 'DISPATCHED:%s\n' "$1"; }
    tool_loose() { printf 'DISPATCHED:%s\n' "$1"; }
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
    assert_output --partial "Allowed parameters: mode, number, repo"
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

@test "validate_tool_arguments: value outside the declared enum fails naming property, value, and allowed values" {
    run validate_tool_arguments "strict" '{"number": "5", "repo": "x/y"}'
    assert_failure
    assert_output --partial 'Invalid value(s):'
    assert_output --partial 'repo="x/y"'
    assert_output --partial '(allowed: a/b, c/d)'
}

@test "validate_tool_arguments: two invalid enum values in one call are both named in one message" {
    run validate_tool_arguments "strict" '{"number": "5", "repo": "x/y", "mode": "staging"}'
    assert_failure
    assert_output --partial 'repo="x/y"'
    assert_output --partial '(allowed: a/b, c/d)'
    assert_output --partial 'mode="staging"'
    assert_output --partial '(allowed: development, production)'
}

@test "validate_tool_arguments: a non-string value against a string enum fails without a jq error" {
    run validate_tool_arguments "strict" '{"number": "5", "mode": 5}'
    assert_failure
    assert_output --partial 'mode="5"'
    assert_output --partial '(allowed: development, production)'
}

@test "validate_tool_arguments: a property with an enum absent from the arguments passes" {
    run validate_tool_arguments "strict" '{"number": "5"}'
    assert_success
    assert_output ""
}

@test "validate_tool_arguments: a property with no enum is unaffected by any value" {
    run validate_tool_arguments "loose" '{"a": "anything-at-all"}'
    assert_success
    assert_output ""
}

@test "validate_tool_arguments: missing required takes precedence over an invalid enum" {
    run validate_tool_arguments "strict" '{"repo": "x/y"}'
    assert_failure
    assert_output --partial "Missing required parameter(s): number"
    refute_output --partial "Invalid value(s)"
}

# --- validate_tool_arguments: arguments that are not a JSON object ---

# Every schema constraint reads `$args | keys`, which errors on a non-object.
# Each of these once passed validation, taking `required`,
# `additionalProperties` and `enum` down with it.
_assert_rejects_non_object() {
    local arguments="$1" expected_type="$2"
    run validate_tool_arguments "strict" "${arguments}"
    assert_failure
    assert_output --partial "Invalid arguments: expected a JSON object, got ${expected_type}."
}

@test "validate_tool_arguments: a string in place of an arguments object is rejected" {
    _assert_rejects_non_object '"oops"' "string"
}

@test "validate_tool_arguments: an array in place of an arguments object is rejected" {
    _assert_rejects_non_object '[1,2]' "array"
}

@test "validate_tool_arguments: a null in place of an arguments object is rejected" {
    _assert_rejects_non_object 'null' "null"
}

@test "validate_tool_arguments: an empty object is still checked against required parameters" {
    run validate_tool_arguments "strict" '{}'
    assert_failure
    assert_output --partial "Missing required parameter(s): number"
}

# --- validate_tool_arguments: a jq failure is a rejection, not a skip ---

@test "validate_tool_arguments: arguments that are not JSON at all are rejected" {
    run validate_tool_arguments "strict" '{not valid json'
    assert_failure
    assert_output --partial "Cannot validate arguments for strict"
    assert_output --partial "could not be evaluated against its schema"
}

@test "validate_tool_arguments: an unparseable tool list is rejected rather than skipping validation" {
    printf '%s' '{"tools": [ broken' > "${MCP_TOOLS_LIST_FILE}"
    run validate_tool_arguments "strict" '{"number": "5"}'
    assert_failure
    assert_output --partial "is not parseable JSON"
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

@test "handle_tools_call: invalid enum returns an isError result, not a dispatch" {
    local params
    params=$(jq -n -c '{name: "strict", arguments: {number: "5", repo: "x/y"}}')
    run handle_tools_call 1 "$params"
    assert_success
    assert_output --partial '"isError":true'
    assert_output --partial 'Invalid value(s):'
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

@test "handle_tools_call: a non-object arguments value is not dispatched to the tool" {
    local params
    params=$(jq -n -c '{name: "strict", arguments: "oops"}')
    run handle_tools_call 1 "$params"
    assert_success
    assert_output --partial '"isError":true'
    assert_output --partial "expected a JSON object, got string"
    refute_output --partial "DISPATCHED"
}

@test "handle_tools_call: a call with no arguments key is dispatched when the schema requires nothing" {
    # handle_tools_call substitutes {} for an absent arguments key, which must
    # stay a valid object for every tool whose schema has no required field.
    local params
    params=$(jq -n -c '{name: "loose"}')
    run handle_tools_call 1 "$params"
    assert_success
    assert_output --partial "DISPATCHED:{}"
    assert_output --partial '"isError":false'
}
