#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,gh
# Tests for gh-tooling MCP server shared parameters:
#   _gh_validate_jq_filter, _gh_post_process, suppress_errors, fallback,
#   jq_filter validation on tools, max_lines, tail_lines, grep_pattern
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"
GH_LIB_DIR="${PLUGIN_DIR}/mcp-server-gh/lib"

setup() {
    # Silence the log calls inside tool functions
    log() { :; }

    # Set a default repo so repo validation passes without requiring it per-test
    GH_DEFAULT_REPO="shopware/shopware"
    GH_TOOLING_CONFIG_FILE=""

    # Source shared helpers and the tool libraries under test
    # shellcheck source=/dev/null
    source "${GH_LIB_DIR}/common.sh"
    # shellcheck source=/dev/null
    source "${GH_LIB_DIR}/pr.sh"
    # shellcheck source=/dev/null
    source "${GH_LIB_DIR}/run.sh"
    # shellcheck source=/dev/null
    source "${GH_LIB_DIR}/api.sh"

    # Configurable gh stub: control via GH_STUB_OUTPUT / GH_STUB_STDERR / GH_STUB_EXIT
    gh() {
        [[ -n "${GH_STUB_STDERR:-}" ]] && echo "${GH_STUB_STDERR}" >&2
        [[ -n "${GH_STUB_OUTPUT:-}" ]] && printf '%s\n' "${GH_STUB_OUTPUT}"
        return "${GH_STUB_EXIT:-0}"
    }

    # Reset stub state between tests
    GH_STUB_OUTPUT=""
    GH_STUB_STDERR=""
    GH_STUB_EXIT=0
}

# =============================================================================
# _gh_validate_jq_filter — unit tests
# =============================================================================

@test "_gh_validate_jq_filter: accepts valid expression" {
    run _gh_validate_jq_filter '.[] | .name'
    assert_success
    assert_output ""
}

@test "_gh_validate_jq_filter: accepts empty filter (no-op)" {
    run _gh_validate_jq_filter ''
    assert_success
    assert_output ""
}

@test "_gh_validate_jq_filter: rejects compile error expression" {
    run _gh_validate_jq_filter '{{broken syntax'
    assert_failure
    assert_output --partial "Invalid jq_filter"
}

@test "_gh_validate_jq_filter: accepts runtime-only error (.[] on null is not a compile error)" {
    # .[] fails at runtime when input is null, but is syntactically valid
    run _gh_validate_jq_filter '.[]'
    assert_success
}

@test "_gh_validate_jq_filter: uses custom field name in error message" {
    run _gh_validate_jq_filter '{{bad' "my_filter"
    assert_failure
    assert_output --partial "Invalid my_filter"
}

# =============================================================================
# _gh_post_process — unit tests
# =============================================================================

@test "_gh_post_process: passes through output unchanged when no filters active" {
    run _gh_post_process $'line1\nline2\nline3' "" "" 0 0 false false "" ""
    assert_success
    assert_output $'line1\nline2\nline3'
}

@test "_gh_post_process: max_lines truncates to first N lines" {
    run _gh_post_process $'a\nb\nc\nd\ne' "" "" 0 0 false false "3" ""
    assert_success
    assert_output $'a\nb\nc'
}

@test "_gh_post_process: tail_lines returns last N lines" {
    run _gh_post_process $'a\nb\nc\nd\ne' "" "" 0 0 false false "" "2"
    assert_success
    assert_output $'d\ne'
}

@test "_gh_post_process: max_lines then tail_lines (head-of-input then tail-of-result)" {
    # head 3 → a,b,c  then tail 2 → b,c
    run _gh_post_process $'a\nb\nc\nd\ne' "" "" 0 0 false false "3" "2"
    assert_success
    assert_output $'b\nc'
}

@test "_gh_post_process: grep_pattern filters matching lines" {
    run _gh_post_process $'Step 1 passed\nERROR: something failed\nStep 3 passed' "" "ERROR" 0 0 false false "" ""
    assert_success
    assert_output "ERROR: something failed"
}

@test "_gh_post_process: grep_invert returns non-matching lines" {
    run _gh_post_process $'Step 1 passed\nERROR: bad\nStep 3 passed' "" "ERROR" 0 0 false true "" ""
    assert_success
    assert_output $'Step 1 passed\nStep 3 passed'
}

@test "_gh_post_process: grep_ignore_case matches case-insensitively" {
    run _gh_post_process $'INFO: ok\nerror: bad thing\nINFO: done' "" "ERROR" 0 0 true false "" ""
    assert_success
    assert_output "error: bad thing"
}

@test "_gh_post_process: grep no matches returns success with empty output" {
    run _gh_post_process $'line1\nline2' "" "NOMATCH_XYZ" 0 0 false false "" ""
    assert_success
}

@test "_gh_post_process: jq filter transforms JSON output" {
    run _gh_post_process '{"title":"hello"}' ".title" "" 0 0 false false "" ""
    assert_success
    assert_output '"hello"'
}

@test "_gh_post_process: invalid jq filter on real output fails with error message" {
    run _gh_post_process '{"title":"hello"}' "{{invalid" "" 0 0 false false "" ""
    assert_failure
    assert_output --partial "jq filter failed"
}

# =============================================================================
# suppress_errors — tested via tool_pr_view
# =============================================================================

@test "suppress_errors false (default): gh failure includes error message in output" {
    GH_STUB_EXIT=1
    GH_STUB_STDERR="error: pull request not found"
    run tool_pr_view '{"number": "99999"}'
    assert_failure
    assert_output --partial "error: pull request not found"
}

@test "suppress_errors true: gh failure returns empty output (no error message)" {
    GH_STUB_EXIT=1
    GH_STUB_STDERR="error: pull request not found"
    run tool_pr_view '{"number": "99999", "suppress_errors": true}'
    assert_failure
    refute_output --partial "error: pull request not found"
}

# =============================================================================
# fallback — tested via tool_pr_view
# =============================================================================

@test "fallback: gh failure returns fallback text and succeeds" {
    GH_STUB_EXIT=1
    GH_STUB_STDERR="error: not found"
    run tool_pr_view '{"number": "99999", "fallback": "PR not found"}'
    assert_success
    assert_output "PR not found"
}

@test "fallback: gh success returns normal output (fallback unused)" {
    GH_STUB_EXIT=0
    GH_STUB_OUTPUT="PR #123: my title"
    run tool_pr_view '{"number": "123", "fallback": "PR not found"}'
    assert_success
    assert_output "PR #123: my title"
}

@test "fallback with suppress_errors: both params coexist cleanly" {
    GH_STUB_EXIT=1
    run tool_pr_view '{"number": "99999", "suppress_errors": true, "fallback": "unavailable"}'
    assert_success
    assert_output "unavailable"
}

# =============================================================================
# jq_filter validation — new on tools that did not previously have it
# =============================================================================

@test "pr_view: invalid jq_filter is rejected before calling gh" {
    GH_STUB_EXIT=0
    GH_STUB_OUTPUT='some output'
    run tool_pr_view '{"number": "123", "jq_filter": "{{bad syntax"}'
    assert_failure
    assert_output --partial "Invalid jq_filter"
}

@test "pr_list: invalid jq_filter is rejected before calling gh" {
    run tool_pr_list '{"jq_filter": "{{broken"}'
    assert_failure
    assert_output --partial "Invalid jq_filter"
}

@test "pr_view: valid jq_filter passes validation and is applied to output" {
    GH_STUB_EXIT=0
    GH_STUB_OUTPUT='{"title":"hello world"}'
    run tool_pr_view '{"number": "123", "fields": "title", "jq_filter": ".title"}'
    assert_success
    assert_output '"hello world"'
}

# =============================================================================
# max_lines — tested via tool_pr_view
# =============================================================================

@test "pr_view: max_lines truncates output to first N lines" {
    GH_STUB_OUTPUT=$'line1\nline2\nline3\nline4\nline5'
    run tool_pr_view '{"number": "123", "max_lines": 3}'
    assert_success
    assert_output $'line1\nline2\nline3'
}

# =============================================================================
# tail_lines — tested via tool_api
# =============================================================================

@test "api: tail_lines returns last N lines" {
    GH_STUB_OUTPUT=$'item1\nitem2\nitem3\nitem4\nitem5'
    run tool_api '{"endpoint": "repos/shopware/shopware/issues", "tail_lines": 2}'
    assert_success
    assert_output $'item4\nitem5'
}

@test "api: max_lines and tail_lines combine" {
    GH_STUB_OUTPUT=$'a\nb\nc\nd\ne'
    run tool_api '{"endpoint": "repos/shopware/shopware/issues", "max_lines": 4, "tail_lines": 2}'
    assert_success
    assert_output $'c\nd'
}

# =============================================================================
# grep_pattern — tested via tool_run_logs
# =============================================================================

@test "run_logs: grep_pattern filters to matching lines only" {
    GH_STUB_OUTPUT=$'Step 1 passed\nERROR: test failed at line 42\nStep 3 passed'
    run tool_run_logs '{"run_id": "12345", "grep_pattern": "ERROR"}'
    assert_success
    assert_output "ERROR: test failed at line 42"
}

@test "run_logs: tail_lines returns last N log lines" {
    GH_STUB_OUTPUT=$'log line 1\nlog line 2\nlog line 3\nlog line 4\nlog line 5'
    run tool_run_logs '{"run_id": "12345", "tail_lines": 2}'
    assert_success
    assert_output $'log line 4\nlog line 5'
}

@test "run_logs: suppress_errors on failure returns empty output" {
    GH_STUB_EXIT=1
    GH_STUB_STDERR="error: run not found"
    run tool_run_logs '{"run_id": "99999", "suppress_errors": true}'
    assert_failure
    refute_output --partial "error: run not found"
}

@test "run_logs: fallback on failure returns fallback text" {
    GH_STUB_EXIT=1
    run tool_run_logs '{"run_id": "99999", "fallback": "no logs available"}'
    assert_success
    assert_output "no logs available"
}
