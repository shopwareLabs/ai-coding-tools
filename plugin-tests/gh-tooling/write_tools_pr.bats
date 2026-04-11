#!/usr/bin/env bats
# bats file_tags=gh-tooling,write-tools,pr
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/gh-tooling"
GH_LIB_DIR="${PLUGIN_DIR}/mcp-server-gh/lib"

setup() {
    log() { :; }
    GH_DEFAULT_REPO="shopware/shopware"
    GH_TOOLING_CONFIG_FILE=""
    source "${GH_LIB_DIR}/common.sh"
    source "${GH_LIB_DIR}/pr_write.sh"

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
# pr_create
# ============================================================================

@test "pr_create requires title" {
    run tool_pr_create '{"body": "desc"}'
    assert_failure
    assert_output --partial "title is required"
}

@test "pr_create with minimal params" {
    GH_STUB_OUTPUT="https://github.com/shopware/shopware/pull/100"
    run tool_pr_create '{"title": "feat: add feature"}'
    assert_success
    assert_output --partial "pull/100"
    assert_gh_args_contain "pr create"
    assert_gh_args_contain "--title"
}

@test "pr_create with draft flag" {
    GH_STUB_OUTPUT="https://github.com/shopware/shopware/pull/101"
    run tool_pr_create '{"title": "draft pr", "draft": true}'
    assert_success
    assert_gh_args_contain "--draft"
}

@test "pr_create with labels array" {
    GH_STUB_OUTPUT="https://github.com/shopware/shopware/pull/102"
    run tool_pr_create '{"title": "labeled", "labels": ["bug", "critical"]}'
    assert_success
    assert_gh_args_contain "--label bug"
    assert_gh_args_contain "--label critical"
}

@test "pr_create with assignees and reviewers" {
    GH_STUB_OUTPUT="https://github.com/shopware/shopware/pull/103"
    run tool_pr_create '{"title": "assigned", "assignees": ["user1"], "reviewers": ["user2"]}'
    assert_success
    assert_gh_args_contain "--assignee user1"
    assert_gh_args_contain "--reviewer user2"
}

@test "pr_create with base and head" {
    GH_STUB_OUTPUT="https://github.com/shopware/shopware/pull/104"
    run tool_pr_create '{"title": "branch pr", "base": "main", "head": "feature/foo"}'
    assert_success
    assert_gh_args_contain "--base main"
    assert_gh_args_contain "--head feature/foo"
}

# ============================================================================
# pr_edit
# ============================================================================

@test "pr_edit requires number" {
    run tool_pr_edit '{"title": "new title"}'
    assert_failure
    assert_output --partial "number is required"
}

@test "pr_edit updates title" {
    GH_STUB_OUTPUT=""
    run tool_pr_edit '{"number": 100, "title": "updated title"}'
    assert_success
    assert_gh_args_contain "pr edit 100"
    assert_gh_args_contain "--title"
}

@test "pr_edit with labels adds --add-label" {
    GH_STUB_OUTPUT=""
    run tool_pr_edit '{"number": 100, "labels": ["bug"]}'
    assert_success
    assert_gh_args_contain "--add-label bug"
}

# ============================================================================
# pr_ready
# ============================================================================

@test "pr_ready requires number" {
    run tool_pr_ready '{}'
    assert_failure
    assert_output --partial "number is required"
}

@test "pr_ready marks PR as ready" {
    GH_STUB_OUTPUT=""
    run tool_pr_ready '{"number": 100}'
    assert_success
    assert_gh_args_contain "pr ready 100"
}

# ============================================================================
# pr_merge
# ============================================================================

@test "pr_merge requires number" {
    run tool_pr_merge '{}'
    assert_failure
    assert_output --partial "number is required"
}

@test "pr_merge with squash method" {
    GH_STUB_OUTPUT=""
    run tool_pr_merge '{"number": 100, "method": "squash"}'
    assert_success
    assert_gh_args_contain "pr merge 100"
    assert_gh_args_contain "--squash"
}

@test "pr_merge with rebase method" {
    GH_STUB_OUTPUT=""
    run tool_pr_merge '{"number": 100, "method": "rebase"}'
    assert_success
    assert_gh_args_contain "--rebase"
}

@test "pr_merge with delete_branch" {
    GH_STUB_OUTPUT=""
    run tool_pr_merge '{"number": 100, "delete_branch": true}'
    assert_success
    assert_gh_args_contain "--delete-branch"
}

@test "pr_merge rejects invalid method" {
    run tool_pr_merge '{"number": 100, "method": "invalid"}'
    assert_failure
    assert_output --partial "method must be"
}

# ============================================================================
# pr_close / pr_reopen
# ============================================================================

@test "pr_close requires number" {
    run tool_pr_close '{}'
    assert_failure
    assert_output --partial "number is required"
}

@test "pr_close with comment" {
    GH_STUB_OUTPUT=""
    run tool_pr_close '{"number": 100, "comment": "Closing: superseded by #101"}'
    assert_success
    assert_gh_args_contain "pr close 100"
    assert_gh_args_contain "--comment"
}

@test "pr_reopen requires number" {
    run tool_pr_reopen '{}'
    assert_failure
    assert_output --partial "number is required"
}

@test "pr_reopen reopens PR" {
    GH_STUB_OUTPUT=""
    run tool_pr_reopen '{"number": 100}'
    assert_success
    assert_gh_args_contain "pr reopen 100"
}
