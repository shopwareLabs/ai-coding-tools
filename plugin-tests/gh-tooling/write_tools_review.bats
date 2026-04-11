#!/usr/bin/env bats
# bats file_tags=gh-tooling,write-tools,review
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/gh-tooling"
GH_LIB_DIR="${PLUGIN_DIR}/mcp-server-gh/lib"

setup() {
    log() { :; }
    GH_DEFAULT_REPO="shopware/shopware"
    GH_TOOLING_CONFIG_FILE=""
    source "${GH_LIB_DIR}/common.sh"
    source "${GH_LIB_DIR}/review_write.sh"

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
# pr_review
# ============================================================================

@test "pr_review requires number" {
    run tool_pr_review '{"event": "approve"}'
    assert_failure
    assert_output --partial "number is required"
}

@test "pr_review approve event" {
    GH_STUB_OUTPUT=""
    run tool_pr_review '{"number": 100, "event": "approve"}'
    assert_success
    assert_gh_args_contain "pr review 100"
    assert_gh_args_contain "--approve"
}

@test "pr_review request_changes event" {
    GH_STUB_OUTPUT=""
    run tool_pr_review '{"number": 100, "event": "request_changes", "body": "Please fix the bug."}'
    assert_success
    assert_gh_args_contain "pr review 100"
    assert_gh_args_contain "--request-changes"
    assert_gh_args_contain "--body"
}

@test "pr_review request_changes requires body" {
    run tool_pr_review '{"number": 100, "event": "request_changes"}'
    assert_failure
    assert_output --partial "body is required"
}

@test "pr_review comment event (default)" {
    GH_STUB_OUTPUT=""
    run tool_pr_review '{"number": 100, "body": "Looks good overall."}'
    assert_success
    assert_gh_args_contain "pr review 100"
    assert_gh_args_contain "--comment"
}

@test "pr_review rejects invalid event" {
    run tool_pr_review '{"number": 100, "event": "invalid"}'
    assert_failure
    assert_output --partial "event must be one of"
}

# ============================================================================
# pr_comment
# ============================================================================

@test "pr_comment requires number" {
    run tool_pr_comment '{"body": "hello"}'
    assert_failure
    assert_output --partial "number is required"
}

@test "pr_comment requires body" {
    run tool_pr_comment '{"number": 100}'
    assert_failure
    assert_output --partial "body is required"
}

@test "pr_comment posts comment" {
    GH_STUB_OUTPUT="https://github.com/shopware/shopware/pull/100#issuecomment-999"
    run tool_pr_comment '{"number": 100, "body": "Great work!"}'
    assert_success
    assert_gh_args_contain "pr comment 100"
    assert_gh_args_contain "--body"
}

# ============================================================================
# pr_review_comment
# ============================================================================

@test "pr_review_comment requires number" {
    run tool_pr_review_comment '{"body": "nit", "path": "src/foo.php", "line": 10}'
    assert_failure
    assert_output --partial "number is required"
}

@test "pr_review_comment requires body" {
    run tool_pr_review_comment '{"number": 100, "path": "src/foo.php", "line": 10}'
    assert_failure
    assert_output --partial "body is required"
}

@test "pr_review_comment requires path" {
    run tool_pr_review_comment '{"number": 100, "body": "nit", "line": 10}'
    assert_failure
    assert_output --partial "path is required"
}

@test "pr_review_comment requires line" {
    run tool_pr_review_comment '{"number": 100, "body": "nit", "path": "src/foo.php"}'
    assert_failure
    assert_output --partial "line is required"
}

@test "pr_review_comment posts inline comment (gh api endpoint)" {
    GH_STUB_OUTPUT='{"id": 1}'
    run tool_pr_review_comment '{"number": 100, "body": "nit: rename variable", "path": "src/foo.php", "line": 42}'
    assert_success
    assert_gh_args_contain "api repos/shopware/shopware/pulls/100/comments"
    assert_gh_args_contain "-X POST"
    assert_gh_args_contain "-f body=nit: rename variable"
    assert_gh_args_contain "-f path=src/foo.php"
    assert_gh_args_contain "-F line=42"
}

@test "pr_review_comment with start_line for multi-line comment" {
    GH_STUB_OUTPUT='{"id": 2}'
    run tool_pr_review_comment '{"number": 100, "body": "Extract this block", "path": "src/bar.php", "line": 50, "start_line": 45}'
    assert_success
    assert_gh_args_contain "-F start_line=45"
    assert_gh_args_contain "-F line=50"
}
