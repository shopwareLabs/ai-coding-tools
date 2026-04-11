#!/usr/bin/env bats
# bats file_tags=gh-tooling,write-tools,issue
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/gh-tooling"
GH_LIB_DIR="${PLUGIN_DIR}/mcp-server-gh/lib"

setup() {
    log() { :; }
    GH_DEFAULT_REPO="shopware/shopware"
    GH_TOOLING_CONFIG_FILE=""
    source "${GH_LIB_DIR}/common.sh"
    source "${GH_LIB_DIR}/issue_write.sh"

    GH_ARGS_FILE="${BATS_TEST_TMPDIR}/gh_args"
    gh() {
        printf '%s\n' "$*" > "${GH_ARGS_FILE}"
        [[ -n "${GH_STUB_STDERR:-}" ]] && echo "${GH_STUB_STDERR}" >&2
        [[ -n "${GH_STUB_OUTPUT:-}" ]] && printf '%s\n' "${GH_STUB_OUTPUT}"
        return "${GH_STUB_EXIT:-0}"
    }
    GH_STUB_OUTPUT=""
    GH_STUB_STDERR=""
    GH_STUB_EXIT=0
}

# Helper to check gh was called with expected args
assert_gh_args_contain() {
    local expected="$1"
    [[ -f "${GH_ARGS_FILE}" ]] || fail "gh was not called"
    grep -qF -- "$expected" "${GH_ARGS_FILE}" || fail "Expected gh args to contain '$expected', got: $(cat "${GH_ARGS_FILE}")"
}

# ============================================================================
# issue_create
# ============================================================================

@test "issue_create requires title" {
    run tool_issue_create '{"body": "desc"}'
    assert_failure
    assert_output --partial "title is required"
}

@test "issue_create with minimal params" {
    GH_STUB_OUTPUT="https://github.com/shopware/shopware/issues/42"
    run tool_issue_create '{"title": "Something is broken"}'
    assert_success
    assert_output --partial "issues/42"
    assert_gh_args_contain "issue create"
    assert_gh_args_contain "--title"
}

@test "issue_create with labels array" {
    GH_STUB_OUTPUT="https://github.com/shopware/shopware/issues/43"
    run tool_issue_create '{"title": "labeled issue", "labels": ["bug", "priority:high"]}'
    assert_success
    assert_gh_args_contain "--label bug"
    assert_gh_args_contain "--label priority:high"
}

@test "issue_create with assignees" {
    GH_STUB_OUTPUT="https://github.com/shopware/shopware/issues/44"
    run tool_issue_create '{"title": "assigned issue", "assignees": ["user1", "user2"]}'
    assert_success
    assert_gh_args_contain "--assignee user1"
    assert_gh_args_contain "--assignee user2"
}

@test "issue_create with project" {
    GH_STUB_OUTPUT="https://github.com/shopware/shopware/issues/45"
    run tool_issue_create '{"title": "project issue", "project": "Shopware Backlog"}'
    assert_success
    assert_gh_args_contain "--project"
}

# ============================================================================
# issue_edit
# ============================================================================

@test "issue_edit requires number" {
    run tool_issue_edit '{"title": "new title"}'
    assert_failure
    assert_output --partial "number is required"
}

@test "issue_edit updates title" {
    GH_STUB_OUTPUT=""
    run tool_issue_edit '{"number": 42, "title": "updated title"}'
    assert_success
    assert_gh_args_contain "issue edit 42"
    assert_gh_args_contain "--title"
}

@test "issue_edit with labels adds --add-label" {
    GH_STUB_OUTPUT=""
    run tool_issue_edit '{"number": 42, "labels": ["wontfix"]}'
    assert_success
    assert_gh_args_contain "--add-label wontfix"
}

# ============================================================================
# issue_close
# ============================================================================

@test "issue_close requires number" {
    run tool_issue_close '{}'
    assert_failure
    assert_output --partial "number is required"
}

@test "issue_close with reason completed" {
    GH_STUB_OUTPUT=""
    run tool_issue_close '{"number": 42, "reason": "completed"}'
    assert_success
    assert_gh_args_contain "issue close 42"
    assert_gh_args_contain "--reason completed"
}

@test "issue_close with reason not_planned" {
    GH_STUB_OUTPUT=""
    run tool_issue_close '{"number": 42, "reason": "not_planned"}'
    assert_success
    assert_gh_args_contain "--reason not_planned"
}

@test "issue_close rejects invalid reason" {
    run tool_issue_close '{"number": 42, "reason": "duplicate"}'
    assert_failure
    assert_output --partial "reason must be"
}

@test "issue_close with comment" {
    GH_STUB_OUTPUT=""
    run tool_issue_close '{"number": 42, "comment": "Closing: fixed in #50"}'
    assert_success
    assert_gh_args_contain "issue close 42"
    assert_gh_args_contain "--comment"
}

# ============================================================================
# issue_reopen
# ============================================================================

@test "issue_reopen requires number" {
    run tool_issue_reopen '{}'
    assert_failure
    assert_output --partial "number is required"
}

@test "issue_reopen reopens issue" {
    GH_STUB_OUTPUT=""
    run tool_issue_reopen '{"number": 42}'
    assert_success
    assert_gh_args_contain "issue reopen 42"
}

# ============================================================================
# issue_comment
# ============================================================================

@test "issue_comment requires number" {
    run tool_issue_comment '{"body": "hello"}'
    assert_failure
    assert_output --partial "number is required"
}

@test "issue_comment requires body" {
    run tool_issue_comment '{"number": 42}'
    assert_failure
    assert_output --partial "body is required"
}

@test "issue_comment posts comment" {
    GH_STUB_OUTPUT="https://github.com/shopware/shopware/issues/42#issuecomment-999"
    run tool_issue_comment '{"number": 42, "body": "Thank you for the report!"}'
    assert_success
    assert_gh_args_contain "issue comment 42"
    assert_gh_args_contain "--body"
}
