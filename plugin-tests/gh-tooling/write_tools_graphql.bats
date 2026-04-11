#!/usr/bin/env bats
# bats file_tags=gh-tooling,write-tools,graphql
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/gh-tooling"
GH_LIB_DIR="${PLUGIN_DIR}/mcp-server-gh/lib"

setup() {
    log() { :; }
    GH_DEFAULT_REPO="shopware/shopware"
    GH_TOOLING_CONFIG_FILE=""
    source "${GH_LIB_DIR}/common.sh"
    source "${GH_LIB_DIR}/sub_issue_write.sh"

    # Mock node ID resolution to return predictable IDs
    _gh_resolve_issue_node_id() {
        local repo="$1" number="$2"
        printf '%s\n' "I_mock_node_${number}"
    }

    GH_ARGS_FILE="${BATS_TEST_TMPDIR}/gh_args"
    gh() {
        printf '%s\n' "$*" > "${GH_ARGS_FILE}"
        [[ -n "${GH_STUB_OUTPUT:-}" ]] && printf '%s\n' "${GH_STUB_OUTPUT}"
        return "${GH_STUB_EXIT:-0}"
    }
    GH_STUB_OUTPUT='{"data":{"addSubIssue":{"issue":{"number":1,"title":"Parent"},"subIssue":{"number":2,"title":"Child"}}}}'
    GH_STUB_EXIT=0
}

# ============================================================================
# sub_issue_add
# ============================================================================

@test "sub_issue_add requires issue_number" {
    run tool_sub_issue_add '{"sub_issue_number": 2}'
    assert_failure
    assert_output --partial "issue_number is required"
}

@test "sub_issue_add requires sub_issue_number" {
    run tool_sub_issue_add '{"issue_number": 1}'
    assert_failure
    assert_output --partial "sub_issue_number is required"
}

@test "sub_issue_add calls GraphQL mutation with correct IDs" {
    run tool_sub_issue_add '{"issue_number": 1, "sub_issue_number": 2}'
    assert_success
    [[ -f "${GH_ARGS_FILE}" ]]
    grep -qF "GraphQL-Features: sub_issues" "${GH_ARGS_FILE}"
    grep -qF "addSubIssue" "${GH_ARGS_FILE}"
    grep -qF "I_mock_node_1" "${GH_ARGS_FILE}"
    grep -qF "I_mock_node_2" "${GH_ARGS_FILE}"
}

@test "sub_issue_add requires repo" {
    GH_DEFAULT_REPO=""
    run tool_sub_issue_add '{"issue_number": 1, "sub_issue_number": 2}'
    assert_failure
    assert_output --partial "repo is required"
}

@test "sub_issue_add handles resolution failure" {
    _gh_resolve_issue_node_id() {
        printf '%s\n' "not found" >&2
        return 1
    }
    run tool_sub_issue_add '{"issue_number": 999, "sub_issue_number": 2}'
    assert_failure
    assert_output --partial "could not resolve"
}

@test "sub_issue_add returns fallback on resolution failure" {
    _gh_resolve_issue_node_id() {
        printf '%s\n' "not found" >&2
        return 1
    }
    run tool_sub_issue_add '{"issue_number": 999, "sub_issue_number": 2, "fallback": "fallback text"}'
    assert_success
    assert_output "fallback text"
}

@test "sub_issue_add returns fallback on mutation failure" {
    GH_STUB_EXIT=1
    run tool_sub_issue_add '{"issue_number": 1, "sub_issue_number": 2, "fallback": "failed"}'
    assert_success
    assert_output "failed"
}

@test "sub_issue_add rejects non-integer issue_number" {
    run tool_sub_issue_add '{"issue_number": "abc", "sub_issue_number": 2}'
    assert_failure
    assert_output --partial "must be a positive integer"
}

# ============================================================================
# sub_issue_remove
# ============================================================================

@test "sub_issue_remove requires issue_number" {
    run tool_sub_issue_remove '{"sub_issue_number": 2}'
    assert_failure
    assert_output --partial "issue_number is required"
}

@test "sub_issue_remove requires sub_issue_number" {
    run tool_sub_issue_remove '{"issue_number": 1}'
    assert_failure
    assert_output --partial "sub_issue_number is required"
}

@test "sub_issue_remove calls GraphQL mutation with removeSubIssue" {
    GH_STUB_OUTPUT='{"data":{"removeSubIssue":{"issue":{"number":1},"subIssue":{"number":2}}}}'
    run tool_sub_issue_remove '{"issue_number": 1, "sub_issue_number": 2}'
    assert_success
    grep -qF "removeSubIssue" "${GH_ARGS_FILE}"
    grep -qF "GraphQL-Features: sub_issues" "${GH_ARGS_FILE}"
}

@test "sub_issue_remove passes correct node IDs" {
    GH_STUB_OUTPUT='{"data":{"removeSubIssue":{"issue":{"number":5},"subIssue":{"number":10}}}}'
    run tool_sub_issue_remove '{"issue_number": 5, "sub_issue_number": 10}'
    assert_success
    grep -qF "I_mock_node_5" "${GH_ARGS_FILE}"
    grep -qF "I_mock_node_10" "${GH_ARGS_FILE}"
}

@test "sub_issue_remove requires repo" {
    GH_DEFAULT_REPO=""
    run tool_sub_issue_remove '{"issue_number": 1, "sub_issue_number": 2}'
    assert_failure
    assert_output --partial "repo is required"
}

@test "sub_issue_remove handles resolution failure" {
    _gh_resolve_issue_node_id() {
        printf '%s\n' "not found" >&2
        return 1
    }
    run tool_sub_issue_remove '{"issue_number": 999, "sub_issue_number": 2}'
    assert_failure
    assert_output --partial "could not resolve"
}

@test "sub_issue_remove returns fallback on mutation failure" {
    GH_STUB_EXIT=1
    run tool_sub_issue_remove '{"issue_number": 1, "sub_issue_number": 2, "fallback": "failed"}'
    assert_success
    assert_output "failed"
}
