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
    GH_STDIN_FILE="${BATS_TEST_TMPDIR}/gh_stdin"
    : > "${GH_ARGS_FILE}"
    : > "${GH_STDIN_FILE}"

    # gh stub: appends each invocation's args on a new line, captures stdin for
    # --input calls, and dispatches a canned head.sha for the commit_id fetch.
    gh() {
        printf '%s\n' "$*" >> "${GH_ARGS_FILE}"
        if [[ "$*" == *"--input"* ]]; then
            cat > "${GH_STDIN_FILE}"
        fi
        if [[ "$*" == *"head.sha"* ]]; then
            printf '%s\n' "${GH_STUB_HEAD_SHA:-0123456789abcdef0123456789abcdef01234567}"
            return 0
        fi
        [[ -n "${GH_STUB_STDERR:-}" ]] && echo "${GH_STUB_STDERR}" >&2
        [[ -n "${GH_STUB_OUTPUT:-}" ]] && printf '%s\n' "${GH_STUB_OUTPUT}"
        return "${GH_STUB_EXIT:-0}"
    }
    GH_STUB_OUTPUT=""
    GH_STUB_STDERR=""
    GH_STUB_EXIT=0
    GH_STUB_HEAD_SHA="0123456789abcdef0123456789abcdef01234567"
}

assert_gh_args_contain() {
    local expected="$1"
    [[ -f "${GH_ARGS_FILE}" ]] || fail "gh was not called"
    grep -qF -- "$expected" "${GH_ARGS_FILE}" || fail "Expected gh args to contain '$expected', got: $(cat "${GH_ARGS_FILE}")"
}

assert_gh_stdin_contain() {
    local expected="$1"
    [[ -f "${GH_STDIN_FILE}" ]] || fail "gh stdin was not captured"
    grep -qF -- "$expected" "${GH_STDIN_FILE}" || fail "Expected gh stdin to contain '$expected', got: $(cat "${GH_STDIN_FILE}")"
}

# ============================================================================
# pr_review_submit — simple path (no inline comments → gh pr review)
# ============================================================================

@test "pr_review_submit requires number" {
    run tool_pr_review_submit '{"event": "approve"}'
    assert_failure
    assert_output --partial "number is required"
}

@test "pr_review_submit rejects invalid event" {
    run tool_pr_review_submit '{"number": 100, "event": "invalid"}'
    assert_failure
    assert_output --partial "event must be one of"
}

@test "pr_review_submit request_changes requires body" {
    run tool_pr_review_submit '{"number": 100, "event": "request_changes"}'
    assert_failure
    assert_output --partial "body is required"
}

@test "pr_review_submit approve (no comments) uses gh pr review --approve" {
    run tool_pr_review_submit '{"number": 100, "event": "approve"}'
    assert_success
    assert_gh_args_contain "pr review 100"
    assert_gh_args_contain "--approve"
}

@test "pr_review_submit request_changes (no comments) uses --request-changes with body" {
    run tool_pr_review_submit '{"number": 100, "event": "request_changes", "body": "Please fix the bug."}'
    assert_success
    assert_gh_args_contain "pr review 100"
    assert_gh_args_contain "--request-changes"
    assert_gh_args_contain "Please fix the bug."
}

@test "pr_review_submit comment is the default event" {
    run tool_pr_review_submit '{"number": 100, "body": "Looks good overall."}'
    assert_success
    assert_gh_args_contain "pr review 100"
    assert_gh_args_contain "--comment"
}

# ============================================================================
# pr_review_submit — batched path (with inline comments → /pulls/N/reviews)
# ============================================================================

@test "pr_review_submit with comments posts to reviews endpoint via stdin" {
    GH_STUB_OUTPUT='{"id": 99}'
    run tool_pr_review_submit '{
        "number": 100,
        "event": "comment",
        "body": "Overall LGTM, a few notes.",
        "comments": [
            {"path": "src/Foo.php", "line": 42, "body": "nit: rename"},
            {"path": "src/Bar.php", "line": 10, "body": "suggestion here", "side": "RIGHT"}
        ]
    }'
    assert_success
    assert_gh_args_contain "api repos/shopware/shopware/pulls/100/reviews"
    assert_gh_args_contain "-X POST"
    assert_gh_args_contain "--input -"
    assert_gh_stdin_contain '"event": "COMMENT"'
    assert_gh_stdin_contain '"src/Foo.php"'
    assert_gh_stdin_contain '"src/Bar.php"'
    assert_gh_stdin_contain '"line": 42'
}

@test "pr_review_submit with comments auto-fetches commit_id from PR head" {
    GH_STUB_HEAD_SHA="feedfacefeedfacefeedfacefeedfacefeedface"
    GH_STUB_OUTPUT='{"id": 99}'
    run tool_pr_review_submit '{
        "number": 100,
        "comments": [{"path": "x.php", "line": 1, "body": "n"}]
    }'
    assert_success
    assert_gh_args_contain "api repos/shopware/shopware/pulls/100 --jq .head.sha"
    assert_gh_stdin_contain '"commit_id": "feedfacefeedfacefeedfacefeedfacefeedface"'
}

@test "pr_review_submit with explicit commit_id skips auto-fetch" {
    GH_STUB_OUTPUT='{"id": 99}'
    run tool_pr_review_submit '{
        "number": 100,
        "commit_id": "abc1234abc1234abc1234abc1234abc1234abcd",
        "comments": [{"path": "x.php", "line": 1, "body": "n"}]
    }'
    assert_success
    run grep -c "head.sha" "${GH_ARGS_FILE}"
    assert_output "0"
}

@test "pr_review_submit uppercases event for REST API body" {
    GH_STUB_OUTPUT='{"id": 99}'
    run tool_pr_review_submit '{
        "number": 100,
        "event": "request_changes",
        "body": "Needs work",
        "comments": [{"path": "x.php", "line": 1, "body": "n"}]
    }'
    assert_success
    assert_gh_stdin_contain '"event": "REQUEST_CHANGES"'
}

@test "pr_review_submit omits empty top-level body from REST request" {
    GH_STUB_OUTPUT='{"id": 99}'
    run tool_pr_review_submit '{
        "number": 100,
        "comments": [{"path": "x.php", "line": 1, "body": "n"}]
    }'
    assert_success
    run jq -e 'has("body") | not' "${GH_STDIN_FILE}"
    assert_success
}

# Shared helper for the "comments[] item must have path/line/body" guard.
_assert_rejects_incomplete_comment() {
    local payload="$1"
    run tool_pr_review_submit "${payload}"
    assert_failure
    assert_output --partial "each item in comments requires path, line, and body"
}

@test "pr_review_submit rejects comment missing path" {
    _assert_rejects_incomplete_comment '{"number": 100, "comments": [{"line": 1, "body": "n"}]}'
}

@test "pr_review_submit rejects comment missing line" {
    _assert_rejects_incomplete_comment '{"number": 100, "comments": [{"path": "x.php", "body": "n"}]}'
}

@test "pr_review_submit rejects comment missing body" {
    _assert_rejects_incomplete_comment '{"number": 100, "comments": [{"path": "x.php", "line": 1}]}'
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

@test "pr_comment posts conversation comment" {
    GH_STUB_OUTPUT="https://github.com/shopware/shopware/pull/100#issuecomment-999"
    run tool_pr_comment '{"number": 100, "body": "Great work!"}'
    assert_success
    assert_gh_args_contain "pr comment 100"
    assert_gh_args_contain "Great work!"
}

# ============================================================================
# pr_review_reply
# ============================================================================

@test "pr_review_reply requires number" {
    run tool_pr_review_reply '{"comment_id": 5, "body": "done"}'
    assert_failure
    assert_output --partial "number is required"
}

@test "pr_review_reply requires comment_id" {
    run tool_pr_review_reply '{"number": 100, "body": "done"}'
    assert_failure
    assert_output --partial "comment_id is required"
}

@test "pr_review_reply requires body" {
    run tool_pr_review_reply '{"number": 100, "comment_id": 5}'
    assert_failure
    assert_output --partial "body is required"
}

@test "pr_review_reply posts to replies endpoint" {
    GH_STUB_OUTPUT='{"id": 1001}'
    run tool_pr_review_reply '{"number": 100, "comment_id": 5, "body": "Addressed, thanks!"}'
    assert_success
    assert_gh_args_contain "api repos/shopware/shopware/pulls/100/comments/5/replies"
    assert_gh_args_contain "-X POST"
    assert_gh_args_contain "-f body=Addressed, thanks!"
}
