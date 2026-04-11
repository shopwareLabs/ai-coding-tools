#!/usr/bin/env bats
# bats file_tags=gh-tooling,write-tools,edit-params
# Parameterized tests for label_add/remove and assignee_add/remove.
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/gh-tooling"
GH_LIB_DIR="${PLUGIN_DIR}/mcp-server-gh/lib"

setup() {
    log() { :; }
    GH_DEFAULT_REPO="shopware/shopware"
    GH_TOOLING_CONFIG_FILE=""
    source "${GH_LIB_DIR}/common.sh"
    source "${GH_LIB_DIR}/label.sh"
    source "${GH_LIB_DIR}/assignee_write.sh"

    GH_ARGS_FILE="${BATS_TEST_TMPDIR}/gh_args"
    gh() {
        printf '%s\n' "$*" > "${GH_ARGS_FILE}"
        [[ -n "${GH_STUB_OUTPUT:-}" ]] && printf '%s\n' "${GH_STUB_OUTPUT}"
        return "${GH_STUB_EXIT:-0}"
    }
    GH_STUB_OUTPUT=""
    GH_STUB_EXIT=0
}

# Parameterized test helpers
_test_requires_number() {
    run "$1" '{"type": "pr", "'"$2"'": ["val"]}'
    assert_failure
    assert_output --partial "number is required"
}

_test_requires_type() {
    run "$1" '{"number": 1, "'"$2"'": ["val"]}'
    assert_failure
    assert_output --partial "type is required"
}

_test_requires_values() {
    run "$1" '{"number": 1, "type": "pr"}'
    assert_failure
    assert_output --partial "$2"
}

_test_routes_to_pr() {
    GH_STUB_OUTPUT=""
    run "$1" '{"number": 1, "type": "pr", "'"$2"'": ["val1"]}'
    assert_success
    grep -qF "pr edit 1" "${GH_ARGS_FILE}"
}

_test_routes_to_issue() {
    GH_STUB_OUTPUT=""
    run "$1" '{"number": 1, "type": "issue", "'"$2"'": ["val1"]}'
    assert_success
    grep -qF "issue edit 1" "${GH_ARGS_FILE}"
}

_test_rejects_invalid_type() {
    run "$1" '{"number": 1, "type": "commit", "'"$2"'": ["val1"]}'
    assert_failure
    assert_output --partial "type must be"
}

# --- label_add ---
bats_test_function --description "label_add requires number" -- _test_requires_number tool_label_add labels
bats_test_function --description "label_add requires type" -- _test_requires_type tool_label_add labels
bats_test_function --description "label_add requires labels array" -- _test_requires_values tool_label_add "labels"
bats_test_function --description "label_add routes to gh pr edit" -- _test_routes_to_pr tool_label_add labels
bats_test_function --description "label_add routes to gh issue edit" -- _test_routes_to_issue tool_label_add labels
bats_test_function --description "label_add rejects invalid type" -- _test_rejects_invalid_type tool_label_add labels

# --- label_remove ---
bats_test_function --description "label_remove requires number" -- _test_requires_number tool_label_remove labels
bats_test_function --description "label_remove routes to gh pr edit" -- _test_routes_to_pr tool_label_remove labels
bats_test_function --description "label_remove routes to gh issue edit" -- _test_routes_to_issue tool_label_remove labels

# --- assignee_add ---
bats_test_function --description "assignee_add requires number" -- _test_requires_number tool_assignee_add assignees
bats_test_function --description "assignee_add requires type" -- _test_requires_type tool_assignee_add assignees
bats_test_function --description "assignee_add requires assignees array" -- _test_requires_values tool_assignee_add "assignees"
bats_test_function --description "assignee_add routes to gh pr edit" -- _test_routes_to_pr tool_assignee_add assignees
bats_test_function --description "assignee_add routes to gh issue edit" -- _test_routes_to_issue tool_assignee_add assignees
bats_test_function --description "assignee_add rejects invalid type" -- _test_rejects_invalid_type tool_assignee_add assignees

# --- assignee_remove ---
bats_test_function --description "assignee_remove requires number" -- _test_requires_number tool_assignee_remove assignees
bats_test_function --description "assignee_remove routes to gh pr edit" -- _test_routes_to_pr tool_assignee_remove assignees
bats_test_function --description "assignee_remove routes to gh issue edit" -- _test_routes_to_issue tool_assignee_remove assignees
