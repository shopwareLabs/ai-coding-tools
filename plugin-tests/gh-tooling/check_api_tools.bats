#!/usr/bin/env bats
# bats file_tags=gh-tooling,api-blocking
# Tests for check-api-tools.sh MCP API tool blocking hook
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

CONFIG_PREFIX="gh-tooling"
SCRIPTS_DIR="${REPO_ROOT}/plugins/gh-tooling/hooks/scripts"

# Helper: create hook input for an MCP api tool call
make_api_input() {
    local tool_name="$1" endpoint="$2" method="${3:-GET}"
    printf '{"tool_name": "%s", "tool_input": {"endpoint": "%s", "method": "%s"}}' \
        "$tool_name" "$endpoint" "$method"
}

run_api_hook() {
    local tool_name="$1" endpoint="$2" method="${3:-GET}"
    local input
    input=$(make_api_input "$tool_name" "$endpoint" "$method")
    run bash -c 'printf "%s" "$1" | bash "$2"' _ "$input" "${SCRIPTS_DIR}/check-api-tools.sh"
}

READ_TOOL="mcp__plugin_gh-tooling_gh-tooling__api_read"
WRITE_TOOL="mcp__plugin_gh-tooling_gh-tooling-write__api"

# ============================================================================
# Read API tool blocking (block_api_tool_read: true)
# ============================================================================

setup_read_blocking() {
    setup_config "gh-tooling" '{"block_api_tool_read": true}'
}

@test "read api: blocks pulls/N/comments → suggests pr_comments" {
    setup_read_blocking
    run_api_hook "$READ_TOOL" "repos/shopware/shopware/pulls/123/comments"
    assert_failure 2
    assert_output --partial "pr_comments"
}

@test "read api: blocks pulls/N/reviews → suggests pr_reviews" {
    setup_read_blocking
    run_api_hook "$READ_TOOL" "repos/shopware/shopware/pulls/123/reviews"
    assert_failure 2
    assert_output --partial "pr_reviews"
}

@test "read api: blocks actions/jobs/N/logs → suggests job_logs" {
    setup_read_blocking
    run_api_hook "$READ_TOOL" "repos/shopware/shopware/actions/jobs/456/logs"
    assert_failure 2
    assert_output --partial "job_logs"
}

@test "read api: blocks contents/ → suggests repo_tree or repo_file" {
    setup_read_blocking
    run_api_hook "$READ_TOOL" "repos/shopware/shopware/contents/src"
    assert_failure 2
    assert_output --partial "repo_tree"
}

@test "read api: allows unknown endpoint" {
    setup_read_blocking
    run_api_hook "$READ_TOOL" "repos/shopware/shopware/actions/runs/123/jobs"
    assert_success
}

@test "read api: allows when block_api_tool_read is false" {
    setup_config "gh-tooling" '{"block_api_tool_read": false}'
    run_api_hook "$READ_TOOL" "repos/shopware/shopware/pulls/123/comments"
    assert_success
}

@test "read api: allows when block_api_tool_read absent" {
    setup_config "gh-tooling" '{}'
    run_api_hook "$READ_TOOL" "repos/shopware/shopware/pulls/123/comments"
    assert_success
}

# ============================================================================
# Write API tool blocking (block_api_tool_write: true)
# ============================================================================

setup_write_blocking() {
    setup_config "gh-tooling" '{"block_api_tool_write": true}'
}

@test "write api: blocks POST pulls → suggests pr_create" {
    setup_write_blocking
    run_api_hook "$WRITE_TOOL" "repos/shopware/shopware/pulls" "POST"
    assert_failure 2
    assert_output --partial "pr_create"
}

@test "write api: blocks PUT pulls/N/merge → suggests pr_merge" {
    setup_write_blocking
    run_api_hook "$WRITE_TOOL" "repos/shopware/shopware/pulls/123/merge" "PUT"
    assert_failure 2
    assert_output --partial "pr_merge"
}

@test "write api: blocks POST issues → suggests issue_create" {
    setup_write_blocking
    run_api_hook "$WRITE_TOOL" "repos/shopware/shopware/issues" "POST"
    assert_failure 2
    assert_output --partial "issue_create"
}

@test "write api: blocks POST issues/N/comments → suggests issue_comment" {
    setup_write_blocking
    run_api_hook "$WRITE_TOOL" "repos/shopware/shopware/issues/123/comments" "POST"
    assert_failure 2
    assert_output --partial "issue_comment"
}

@test "write api: allows unknown write endpoint" {
    setup_write_blocking
    run_api_hook "$WRITE_TOOL" "repos/shopware/shopware/releases" "POST"
    assert_success
}

@test "write api: allows when block_api_tool_write is false" {
    setup_config "gh-tooling" '{"block_api_tool_write": false}'
    run_api_hook "$WRITE_TOOL" "repos/shopware/shopware/pulls" "POST"
    assert_success
}

@test "write api: also blocks read endpoints" {
    setup_write_blocking
    run_api_hook "$WRITE_TOOL" "repos/shopware/shopware/pulls/123/comments" "GET"
    assert_failure 2
    assert_output --partial "pr_comments"
}
