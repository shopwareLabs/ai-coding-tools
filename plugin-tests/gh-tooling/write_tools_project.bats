#!/usr/bin/env bats
# bats file_tags=gh-tooling,write-tools,project
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/gh-tooling"
GH_LIB_DIR="${PLUGIN_DIR}/mcp-server-gh/lib"

setup() {
    log() { :; }
    GH_DEFAULT_REPO="shopware/shopware"
    GH_TOOLING_CONFIG_FILE=""
    source "${GH_LIB_DIR}/common.sh"
    source "${GH_LIB_DIR}/project.sh"

    # Mock resolution helpers
    _gh_resolve_project_number() { printf '%s\n' "42"; }
    _gh_resolve_status_option() { printf 'FIELD_123\tOPTION_456'; }

    GH_ARGS_FILE="${BATS_TEST_TMPDIR}/gh_args"
    gh() {
        printf '%s\n' "$*" > "${GH_ARGS_FILE}"
        [[ -n "${GH_STUB_OUTPUT:-}" ]] && printf '%s\n' "${GH_STUB_OUTPUT}"
        return "${GH_STUB_EXIT:-0}"
    }
    GH_STUB_OUTPUT=""
    GH_STUB_EXIT=0
}

# ============================================================================
# project_item_add
# ============================================================================

@test "project_item_add requires number" {
    run tool_project_item_add '{"type": "issue", "project": "Board"}'
    assert_failure
    assert_output --partial "number is required"
}

@test "project_item_add requires type" {
    run tool_project_item_add '{"number": 1, "project": "Board"}'
    assert_failure
    assert_output --partial "type is required"
}

@test "project_item_add requires project name" {
    run tool_project_item_add '{"number": 1, "type": "issue"}'
    assert_failure
    assert_output --partial "project name is required"
}

@test "project_item_add rejects invalid type" {
    run tool_project_item_add '{"number": 1, "type": "commit", "project": "Board"}'
    assert_failure
    assert_output --partial "type must be"
}

@test "project_item_add adds issue to project" {
    GH_STUB_OUTPUT="Added item"
    run tool_project_item_add '{"number": 1, "type": "issue", "project": "Sprint Board"}'
    assert_success
    grep -qF "project item-add 42" "${GH_ARGS_FILE}"
    grep -qF "issues/1" "${GH_ARGS_FILE}"
}

@test "project_item_add adds PR to project" {
    GH_STUB_OUTPUT="Added item"
    run tool_project_item_add '{"number": 100, "type": "pr", "project": "Sprint Board"}'
    assert_success
    grep -qF "pull/100" "${GH_ARGS_FILE}"
}

@test "project_item_add shows error with available projects when not found" {
    _gh_resolve_project_number() {
        printf '%s\n' "Error: project 'Nonexistent' not found. Available projects: Board A, Board B"
        return 1
    }
    run tool_project_item_add '{"number": 1, "type": "issue", "project": "Nonexistent"}'
    assert_failure
    assert_output --partial "Available projects"
}

# ============================================================================
# project_status_set
# ============================================================================

@test "project_status_set requires number" {
    run tool_project_status_set '{"type": "issue", "project": "Board", "status": "Done"}'
    assert_failure
    assert_output --partial "number is required"
}

@test "project_status_set requires status" {
    run tool_project_status_set '{"number": 1, "type": "issue", "project": "Board"}'
    assert_failure
    assert_output --partial "status is required"
}

@test "project_status_set requires project" {
    run tool_project_status_set '{"number": 1, "type": "issue", "status": "Done"}'
    assert_failure
    assert_output --partial "project name is required"
}

@test "project_status_set calls item-edit with resolved IDs" {
    # Mock item-list to return an item matching the URL
    gh() {
        if [[ "$*" == *"item-list"* ]]; then
            printf '%s\n' '{"items":[{"id":"PVTI_abc","content":{"url":"https://github.com/shopware/shopware/issues/1"}}]}'
            return 0
        fi
        printf '%s\n' "$*" > "${GH_ARGS_FILE}"
        return 0
    }
    run tool_project_status_set '{"number": 1, "type": "issue", "project": "Sprint Board", "status": "In Progress"}'
    assert_success
    grep -qF "item-edit" "${GH_ARGS_FILE}"
    grep -qF "FIELD_123" "${GH_ARGS_FILE}"
    grep -qF "OPTION_456" "${GH_ARGS_FILE}"
    grep -qF "PVTI_abc" "${GH_ARGS_FILE}"
}

@test "project_status_set shows error with available options when status not found" {
    _gh_resolve_status_option() {
        printf '%s\n' "Error: status 'Nope' not found. Available options: Todo, Done"
        return 1
    }
    run tool_project_status_set '{"number": 1, "type": "issue", "project": "Board", "status": "Nope"}'
    assert_failure
    assert_output --partial "Available options"
}

@test "project_status_set fails when item not in project" {
    gh() {
        if [[ "$*" == *"item-list"* ]]; then
            printf '%s\n' '{"items":[]}'
            return 0
        fi
        return 0
    }
    run tool_project_status_set '{"number": 999, "type": "issue", "project": "Board", "status": "Done"}'
    assert_failure
    assert_output --partial "not found in project"
}
