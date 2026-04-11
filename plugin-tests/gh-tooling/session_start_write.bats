#!/usr/bin/env bats
# bats file_tags=gh-tooling,session-start,write
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

SESSION_SCRIPT="${REPO_ROOT}/plugins/gh-tooling/hooks/scripts/session-start.sh"

run_session_with_config() {
    local config="$1"
    setup_config "gh-tooling" "$config"
    run bash -c 'echo "{}" | bash "$1"' _ "$SESSION_SCRIPT"
}

extract_context() {
    echo "$output" | jq -r '.hookSpecificOutput.additionalContext'
}

@test "includes write section when enable_write_server is true" {
    run_session_with_config '{"enforce_mcp_tools": true, "enable_write_server": true}'
    assert_success
    local context
    context=$(extract_context)
    [[ "$context" == *"Write"*"gh-tooling-write"* ]]
    [[ "$context" == *"pr_create"* ]]
}

@test "shows write disabled message when enable_write_server is false" {
    run_session_with_config '{"enforce_mcp_tools": true, "enable_write_server": false}'
    assert_success
    local context
    context=$(extract_context)
    [[ "$context" == *"Write operations are disabled"* ]]
    [[ "$context" != *"pr_create"* ]]
}

@test "shows write disabled when enable_write_server absent" {
    run_session_with_config '{"enforce_mcp_tools": true}'
    assert_success
    local context
    context=$(extract_context)
    [[ "$context" == *"Write operations are disabled"* ]]
}

@test "includes label definitions when labels config present" {
    run_session_with_config '{"enforce_mcp_tools": true, "labels": {"bug": "A confirmed bug", "enhancement": "Feature request"}}'
    assert_success
    local context
    context=$(extract_context)
    [[ "$context" == *"Label Definitions"* ]]
    [[ "$context" == *"bug"* ]]
    [[ "$context" == *"A confirmed bug"* ]]
    [[ "$context" == *"enhancement"* ]]
}

@test "omits label section when no labels in config" {
    run_session_with_config '{"enforce_mcp_tools": true}'
    assert_success
    local context
    context=$(extract_context)
    [[ "$context" != *"Label Definitions"* ]]
}

@test "includes new read tools in read section" {
    run_session_with_config '{"enforce_mcp_tools": true}'
    assert_success
    local context
    context=$(extract_context)
    [[ "$context" == *"label_list"* ]]
    [[ "$context" == *"project_list"* ]]
    [[ "$context" == *"project_view"* ]]
}

@test "read api described as read-only" {
    run_session_with_config '{"enforce_mcp_tools": true}'
    assert_success
    local context
    context=$(extract_context)
    [[ "$context" == *"GET only"* ]]
}
