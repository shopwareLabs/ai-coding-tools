#!/usr/bin/env bats
# bats file_tags=gh-tooling,mcp-tools
# Tests for gh-tooling MCP server shared parameters:
#   _gh_validate_jq_filter, _gh_post_process, suppress_errors, fallback,
#   jq_filter validation on tools, max_lines, tail_lines, grep_pattern
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/gh-tooling"
GH_LIB_DIR="${PLUGIN_DIR}/mcp-server-gh/lib"

setup() {
    # Silence the log calls inside tool functions
    log() { :; }

    # Set a default repo so repo validation passes without requiring it per-test
    GH_DEFAULT_REPO="shopware/shopware"
    GH_TOOLING_CONFIG_FILE=""

    # Source shared helpers and the tool libraries under test
    source "${GH_LIB_DIR}/common.sh"
    source "${GH_LIB_DIR}/pr.sh"
    source "${GH_LIB_DIR}/run.sh"
    source "${GH_LIB_DIR}/api.sh"
    source "${GH_LIB_DIR}/commit.sh"
    source "${GH_LIB_DIR}/search.sh"
    source "${GH_LIB_DIR}/repo.sh"
    source "${GH_LIB_DIR}/issue.sh"
    source "${GH_LIB_DIR}/job.sh"

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
# DRY helper functions for parameterized cross-tool tests
# =============================================================================

# Assert tool returns stub output on success.
# Usage: assert_tool_success <tool_fn> <args_json> [expected_partial]
assert_tool_success() {
    local fn="$1" args="$2" expected="${3:-stub output}"
    GH_STUB_OUTPUT="${expected}"
    run "${fn}" "${args}"
    assert_success
    assert_output --partial "${expected}"
}

# Assert tool fails when a required param is missing.
# Usage: assert_tool_required_param <tool_fn> <param_name>
assert_tool_required_param() {
    local fn="$1" param_name="$2"
    run "${fn}" '{}'
    assert_failure
    assert_output --partial "${param_name} is required"
}

# Assert suppress_errors hides stderr on failure.
# Usage: assert_tool_suppress_errors <tool_fn> <args_json>
assert_tool_suppress_errors() {
    local fn="$1" args="$2"
    GH_STUB_EXIT=1
    GH_STUB_STDERR="hidden error text"
    run "${fn}" "${args}"
    assert_failure
    refute_output --partial "hidden error text"
}

# Assert fallback returns text and succeeds on failure.
# Usage: assert_tool_fallback <tool_fn> <args_json>
assert_tool_fallback() {
    local fn="$1" args="$2"
    GH_STUB_EXIT=1
    run "${fn}" "${args}"
    assert_success
    assert_output "fallback text"
}

# Assert invalid jq_filter is rejected before calling gh.
# Usage: assert_tool_jq_validation <tool_fn> <args_json>
assert_tool_jq_validation() {
    local fn="$1" args="$2"
    run "${fn}" "${args}"
    assert_failure
    assert_output --partial "Invalid jq_filter"
}

# Assert tools using _gh_require_repo fail when no repo is available.
# Usage: assert_tool_require_repo <tool_fn> <args_json>
assert_tool_require_repo() {
    local fn="$1" args="$2"
    GH_DEFAULT_REPO=""
    run "${fn}" "${args}"
    assert_failure
    assert_output --partial "repo is required"
}

# =============================================================================
# Parameterized cross-tool tests — basic success
# =============================================================================

_test_success_pr_checks()       { assert_tool_success tool_pr_checks '{"number":"123"}'; }
_test_success_pr_comments()     { assert_tool_success tool_pr_comments '{"number":"123"}'; }
_test_success_pr_reviews()      { assert_tool_success tool_pr_reviews '{"number":"123"}'; }
_test_success_pr_files()        { assert_tool_success tool_pr_files '{"number":"123"}'; }
_test_success_pr_commits()      { assert_tool_success tool_pr_commits '{"number":"123"}'; }
_test_success_pr_list()         { assert_tool_success tool_pr_list '{}'; }
_test_success_issue_view()      { assert_tool_success tool_issue_view '{"number":"42"}'; }
_test_success_issue_list()      { assert_tool_success tool_issue_list '{}'; }
_test_success_run_view()        { assert_tool_success tool_run_view '{"run_id":"12345"}'; }
_test_success_job_view()        { assert_tool_success tool_job_view '{"job_id":"99"}'; }
_test_success_job_logs()        { assert_tool_success tool_job_logs '{"job_id":"99"}'; }
_test_success_job_annotations() { assert_tool_success tool_job_annotations '{"check_run_id":"99"}'; }
_test_success_search()          { assert_tool_success tool_search '{"query":"test"}'; }

bats_test_function --description "pr_checks: basic success returns stub output"       -- _test_success_pr_checks
bats_test_function --description "pr_comments: basic success returns stub output"     -- _test_success_pr_comments
bats_test_function --description "pr_reviews: basic success returns stub output"      -- _test_success_pr_reviews
bats_test_function --description "pr_files: basic success returns stub output"        -- _test_success_pr_files
bats_test_function --description "pr_commits: basic success returns stub output"      -- _test_success_pr_commits
bats_test_function --description "pr_list: basic success returns stub output"         -- _test_success_pr_list
bats_test_function --description "issue_view: basic success returns stub output"      -- _test_success_issue_view
bats_test_function --description "issue_list: basic success returns stub output"      -- _test_success_issue_list
bats_test_function --description "run_view: basic success returns stub output"        -- _test_success_run_view
bats_test_function --description "job_view: basic success returns stub output"        -- _test_success_job_view
bats_test_function --description "job_logs: basic success returns stub output"        -- _test_success_job_logs
bats_test_function --description "job_annotations: basic success returns stub output" -- _test_success_job_annotations
bats_test_function --description "search: basic success returns stub output"          -- _test_success_search

# =============================================================================
# Parameterized cross-tool tests — suppress_errors
# =============================================================================

_test_suppress_pr_checks()       { assert_tool_suppress_errors tool_pr_checks '{"number":"123","suppress_errors":true}'; }
_test_suppress_pr_comments()     { assert_tool_suppress_errors tool_pr_comments '{"number":"123","suppress_errors":true}'; }
_test_suppress_pr_reviews()      { assert_tool_suppress_errors tool_pr_reviews '{"number":"123","suppress_errors":true}'; }
_test_suppress_pr_files()        { assert_tool_suppress_errors tool_pr_files '{"number":"123","suppress_errors":true}'; }
_test_suppress_pr_commits()      { assert_tool_suppress_errors tool_pr_commits '{"number":"123","suppress_errors":true}'; }
_test_suppress_pr_list()         { assert_tool_suppress_errors tool_pr_list '{"suppress_errors":true}'; }
_test_suppress_issue_view()      { assert_tool_suppress_errors tool_issue_view '{"number":"42","suppress_errors":true}'; }
_test_suppress_issue_list()      { assert_tool_suppress_errors tool_issue_list '{"suppress_errors":true}'; }
_test_suppress_run_view()        { assert_tool_suppress_errors tool_run_view '{"run_id":"12345","suppress_errors":true}'; }
_test_suppress_job_view()        { assert_tool_suppress_errors tool_job_view '{"job_id":"99","suppress_errors":true}'; }
_test_suppress_job_logs()        { assert_tool_suppress_errors tool_job_logs '{"job_id":"99","suppress_errors":true}'; }
_test_suppress_job_annotations() { assert_tool_suppress_errors tool_job_annotations '{"check_run_id":"99","suppress_errors":true}'; }
_test_suppress_search()          { assert_tool_suppress_errors tool_search '{"query":"test","suppress_errors":true}'; }

bats_test_function --description "pr_checks: suppress_errors hides stderr"       -- _test_suppress_pr_checks
bats_test_function --description "pr_comments: suppress_errors hides stderr"     -- _test_suppress_pr_comments
bats_test_function --description "pr_reviews: suppress_errors hides stderr"      -- _test_suppress_pr_reviews
bats_test_function --description "pr_files: suppress_errors hides stderr"        -- _test_suppress_pr_files
bats_test_function --description "pr_commits: suppress_errors hides stderr"      -- _test_suppress_pr_commits
bats_test_function --description "pr_list: suppress_errors hides stderr"         -- _test_suppress_pr_list
bats_test_function --description "issue_view: suppress_errors hides stderr"      -- _test_suppress_issue_view
bats_test_function --description "issue_list: suppress_errors hides stderr"      -- _test_suppress_issue_list
bats_test_function --description "run_view: suppress_errors hides stderr"        -- _test_suppress_run_view
bats_test_function --description "job_view: suppress_errors hides stderr"        -- _test_suppress_job_view
bats_test_function --description "job_logs: suppress_errors hides stderr"        -- _test_suppress_job_logs
bats_test_function --description "job_annotations: suppress_errors hides stderr" -- _test_suppress_job_annotations
bats_test_function --description "search: suppress_errors hides stderr"          -- _test_suppress_search

# =============================================================================
# Parameterized cross-tool tests — fallback
# =============================================================================

_test_fallback_pr_checks()       { assert_tool_fallback tool_pr_checks '{"number":"123","fallback":"fallback text"}'; }
_test_fallback_pr_comments()     { assert_tool_fallback tool_pr_comments '{"number":"123","fallback":"fallback text"}'; }
_test_fallback_pr_reviews()      { assert_tool_fallback tool_pr_reviews '{"number":"123","fallback":"fallback text"}'; }
_test_fallback_pr_files()        { assert_tool_fallback tool_pr_files '{"number":"123","fallback":"fallback text"}'; }
_test_fallback_pr_commits()      { assert_tool_fallback tool_pr_commits '{"number":"123","fallback":"fallback text"}'; }
_test_fallback_pr_list()         { assert_tool_fallback tool_pr_list '{"fallback":"fallback text"}'; }
_test_fallback_issue_view()      { assert_tool_fallback tool_issue_view '{"number":"42","fallback":"fallback text"}'; }
_test_fallback_issue_list()      { assert_tool_fallback tool_issue_list '{"fallback":"fallback text"}'; }
_test_fallback_run_view()        { assert_tool_fallback tool_run_view '{"run_id":"12345","fallback":"fallback text"}'; }
_test_fallback_job_view()        { assert_tool_fallback tool_job_view '{"job_id":"99","fallback":"fallback text"}'; }
_test_fallback_job_logs()        { assert_tool_fallback tool_job_logs '{"job_id":"99","fallback":"fallback text"}'; }
_test_fallback_job_annotations() { assert_tool_fallback tool_job_annotations '{"check_run_id":"99","fallback":"fallback text"}'; }
_test_fallback_search()          { assert_tool_fallback tool_search '{"query":"test","fallback":"fallback text"}'; }

bats_test_function --description "pr_checks: fallback on failure returns text"       -- _test_fallback_pr_checks
bats_test_function --description "pr_comments: fallback on failure returns text"     -- _test_fallback_pr_comments
bats_test_function --description "pr_reviews: fallback on failure returns text"      -- _test_fallback_pr_reviews
bats_test_function --description "pr_files: fallback on failure returns text"        -- _test_fallback_pr_files
bats_test_function --description "pr_commits: fallback on failure returns text"      -- _test_fallback_pr_commits
bats_test_function --description "pr_list: fallback on failure returns text"         -- _test_fallback_pr_list
bats_test_function --description "issue_view: fallback on failure returns text"      -- _test_fallback_issue_view
bats_test_function --description "issue_list: fallback on failure returns text"      -- _test_fallback_issue_list
bats_test_function --description "run_view: fallback on failure returns text"        -- _test_fallback_run_view
bats_test_function --description "job_view: fallback on failure returns text"        -- _test_fallback_job_view
bats_test_function --description "job_logs: fallback on failure returns text"        -- _test_fallback_job_logs
bats_test_function --description "job_annotations: fallback on failure returns text" -- _test_fallback_job_annotations
bats_test_function --description "search: fallback on failure returns text"          -- _test_fallback_search

# =============================================================================
# Parameterized cross-tool tests — required param missing
# =============================================================================

_test_required_pr_checks()       { assert_tool_required_param tool_pr_checks "number"; }
_test_required_pr_comments()     { assert_tool_required_param tool_pr_comments "number"; }
_test_required_pr_reviews()      { assert_tool_required_param tool_pr_reviews "number"; }
_test_required_pr_files()        { assert_tool_required_param tool_pr_files "number"; }
_test_required_pr_commits()      { assert_tool_required_param tool_pr_commits "number"; }
_test_required_issue_view()      { assert_tool_required_param tool_issue_view "number"; }
_test_required_run_view()        { assert_tool_required_param tool_run_view "run_id"; }
_test_required_job_view()        { assert_tool_required_param tool_job_view "job_id"; }
_test_required_job_logs()        { assert_tool_required_param tool_job_logs "job_id"; }
_test_required_job_annotations() { assert_tool_required_param tool_job_annotations "check_run_id"; }
_test_required_search()          { assert_tool_required_param tool_search "query"; }

bats_test_function --description "pr_checks: fails when number is missing"             -- _test_required_pr_checks
bats_test_function --description "pr_comments: fails when number is missing"           -- _test_required_pr_comments
bats_test_function --description "pr_reviews: fails when number is missing"            -- _test_required_pr_reviews
bats_test_function --description "pr_files: fails when number is missing"              -- _test_required_pr_files
bats_test_function --description "pr_commits: fails when number is missing"            -- _test_required_pr_commits
bats_test_function --description "issue_view: fails when number is missing"            -- _test_required_issue_view
bats_test_function --description "run_view: fails when run_id is missing"              -- _test_required_run_view
bats_test_function --description "job_view: fails when job_id is missing"              -- _test_required_job_view
bats_test_function --description "job_logs: fails when job_id is missing"              -- _test_required_job_logs
bats_test_function --description "job_annotations: fails when check_run_id is missing" -- _test_required_job_annotations
bats_test_function --description "search: fails when query is missing"                 -- _test_required_search

# =============================================================================
# Parameterized cross-tool tests — jq_filter validation
# =============================================================================

_test_jq_pr_comments()     { assert_tool_jq_validation tool_pr_comments '{"number":"123","jq_filter":"{{bad"}'; }
_test_jq_pr_reviews()      { assert_tool_jq_validation tool_pr_reviews '{"number":"123","jq_filter":"{{bad"}'; }
_test_jq_pr_files()        { assert_tool_jq_validation tool_pr_files '{"number":"123","jq_filter":"{{bad"}'; }
_test_jq_pr_commits()      { assert_tool_jq_validation tool_pr_commits '{"number":"123","jq_filter":"{{bad"}'; }
_test_jq_pr_list()         { assert_tool_jq_validation tool_pr_list '{"jq_filter":"{{bad"}'; }
_test_jq_issue_view()      { assert_tool_jq_validation tool_issue_view '{"number":"42","jq_filter":"{{bad"}'; }
_test_jq_issue_list()      { assert_tool_jq_validation tool_issue_list '{"jq_filter":"{{bad"}'; }
_test_jq_run_view()        { assert_tool_jq_validation tool_run_view '{"run_id":"12345","jq_filter":"{{bad"}'; }
_test_jq_job_view()        { assert_tool_jq_validation tool_job_view '{"job_id":"99","jq_filter":"{{bad"}'; }
_test_jq_job_annotations() { assert_tool_jq_validation tool_job_annotations '{"check_run_id":"99","jq_filter":"{{bad"}'; }
_test_jq_search()          { assert_tool_jq_validation tool_search '{"query":"test","jq_filter":"{{bad"}'; }

bats_test_function --description "pr_comments: invalid jq_filter rejected"     -- _test_jq_pr_comments
bats_test_function --description "pr_reviews: invalid jq_filter rejected"      -- _test_jq_pr_reviews
bats_test_function --description "pr_files: invalid jq_filter rejected"        -- _test_jq_pr_files
bats_test_function --description "pr_commits: invalid jq_filter rejected"      -- _test_jq_pr_commits
bats_test_function --description "pr_list (param): invalid jq_filter rejected" -- _test_jq_pr_list
bats_test_function --description "issue_view: invalid jq_filter rejected"      -- _test_jq_issue_view
bats_test_function --description "issue_list: invalid jq_filter rejected"      -- _test_jq_issue_list
bats_test_function --description "run_view: invalid jq_filter rejected"        -- _test_jq_run_view
bats_test_function --description "job_view: invalid jq_filter rejected"        -- _test_jq_job_view
bats_test_function --description "job_annotations: invalid jq_filter rejected" -- _test_jq_job_annotations
bats_test_function --description "search: invalid jq_filter rejected"          -- _test_jq_search

# =============================================================================
# Parameterized cross-tool tests — require_repo
# =============================================================================

_test_repo_pr_comments()     { assert_tool_require_repo tool_pr_comments '{"number":"123"}'; }
_test_repo_pr_reviews()      { assert_tool_require_repo tool_pr_reviews '{"number":"123"}'; }
_test_repo_pr_files()        { assert_tool_require_repo tool_pr_files '{"number":"123"}'; }
_test_repo_pr_commits()      { assert_tool_require_repo tool_pr_commits '{"number":"123"}'; }
_test_repo_job_view()        { assert_tool_require_repo tool_job_view '{"job_id":"99"}'; }
_test_repo_job_logs()        { assert_tool_require_repo tool_job_logs '{"job_id":"99"}'; }
_test_repo_job_annotations() { assert_tool_require_repo tool_job_annotations '{"check_run_id":"99"}'; }

bats_test_function --description "pr_comments: fails without repo"     -- _test_repo_pr_comments
bats_test_function --description "pr_reviews: fails without repo"      -- _test_repo_pr_reviews
bats_test_function --description "pr_files: fails without repo"        -- _test_repo_pr_files
bats_test_function --description "pr_commits: fails without repo"      -- _test_repo_pr_commits
bats_test_function --description "job_view: fails without repo"        -- _test_repo_job_view
bats_test_function --description "job_logs: fails without repo"        -- _test_repo_job_logs
bats_test_function --description "job_annotations: fails without repo" -- _test_repo_job_annotations

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
# pr_view — current branch PR resolution (no number + --repo)
# =============================================================================

@test "pr_view: no number without repo uses bare gh pr view" {
    GH_DEFAULT_REPO=""
    GH_STUB_OUTPUT="PR #42: my title"
    run tool_pr_view '{}'
    assert_success
    assert_output "PR #42: my title"
}

@test "pr_view: no number with repo resolves PR via current branch" {
    # Stub git to return a branch name
    git() {
        if [[ "$1" == "rev-parse" ]]; then
            echo "feature/my-branch"
            return 0
        fi
    }
    # Stub gh: pr list returns PR number, pr view returns details
    gh() {
        if [[ "$1" == "pr" && "$2" == "list" ]]; then
            echo "42"
            return 0
        fi
        if [[ "$1" == "pr" && "$2" == "view" ]]; then
            printf '%s\n' "${GH_STUB_OUTPUT}"
            return 0
        fi
    }
    GH_STUB_OUTPUT="PR #42: my title"
    run tool_pr_view '{}'
    assert_success
    assert_output "PR #42: my title"
}

@test "pr_view: no number with repo fails when no PR exists for branch" {
    git() {
        if [[ "$1" == "rev-parse" ]]; then
            echo "feature/no-pr-branch"
            return 0
        fi
    }
    gh() {
        if [[ "$1" == "pr" && "$2" == "list" ]]; then
            echo ""
            return 0
        fi
    }
    run tool_pr_view '{}'
    assert_failure
    assert_output --partial "no open pull request found for the current branch"
}

@test "pr_view: no number with repo fails on detached HEAD" {
    git() {
        if [[ "$1" == "rev-parse" ]]; then
            echo "HEAD"
            return 0
        fi
    }
    run tool_pr_view '{}'
    assert_failure
    assert_output --partial "no open pull request found for the current branch"
}

@test "pr_view: no number with repo fails when git is unavailable" {
    git() { return 1; }
    run tool_pr_view '{}'
    assert_failure
    assert_output --partial "no open pull request found for the current branch"
}

@test "pr_view: explicit number with repo skips branch resolution" {
    GH_STUB_OUTPUT="PR #99: explicit"
    run tool_pr_view '{"number": "99"}'
    assert_success
    assert_output "PR #99: explicit"
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

# =============================================================================
# commit_pulls
# =============================================================================

@test "commit_pulls: succeeds and returns PR list output" {
    GH_STUB_OUTPUT='[{"number":42}]'
    run tool_commit_pulls '{"sha":"abc1234"}'
    assert_success
    assert_output '[{"number":42}]'
}

@test "commit_pulls: custom jq_filter is applied to output" {
    GH_STUB_OUTPUT='[{"number":42},{"number":43}]'
    run tool_commit_pulls '{"sha":"abc1234","jq_filter":".[1].number"}'
    assert_success
    assert_output "43"
}

@test "commit_pulls: fails when sha is missing" {
    run tool_commit_pulls '{}'
    assert_failure
    assert_output --partial "sha is required"
}

@test "commit_pulls: suppress_errors on failure returns empty output without error text" {
    GH_STUB_EXIT=1
    GH_STUB_STDERR="No commit found for SHA"
    run tool_commit_pulls '{"sha":"abc1234","suppress_errors":true}'
    assert_failure
    refute_output --partial "No commit found for SHA"
}

@test "commit_pulls: fallback on failure returns fallback text" {
    GH_STUB_EXIT=1
    run tool_commit_pulls '{"sha":"abc1234","fallback":"no PRs found"}'
    assert_success
    assert_output "no PRs found"
}

# =============================================================================
# _gh_parse_github_url — unit tests
# =============================================================================

@test "_gh_parse_github_url: parses tree URL with ref and path" {
    _gh_parse_github_url "https://github.com/shopware/shopware/tree/main/src/Core"
    assert_equal "${_GH_URL_OWNER}" "shopware"
    assert_equal "${_GH_URL_REPO}" "shopware"
    assert_equal "${_GH_URL_REF}" "main"
    assert_equal "${_GH_URL_PATH}" "src/Core"
}

@test "_gh_parse_github_url: parses blob URL" {
    _gh_parse_github_url "https://github.com/shopware/shopware/blob/main/composer.json"
    assert_equal "${_GH_URL_OWNER}" "shopware"
    assert_equal "${_GH_URL_REPO}" "shopware"
    assert_equal "${_GH_URL_REF}" "main"
    assert_equal "${_GH_URL_PATH}" "composer.json"
}

@test "_gh_parse_github_url: parses repo-only URL" {
    _gh_parse_github_url "https://github.com/shopware/shopware"
    assert_equal "${_GH_URL_OWNER}" "shopware"
    assert_equal "${_GH_URL_REPO}" "shopware"
    assert_equal "${_GH_URL_REF}" ""
    assert_equal "${_GH_URL_PATH}" ""
}

@test "_gh_parse_github_url: rejects non-GitHub URL" {
    run _gh_parse_github_url "https://gitlab.com/foo/bar"
    assert_failure
}

# =============================================================================
# _gh_validate_path — unit tests
# =============================================================================

@test "_gh_validate_path: accepts valid path" {
    run _gh_validate_path "src/Core/Content"
    assert_success
}

@test "_gh_validate_path: accepts empty path (repo root)" {
    run _gh_validate_path ""
    assert_success
}

@test "_gh_validate_path: rejects leading slash" {
    run _gh_validate_path "/src/Core"
    assert_failure
    assert_output --partial "must not start with '/'"
}

@test "_gh_validate_path: rejects path traversal" {
    run _gh_validate_path "src/../etc/passwd"
    assert_failure
    assert_output --partial "must not contain '..'"
}

# =============================================================================
# _gh_resolve_owner_repo — unit tests
# =============================================================================

@test "_gh_resolve_owner_repo: resolves from URL" {
    _gh_resolve_owner_repo '{"url": "https://github.com/foo/bar/tree/main/src"}'
    assert_equal "${_GH_OWNER}" "foo"
    assert_equal "${_GH_REPO}" "bar"
    assert_equal "${_GH_REF}" "main"
    assert_equal "${_GH_PATH}" "src"
}

@test "_gh_resolve_owner_repo: resolves from repository string" {
    _gh_resolve_owner_repo '{"repository": "foo/bar", "path": "src"}'
    assert_equal "${_GH_OWNER}" "foo"
    assert_equal "${_GH_REPO}" "bar"
    assert_equal "${_GH_PATH}" "src"
}

@test "_gh_resolve_owner_repo: falls back to GH_DEFAULT_REPO" {
    GH_DEFAULT_REPO="default/repo"
    _gh_resolve_owner_repo '{}'
    assert_equal "${_GH_OWNER}" "default"
    assert_equal "${_GH_REPO}" "repo"
}

@test "_gh_resolve_owner_repo: fails when no repo available" {
    GH_DEFAULT_REPO=""
    run _gh_resolve_owner_repo '{}'
    assert_failure
    assert_output --partial "repository is required"
}

# =============================================================================
# search_code
# =============================================================================

@test "search_code: succeeds with stub output" {
    GH_STUB_OUTPUT='[{"repository":{"nameWithOwner":"shopware/shopware"},"path":"src/file.php","textMatch":"match"}]'
    run tool_search_code '{"query":"addClass"}'
    assert_success
    assert_output --partial "shopware/shopware"
}

@test "search_code: uses GH_DEFAULT_REPO when no explicit repo provided" {
    # Regression: search_code must fall back to GH_DEFAULT_REPO like tool_search does
    GH_DEFAULT_REPO="default/repo"
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_search_code '{"query":"test"}'
    assert_success
    # The --repo flag must appear in the command with the default repo value
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--repo default/repo"* ]] || {
        echo "Expected --repo default/repo in command: ${captured_cmd}"
        return 1
    }
}

@test "search_code: explicit repo overrides GH_DEFAULT_REPO" {
    GH_DEFAULT_REPO="default/repo"
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_search_code '{"query":"test","repo":"explicit/repo"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--repo explicit/repo"* ]] || {
        echo "Expected --repo explicit/repo in command: ${captured_cmd}"
        return 1
    }
}

@test "search_code: owner used when no repo and no GH_DEFAULT_REPO" {
    GH_DEFAULT_REPO=""
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_search_code '{"query":"test","owner":"myorg"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--owner myorg"* ]] || {
        echo "Expected --owner myorg in command: ${captured_cmd}"
        return 1
    }
}

@test "search_code: fails when query is missing" {
    run tool_search_code '{}'
    assert_failure
    assert_output --partial "query is required"
}

@test "search_code: suppress_errors on failure hides error" {
    GH_STUB_EXIT=1
    GH_STUB_STDERR="rate limit exceeded"
    run tool_search_code '{"query":"test","suppress_errors":true}'
    assert_failure
    refute_output --partial "rate limit"
}

@test "search_code: fallback on failure returns fallback text" {
    GH_STUB_EXIT=1
    run tool_search_code '{"query":"test","fallback":"no results"}'
    assert_success
    assert_output "no results"
}

# =============================================================================
# search_repos
# =============================================================================

@test "search_repos: succeeds with stub output" {
    GH_STUB_OUTPUT='[{"fullName":"shopware/shopware","description":"ecommerce"}]'
    run tool_search_repos '{"owner":"shopware"}'
    assert_success
    assert_output --partial "shopware/shopware"
}

@test "search_repos: works without query (filter-only)" {
    GH_STUB_OUTPUT='[{"fullName":"shopware/shopware"}]'
    run tool_search_repos '{"owner":"shopware","language":"php"}'
    assert_success
    assert_output --partial "shopware/shopware"
}

@test "search_repos: invalid sort is rejected" {
    run tool_search_repos '{"query":"test","sort":"invalid"}'
    assert_failure
    assert_output --partial "sort must be"
}

# =============================================================================
# search_commits
# =============================================================================

@test "search_commits: succeeds with stub output" {
    GH_STUB_OUTPUT='[{"sha":"abc123","commit":{"message":"NEXT-1234 fix"}}]'
    run tool_search_commits '{"query":"NEXT-1234"}'
    assert_success
    assert_output --partial "NEXT-1234"
}

@test "search_commits: uses GH_DEFAULT_REPO when no explicit repo provided" {
    # Regression: search_commits must fall back to GH_DEFAULT_REPO like tool_search does
    GH_DEFAULT_REPO="default/repo"
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_search_commits '{"query":"test"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--repo default/repo"* ]] || {
        echo "Expected --repo default/repo in command: ${captured_cmd}"
        return 1
    }
}

@test "search_commits: fails when query is missing" {
    run tool_search_commits '{}'
    assert_failure
    assert_output --partial "query is required"
}

@test "search_commits: invalid sort is rejected" {
    run tool_search_commits '{"query":"test","sort":"invalid"}'
    assert_failure
    assert_output --partial "sort must be"
}

# =============================================================================
# search_discussions
# =============================================================================

@test "search_discussions: succeeds with stub GraphQL output" {
    GH_STUB_OUTPUT='{"data":{"search":{"nodes":[{"number":1,"title":"RFC: New API"}]}}}'
    run tool_search_discussions '{"query":"RFC"}'
    assert_success
    assert_output --partial "RFC: New API"
}

@test "search_discussions: fails when query is missing" {
    run tool_search_discussions '{}'
    assert_failure
    assert_output --partial "query is required"
}

@test "search_discussions: invalid jq_filter is rejected" {
    run tool_search_discussions '{"query":"RFC","jq_filter":"{{bad"}'
    assert_failure
    assert_output --partial "Invalid jq_filter"
}

@test "search_discussions: query with double quotes is escaped for GraphQL" {
    # Regression: unescaped " in query would break GraphQL string interpolation
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '{"data":{"search":{"nodes":[]}}}'
    }
    run tool_search_discussions '{"query":"say \"hello\" world"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    # The escaped quotes must appear in the GraphQL query passed to gh
    [[ "${captured_cmd}" == *'say \"hello\" world'* ]] || [[ "${captured_cmd}" == *'say \\"hello\\" world'* ]] || {
        echo "Expected escaped quotes in command: ${captured_cmd}"
        return 1
    }
}

@test "search_discussions: query with backslashes is escaped for GraphQL" {
    # Regression: backslashes in query were not escaped, breaking GraphQL interpolation
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '{"data":{"search":{"nodes":[]}}}'
    }
    run tool_search_discussions '{"query":"path\\to\\file"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    # Backslashes must be doubled in the GraphQL query
    [[ "${captured_cmd}" == *'path\\\\to\\\\file'* ]] || [[ "${captured_cmd}" == *'path\\to\\file'* ]] || {
        echo "Expected escaped backslashes in command: ${captured_cmd}"
        return 1
    }
}

# =============================================================================
# repo_tree
# =============================================================================

@test "repo_tree: succeeds with stub output" {
    GH_STUB_OUTPUT='[{"name":"src","type":"dir","size":0,"path":"src"},{"name":"README.md","type":"file","size":1024,"path":"README.md"}]'
    run tool_repo_tree '{"repository":"shopware/shopware"}'
    assert_success
    assert_output --partial "src"
}

@test "repo_tree: resolves from repository param" {
    GH_STUB_OUTPUT='[{"name":"README.md","type":"file","size":100,"path":"README.md"}]'
    run tool_repo_tree '{"repository":"shopware/shopware","path":"src/Core"}'
    assert_success
    assert_output --partial "README.md"
}

@test "repo_tree: rejects path traversal" {
    run tool_repo_tree '{"repository":"shopware/shopware","path":"src/../etc/passwd"}'
    assert_failure
    assert_output --partial "must not contain '..'"
}

@test "repo_tree: fails when no repo available" {
    GH_DEFAULT_REPO=""
    run tool_repo_tree '{}'
    assert_failure
    assert_output --partial "repository is required"
}

@test "repo_tree: recursive path with double quotes does not break jq filter" {
    # Regression: path containing " was interpolated raw into jq, breaking the filter
    GH_STUB_OUTPUT='{"tree":[{"path":"src/weird\"dir/file.php","type":"blob","size":100}]}'
    run tool_repo_tree '{"repository":"shopware/shopware","path":"src/weird\"dir","recursive":true}'
    assert_success
    # Should not fail with a jq error — the quotes must be escaped
    refute_output --partial "Error: jq filter failed"
}

# =============================================================================
# repo_file
# =============================================================================

@test "repo_file: succeeds with stub output" {
    GH_STUB_OUTPUT='{"name": "shopware/shopware", "version": "6.6.0"}'
    run tool_repo_file '{"repository":"shopware/shopware","path":"composer.json"}'
    assert_success
    assert_output --partial "shopware/shopware"
}

@test "repo_file: fails when path is missing" {
    run tool_repo_file '{"repository":"shopware/shopware"}'
    assert_failure
    assert_output --partial "path is required"
}

@test "repo_file: grep_pattern filters output" {
    GH_STUB_OUTPUT=$'line 1: foo\nline 2: bar\nline 3: foo again'
    run tool_repo_file '{"repository":"shopware/shopware","path":"file.txt","grep_pattern":"foo"}'
    assert_success
    assert_output $'line 1: foo\nline 3: foo again'
}

@test "repo_file: tail_lines returns last N lines" {
    GH_STUB_OUTPUT=$'line 1\nline 2\nline 3\nline 4\nline 5'
    run tool_repo_file '{"repository":"shopware/shopware","path":"file.txt","tail_lines":2}'
    assert_success
    assert_output $'line 4\nline 5'
}

@test "repo_file: fallback on failure returns fallback text" {
    GH_STUB_EXIT=1
    run tool_repo_file '{"repository":"shopware/shopware","path":"missing.txt","fallback":"file not found"}'
    assert_success
    assert_output "file not found"
}

@test "repo_file: line_start and line_end extract line range" {
    GH_STUB_OUTPUT=$'line 1\nline 2\nline 3\nline 4\nline 5'
    run tool_repo_file '{"repository":"shopware/shopware","path":"file.txt","line_start":2,"line_end":4}'
    assert_success
    assert_output $'line 2\nline 3\nline 4'
}

@test "repo_file: non-integer line_start is rejected" {
    # Regression: unvalidated line_start was passed directly to sed
    GH_STUB_OUTPUT='some content'
    run tool_repo_file '{"repository":"shopware/shopware","path":"file.txt","line_start":"evil"}'
    assert_failure
    assert_output --partial "line_start must be a positive integer"
}

@test "repo_file: non-integer line_end is rejected" {
    # Regression: unvalidated line_end was passed directly to sed
    GH_STUB_OUTPUT='some content'
    run tool_repo_file '{"repository":"shopware/shopware","path":"file.txt","line_end":"1;d"}'
    assert_failure
    assert_output --partial "line_end must be a positive integer"
}

@test "repo_file: download_to saves file and returns confirmation" {
    local dl_dir="${BATS_TEST_TMPDIR}/downloads"
    GH_STUB_OUTPUT='{"key": "value"}'
    # Override gh to write to stdout (simulating raw file content)
    gh() { echo '{"key": "value"}'; }
    run tool_repo_file '{"repository":"shopware/shopware","path":"composer.json","download_to":"'"${dl_dir}/composer.json"'"}'
    assert_success
    assert_output --partial "Downloaded"
    assert_output --partial "composer.json"
}

@test "repo_file: download_to on failure does not leave partial file" {
    # Regression: API errors were written into the download file instead of being captured
    local dl_path="${BATS_TEST_TMPDIR}/should_not_exist.json"
    GH_STUB_EXIT=1
    GH_STUB_STDERR="Not Found"
    run tool_repo_file '{"repository":"shopware/shopware","path":"nonexistent.txt","download_to":"'"${dl_path}"'"}'
    assert_failure
    # The partial/error file must be cleaned up
    [[ ! -f "${dl_path}" ]] || {
        echo "Partial download file should have been removed: ${dl_path}"
        return 1
    }
}

@test "repo_file: download_to on failure returns stderr in output (not in file)" {
    # Regression: stderr was redirected into the download file via 2>&1 instead of being
    # captured separately in __dl_err. If reverted, the error message would vanish from
    # output (written into the file and then deleted by rm -f).
    local dl_path="${BATS_TEST_TMPDIR}/stderr_test.json"
    GH_STUB_EXIT=1
    GH_STUB_STDERR="API error: Not Found"
    run tool_repo_file '{"repository":"shopware/shopware","path":"missing.txt","download_to":"'"${dl_path}"'"}'
    assert_failure
    # The captured stderr must appear in tool output (proves __dl_err was set)
    assert_output --partial "API error: Not Found"
}

@test "repo_file: download_to on failure returns fallback when provided" {
    local dl_path="${BATS_TEST_TMPDIR}/fallback_test.json"
    GH_STUB_EXIT=1
    run tool_repo_file '{"repository":"shopware/shopware","path":"missing.txt","download_to":"'"${dl_path}"'","fallback":"not available"}'
    assert_success
    assert_output "not available"
}

# =============================================================================
# run_list — new filter params
# =============================================================================

@test "run_list: workflow and status filters passed to gh" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_run_list '{"workflow":"CI","status":"failure","limit":5}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--workflow CI"* ]] || {
        echo "Expected --workflow CI in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" == *"--status failure"* ]] || {
        echo "Expected --status failure in command: ${captured_cmd}"
        return 1
    }
}

@test "run_list: event, user, created, commit filters passed to gh" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_run_list '{"event":"push","user":"mitelg","created":">2024-01-01","commit":"abc1234"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--event push"* ]] || {
        echo "Expected --event push in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" == *"--user mitelg"* ]] || {
        echo "Expected --user mitelg in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" == *"--created >2024-01-01"* ]] || {
        echo "Expected --created in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" == *"--commit abc1234"* ]] || {
        echo "Expected --commit abc1234 in command: ${captured_cmd}"
        return 1
    }
}

# =============================================================================
# workflow_jobs
# =============================================================================

@test "workflow_jobs: fails without workflow param" {
    run tool_workflow_jobs '{}'
    assert_failure
    assert_output --partial "workflow is required"
}

@test "workflow_jobs: fails without repo" {
    GH_DEFAULT_REPO=""
    run tool_workflow_jobs '{"workflow":"CI"}'
    assert_failure
    assert_output --partial "repo is required"
}

@test "workflow_jobs: returns [] when no runs found" {
    gh() {
        if [[ "$1" == "run" && "$2" == "list" ]]; then
            echo '[]'
            return 0
        fi
    }
    run tool_workflow_jobs '{"workflow":"CI"}'
    assert_success
    assert_output "[]"
}

@test "workflow_jobs: jq_filter is validated before execution" {
    run tool_workflow_jobs '{"workflow":"CI","jq_filter":"{{bad syntax"}'
    assert_failure
    assert_output --partial "Invalid jq_filter"
}

@test "workflow_jobs: aggregates jobs from multiple runs" {
    gh() {
        if [[ "$1" == "run" && "$2" == "list" ]]; then
            echo '[{"databaseId":100,"displayTitle":"Run 100","headBranch":"main","status":"completed","conclusion":"failure","createdAt":"2024-01-01T00:00:00Z"},{"databaseId":200,"displayTitle":"Run 200","headBranch":"main","status":"completed","conclusion":"success","createdAt":"2024-01-02T00:00:00Z"}]'
            return 0
        fi
        if [[ "$1" == "api" ]]; then
            if [[ "$2" == *"/100/"* ]]; then
                echo '{"jobs":[{"id":1001,"name":"PHPStan","status":"completed","conclusion":"failure","html_url":"https://github.com/a/b/actions/runs/100/jobs/1001","started_at":"2024-01-01T00:01:00Z","completed_at":"2024-01-01T00:02:00Z","steps":[]}]}'
                return 0
            fi
            if [[ "$2" == *"/200/"* ]]; then
                echo '{"jobs":[{"id":2001,"name":"PHPStan","status":"completed","conclusion":"success","html_url":"https://github.com/a/b/actions/runs/200/jobs/2001","started_at":"2024-01-02T00:01:00Z","completed_at":"2024-01-02T00:02:00Z","steps":[]}]}'
                return 0
            fi
        fi
    }
    run tool_workflow_jobs '{"workflow":"CI","job":"phpstan"}'
    assert_success
    # Should contain both jobs
    local output_json
    output_json=$(echo "${output}" | jq 'length')
    [[ "${output_json}" == "2" ]] || {
        echo "Expected 2 jobs, got: ${output_json}, output: ${output}"
        return 1
    }
}

@test "workflow_jobs: conclusion filter works" {
    gh() {
        if [[ "$1" == "run" && "$2" == "list" ]]; then
            echo '[{"databaseId":100,"displayTitle":"Run","headBranch":"main","status":"completed","conclusion":"failure","createdAt":"2024-01-01T00:00:00Z"}]'
            return 0
        fi
        if [[ "$1" == "api" ]]; then
            echo '{"jobs":[{"id":1001,"name":"PHPStan","status":"completed","conclusion":"failure","html_url":"","started_at":"","completed_at":"","steps":[]},{"id":1002,"name":"ESLint","status":"completed","conclusion":"success","html_url":"","started_at":"","completed_at":"","steps":[]}]}'
            return 0
        fi
    }
    run tool_workflow_jobs '{"workflow":"CI","conclusion":"failure"}'
    assert_success
    local count
    count=$(echo "${output}" | jq 'length')
    [[ "${count}" == "1" ]] || {
        echo "Expected 1 job with conclusion=failure, got: ${count}"
        return 1
    }
    local job_name
    job_name=$(echo "${output}" | jq -r '.[0].name')
    [[ "${job_name}" == "PHPStan" ]] || {
        echo "Expected PHPStan, got: ${job_name}"
        return 1
    }
}

@test "workflow_jobs: special chars in job name do not break jq filter" {
    # Regression: raw string interpolation into jq would break on special chars
    gh() {
        if [[ "$1" == "run" && "$2" == "list" ]]; then
            echo '[{"databaseId":100,"displayTitle":"Run","headBranch":"main","status":"completed","conclusion":"failure","createdAt":"2024-01-01T00:00:00Z"}]'
            return 0
        fi
        if [[ "$1" == "api" ]]; then
            echo '{"jobs":[{"id":1001,"name":"PHPUnit (\"fast\")","status":"completed","conclusion":"success","html_url":"","started_at":"","completed_at":"","steps":[]}]}'
            return 0
        fi
    }
    run tool_workflow_jobs '{"workflow":"CI","job":"PHPUnit (\"fast\")"}'
    assert_success
    # Should not fail with a jq error
    refute_output --partial "Error"
    local count
    count=$(echo "${output}" | jq 'length')
    [[ "${count}" == "1" ]] || {
        echo "Expected 1 matching job, got: ${count}, output: ${output}"
        return 1
    }
}

@test "workflow_jobs: special chars in step name do not break jq filter" {
    # Regression: same class of bug as job name — step filter uses jq --arg too
    gh() {
        if [[ "$1" == "run" && "$2" == "list" ]]; then
            echo '[{"databaseId":100,"displayTitle":"Run","headBranch":"main","status":"completed","conclusion":"failure","createdAt":"2024-01-01T00:00:00Z"}]'
            return 0
        fi
        if [[ "$1" == "api" ]]; then
            echo '{"jobs":[{"id":1001,"name":"Tests","status":"completed","conclusion":"success","html_url":"","started_at":"","completed_at":"","steps":[{"name":"Run \"unit\" tests","status":"completed","conclusion":"success","number":1}]}]}'
            return 0
        fi
    }
    run tool_workflow_jobs '{"workflow":"CI","step":"Run \"unit\" tests"}'
    assert_success
    refute_output --partial "Error"
    # Steps should be included since step filter is set
    local step_count
    step_count=$(echo "${output}" | jq '.[0].steps | length')
    [[ "${step_count}" == "1" ]] || {
        echo "Expected 1 matching step, got: ${step_count}, output: ${output}"
        return 1
    }
}

@test "workflow_jobs: steps excluded by default when no step filter" {
    gh() {
        if [[ "$1" == "run" && "$2" == "list" ]]; then
            echo '[{"databaseId":100,"displayTitle":"Run","headBranch":"main","status":"completed","conclusion":"success","createdAt":"2024-01-01T00:00:00Z"}]'
            return 0
        fi
        if [[ "$1" == "api" ]]; then
            echo '{"jobs":[{"id":1001,"name":"PHPStan","status":"completed","conclusion":"success","html_url":"","started_at":"","completed_at":"","steps":[{"name":"Checkout","number":1},{"name":"Run PHPStan","number":2}]}]}'
            return 0
        fi
    }
    run tool_workflow_jobs '{"workflow":"CI"}'
    assert_success
    # Steps should be null/absent in output when no step filter is set
    local has_steps
    has_steps=$(echo "${output}" | jq '.[0].steps // null')
    [[ "${has_steps}" == "null" ]] || {
        echo "Expected steps to be excluded, got: ${has_steps}"
        return 1
    }
}

@test "workflow_jobs: run_status and branch passed to run list" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        if [[ "$1" == "run" && "$2" == "list" ]]; then
            echo '[]'
            return 0
        fi
    }
    run tool_workflow_jobs '{"workflow":"CI","run_status":"failure","branch":"main","event":"push"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--status failure"* ]] || {
        echo "Expected --status failure in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" == *"--branch main"* ]] || {
        echo "Expected --branch main in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" == *"--event push"* ]] || {
        echo "Expected --event push in command: ${captured_cmd}"
        return 1
    }
}

@test "workflow_jobs: jq_filter applied to final output" {
    gh() {
        if [[ "$1" == "run" && "$2" == "list" ]]; then
            echo '[{"databaseId":100,"displayTitle":"Run","headBranch":"main","status":"completed","conclusion":"failure","createdAt":"2024-01-01T00:00:00Z"}]'
            return 0
        fi
        if [[ "$1" == "api" ]]; then
            echo '{"jobs":[{"id":1001,"name":"PHPStan","status":"completed","conclusion":"failure","html_url":"","started_at":"","completed_at":"","steps":[]}]}'
            return 0
        fi
    }
    run tool_workflow_jobs '{"workflow":"CI","jq_filter":".[0].name"}'
    assert_success
    assert_output '"PHPStan"'
}

@test "workflow_jobs: max_lines truncates output" {
    gh() {
        if [[ "$1" == "run" && "$2" == "list" ]]; then
            echo '[{"databaseId":100,"displayTitle":"Run","headBranch":"main","status":"completed","conclusion":"failure","createdAt":"2024-01-01T00:00:00Z"}]'
            return 0
        fi
        if [[ "$1" == "api" ]]; then
            echo '{"jobs":[{"id":1001,"name":"PHPStan","status":"completed","conclusion":"failure","html_url":"","started_at":"","completed_at":"","steps":[]},{"id":1002,"name":"ESLint","status":"completed","conclusion":"success","html_url":"","started_at":"","completed_at":"","steps":[]}]}'
            return 0
        fi
    }
    run tool_workflow_jobs '{"workflow":"CI","max_lines":1}'
    assert_success
    # Output should be truncated to 1 line
    local line_count
    line_count=$(echo "${output}" | wc -l | tr -d ' ')
    [[ "${line_count}" == "1" ]] || {
        echo "Expected 1 line, got: ${line_count}"
        return 1
    }
}

@test "workflow_jobs: partial API failure skips failed run" {
    gh() {
        if [[ "$1" == "run" && "$2" == "list" ]]; then
            echo '[{"databaseId":100,"displayTitle":"Run 100","headBranch":"main","status":"completed","conclusion":"failure","createdAt":"2024-01-01T00:00:00Z"},{"databaseId":200,"displayTitle":"Run 200","headBranch":"main","status":"completed","conclusion":"success","createdAt":"2024-01-02T00:00:00Z"}]'
            return 0
        fi
        if [[ "$1" == "api" ]]; then
            # Run 100 fails, run 200 succeeds
            if [[ "$2" == *"/100/"* ]]; then
                echo "API error" >&2
                return 1
            fi
            if [[ "$2" == *"/200/"* ]]; then
                echo '{"jobs":[{"id":2001,"name":"PHPStan","status":"completed","conclusion":"success","html_url":"","started_at":"","completed_at":"","steps":[]}]}'
                return 0
            fi
        fi
    }
    run tool_workflow_jobs '{"workflow":"CI"}'
    assert_success
    # Should still return jobs from the successful run
    local count
    count=$(echo "${output}" | jq 'length')
    [[ "${count}" == "1" ]] || {
        echo "Expected 1 job (from successful run), got: ${count}"
        return 1
    }
}

@test "workflow_jobs: suppress_errors hides run list stderr" {
    gh() {
        echo "gh error output" >&2
        return 1
    }
    run tool_workflow_jobs '{"workflow":"CI","suppress_errors":true}'
    assert_failure
    refute_output --partial "gh error output"
}

@test "run_list: omitted params not passed to gh" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_run_list '{"limit":5}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" != *"--workflow"* ]] || {
        echo "Unexpected --workflow in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" != *"--status"* ]] || {
        echo "Unexpected --status in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" != *"--event"* ]] || {
        echo "Unexpected --event in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" != *"--user"* ]] || {
        echo "Unexpected --user in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" != *"--created"* ]] || {
        echo "Unexpected --created in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" != *"--commit"* ]] || {
        echo "Unexpected --commit in command: ${captured_cmd}"
        return 1
    }
}

@test "workflow_jobs: fallback on run list failure" {
    GH_STUB_EXIT=1
    run tool_workflow_jobs '{"workflow":"CI","fallback":"no runs"}'
    assert_success
    assert_output "no runs"
}

# =============================================================================
# pr_diff — file filter post-processing
# =============================================================================

@test "pr_diff: succeeds with basic diff output" {
    GH_STUB_OUTPUT='diff --git a/src/File.php b/src/File.php
--- a/src/File.php
+++ b/src/File.php
@@ -1,3 +1,3 @@
-old line
+new line'
    run tool_pr_diff '{"number": "123"}'
    assert_success
    assert_output "${GH_STUB_OUTPUT}"
}

@test "pr_diff: file filter extracts matching file from multi-file diff" {
    GH_STUB_OUTPUT='diff --git a/src/First.php b/src/First.php
--- a/src/First.php
+++ b/src/First.php
@@ -1,3 +1,3 @@
-old first
+new first
diff --git a/src/Second.php b/src/Second.php
--- a/src/Second.php
+++ b/src/Second.php
@@ -1,3 +1,3 @@
-old second
+new second
diff --git a/src/Third.php b/src/Third.php
--- a/src/Third.php
+++ b/src/Third.php
@@ -1,3 +1,3 @@
-old third
+new third'
    run tool_pr_diff '{"number": "123", "file": "src/Second.php"}'
    assert_success
    assert_output 'diff --git a/src/Second.php b/src/Second.php
--- a/src/Second.php
+++ b/src/Second.php
@@ -1,3 +1,3 @@
-old second
+new second'
}

@test "pr_diff: file filter returns empty when file not in diff" {
    GH_STUB_OUTPUT='diff --git a/src/Other.php b/src/Other.php
--- a/src/Other.php
+++ b/src/Other.php
@@ -1 +1 @@
-old
+new'
    run tool_pr_diff '{"number": "123", "file": "src/Missing.php"}'
    assert_success
    assert_output ""
}

@test "pr_diff: file filter does not pass -- to gh command" {
    # Verify that the file param is NOT passed to gh as a CLI arg.
    # A gh stub that fails on extra args proves the fix works.
    gh() {
        if [[ "$3" == "diff" && "$#" -gt 4 ]]; then
            echo "Error: accepts at most 1 arg(s), received $(($# - 3))"
            return 1
        fi
        echo 'diff --git a/src/File.php b/src/File.php
--- a/src/File.php
+++ b/src/File.php
@@ -1 +1 @@
-old
+new'
        return 0
    }
    run tool_pr_diff '{"number": "123", "file": "src/File.php"}'
    assert_success
    refute_output --partial "accepts at most 1 arg"
}

@test "pr_diff: fails when number is missing" {
    run tool_pr_diff '{}'
    assert_failure
    assert_output --partial "number is required"
}

# =============================================================================
# pr_checks — tool-specific tests
# =============================================================================

@test "pr_checks: max_lines truncates output" {
    GH_STUB_OUTPUT=$'check1\tpass\ncheck2\tfail\ncheck3\tpass\ncheck4\tskip'
    run tool_pr_checks '{"number":"123","max_lines":2}'
    assert_success
    assert_output $'check1\tpass\ncheck2\tfail'
}

# =============================================================================
# pr_comments — tool-specific tests
# =============================================================================

@test "pr_comments: builds correct API endpoint" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_pr_comments '{"number":"42"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"repos/shopware/shopware/pulls/42/comments"* ]] || {
        echo "Expected pulls/42/comments endpoint in command: ${captured_cmd}"
        return 1
    }
}

@test "pr_comments: paginate true by default adds --paginate" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_pr_comments '{"number":"42"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--paginate"* ]] || {
        echo "Expected --paginate in command: ${captured_cmd}"
        return 1
    }
}

@test "pr_comments: paginate false omits --paginate" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    # Note: must use string "false" — jq's // treats boolean false as null
    run tool_pr_comments '{"number":"42","paginate":"false"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" != *"--paginate"* ]] || {
        echo "Unexpected --paginate in command: ${captured_cmd}"
        return 1
    }
}

# =============================================================================
# pr_reviews — tool-specific tests
# =============================================================================

@test "pr_reviews: builds correct API endpoint" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_pr_reviews '{"number":"42"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"repos/shopware/shopware/pulls/42/reviews"* ]] || {
        echo "Expected pulls/42/reviews endpoint in command: ${captured_cmd}"
        return 1
    }
}

# =============================================================================
# pr_files — tool-specific tests
# =============================================================================

@test "pr_files: applies default jq_filter with filename/status/additions/deletions" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_pr_files '{"number":"42"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--jq"* ]] || {
        echo "Expected --jq in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" == *"filename"* ]] || {
        echo "Expected filename in default jq_filter: ${captured_cmd}"
        return 1
    }
}

@test "pr_files: custom jq_filter overrides default" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_pr_files '{"number":"42","jq_filter":".[] | .patch"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *".patch"* ]] || {
        echo "Expected custom .patch filter in command: ${captured_cmd}"
        return 1
    }
}

# =============================================================================
# pr_commits — tool-specific tests
# =============================================================================

@test "pr_commits: default jq_filter extracts sha and message" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_pr_commits '{"number":"42"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--jq"* ]] || {
        echo "Expected --jq in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" == *"sha"* ]] || {
        echo "Expected sha in default jq_filter: ${captured_cmd}"
        return 1
    }
}

# =============================================================================
# pr_list — tool-specific tests
# =============================================================================

@test "pr_list: author/state/search/head filters passed to gh" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_pr_list '{"author":"dev","state":"open","search":"bug","head":"feature/x"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--author dev"* ]] || {
        echo "Expected --author dev in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" == *"--state open"* ]] || {
        echo "Expected --state open in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" == *"--search bug"* ]] || {
        echo "Expected --search bug in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" == *"--head feature/x"* ]] || {
        echo "Expected --head feature/x in command: ${captured_cmd}"
        return 1
    }
}

@test "pr_list: fields passed as --json" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_pr_list '{"fields":"number,title,state"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--json number,title,state"* ]] || {
        echo "Expected --json number,title,state in command: ${captured_cmd}"
        return 1
    }
}

@test "pr_list: invalid limit is rejected" {
    run tool_pr_list '{"limit":"abc"}'
    assert_failure
    assert_output --partial "limit"
}

@test "pr_list: jq_filter applied to output" {
    GH_STUB_OUTPUT='[{"number":1},{"number":2}]'
    run tool_pr_list '{"jq_filter":".[0].number"}'
    assert_success
    assert_output "1"
}

# =============================================================================
# issue_view — tool-specific tests
# =============================================================================

@test "issue_view: fields passed as --json" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '{}'
    }
    run tool_issue_view '{"number":"42","fields":"title,body,state"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--json title,body,state"* ]] || {
        echo "Expected --json title,body,state in command: ${captured_cmd}"
        return 1
    }
}

@test "issue_view: with_comments adds --comments flag" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo 'issue body'
    }
    run tool_issue_view '{"number":"42","with_comments":true}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--comments"* ]] || {
        echo "Expected --comments in command: ${captured_cmd}"
        return 1
    }
}

@test "issue_view: jq_filter applied to output" {
    GH_STUB_OUTPUT='{"title":"my issue","state":"open"}'
    run tool_issue_view '{"number":"42","fields":"title,state","jq_filter":".title"}'
    assert_success
    assert_output '"my issue"'
}

# =============================================================================
# issue_list — tool-specific tests
# =============================================================================

@test "issue_list: search/state/label filters passed to gh" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_issue_list '{"search":"TODO","state":"open","label":"bug"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--search TODO"* ]] || {
        echo "Expected --search TODO in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" == *"--state open"* ]] || {
        echo "Expected --state open in command: ${captured_cmd}"
        return 1
    }
    [[ "${captured_cmd}" == *"--label bug"* ]] || {
        echo "Expected --label bug in command: ${captured_cmd}"
        return 1
    }
}

@test "issue_list: fields passed as --json" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_issue_list '{"fields":"number,title,state"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--json number,title,state"* ]] || {
        echo "Expected --json number,title,state in command: ${captured_cmd}"
        return 1
    }
}

@test "issue_list: invalid limit is rejected" {
    run tool_issue_list '{"limit":"xyz"}'
    assert_failure
    assert_output --partial "limit"
}

# =============================================================================
# run_view — tool-specific tests
# =============================================================================

@test "run_view: fields passed as --json" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '{}'
    }
    run tool_run_view '{"run_id":"12345","fields":"status,conclusion,jobs"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--json status,conclusion,jobs"* ]] || {
        echo "Expected --json status,conclusion,jobs in command: ${captured_cmd}"
        return 1
    }
}

@test "run_view: jq_filter applied to output" {
    GH_STUB_OUTPUT='{"status":"completed","conclusion":"success"}'
    run tool_run_view '{"run_id":"12345","jq_filter":".conclusion"}'
    assert_success
    assert_output '"success"'
}

# =============================================================================
# job_view — tool-specific tests
# =============================================================================

@test "job_view: builds correct API endpoint" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '{}'
    }
    run tool_job_view '{"job_id":"99"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"repos/shopware/shopware/actions/jobs/99"* ]] || {
        echo "Expected actions/jobs/99 endpoint in command: ${captured_cmd}"
        return 1
    }
}

# =============================================================================
# job_logs — tool-specific tests
# =============================================================================

@test "job_logs: builds correct API endpoint" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo 'log output'
    }
    run tool_job_logs '{"job_id":"99"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"repos/shopware/shopware/actions/jobs/99/logs"* ]] || {
        echo "Expected actions/jobs/99/logs endpoint in command: ${captured_cmd}"
        return 1
    }
}

@test "job_logs: grep_pattern filters output" {
    GH_STUB_OUTPUT=$'Step 1 passed\nERROR: test failed\nStep 3 passed'
    run tool_job_logs '{"job_id":"99","grep_pattern":"ERROR"}'
    assert_success
    assert_output "ERROR: test failed"
}

@test "job_logs: max_lines truncates output" {
    GH_STUB_OUTPUT=$'line1\nline2\nline3\nline4\nline5'
    run tool_job_logs '{"job_id":"99","max_lines":2}'
    assert_success
    assert_output $'line1\nline2'
}

@test "job_logs: tail_lines returns last N lines" {
    GH_STUB_OUTPUT=$'line1\nline2\nline3\nline4\nline5'
    run tool_job_logs '{"job_id":"99","tail_lines":2}'
    assert_success
    assert_output $'line4\nline5'
}

# =============================================================================
# job_annotations — tool-specific tests
# =============================================================================

@test "job_annotations: builds correct API endpoint" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_job_annotations '{"check_run_id":"99"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"repos/shopware/shopware/check-runs/99/annotations"* ]] || {
        echo "Expected check-runs/99/annotations endpoint in command: ${captured_cmd}"
        return 1
    }
}

# =============================================================================
# search — tool-specific tests
# =============================================================================

@test "search: invalid type is rejected" {
    run tool_search '{"query":"test","type":"invalid"}'
    assert_failure
    assert_output --partial "type must be"
}

@test "search: type=issues uses gh search issues" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_search '{"query":"bug","type":"issues"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"search issues bug"* ]] || {
        echo "Expected 'search issues bug' in command: ${captured_cmd}"
        return 1
    }
}

@test "search: repo filter passed to gh" {
    gh() {
        echo "$*" > "${BATS_TEST_TMPDIR}/captured_cmd"
        echo '[]'
    }
    run tool_search '{"query":"test","repo":"org/repo"}'
    assert_success
    local captured_cmd
    captured_cmd=$(cat "${BATS_TEST_TMPDIR}/captured_cmd")
    [[ "${captured_cmd}" == *"--repo org/repo"* ]] || {
        echo "Expected --repo org/repo in command: ${captured_cmd}"
        return 1
    }
}
