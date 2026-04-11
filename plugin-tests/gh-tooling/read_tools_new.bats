#!/usr/bin/env bats
# bats file_tags=gh-tooling,read-tools
# Tests for new read tools: label_list, project_list, project_view
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
    source "${GH_LIB_DIR}/project.sh"

    GH_ARGS_FILE="${BATS_TEST_TMPDIR}/gh_args"

    gh() {
        printf '%s\n' "$@" > "${GH_ARGS_FILE}"
        [[ -n "${GH_STUB_STDERR:-}" ]] && echo "${GH_STUB_STDERR}" >&2
        [[ -n "${GH_STUB_OUTPUT:-}" ]] && printf '%s\n' "${GH_STUB_OUTPUT}"
        return "${GH_STUB_EXIT:-0}"
    }
    GH_STUB_OUTPUT=""
    GH_STUB_STDERR=""
    GH_STUB_EXIT=0
}

# ============================================================================
# label_list
# ============================================================================

@test "label_list returns labels in JSON format" {
    GH_STUB_OUTPUT='[{"name":"bug","description":"Bug report","color":"d73a4a"}]'
    run tool_label_list '{"repo": "shopware/shopware"}'
    assert_success
    assert_output --partial "bug"
}

@test "label_list uses default repo when repo omitted" {
    GH_STUB_OUTPUT='[{"name":"bug"}]'
    run tool_label_list '{}'
    assert_success
}

@test "label_list passes filter to --search" {
    GH_STUB_OUTPUT='[{"name":"bug"}]'
    run tool_label_list '{"filter": "bug"}'
    assert_success
    run grep -x -- '--search' "${GH_ARGS_FILE}"
    assert_success
    run grep -x -- 'bug' "${GH_ARGS_FILE}"
    assert_success
}

# ============================================================================
# project_list
# ============================================================================

@test "project_list returns projects" {
    GH_STUB_OUTPUT='{"projects":[{"number":1,"title":"Sprint Board"}]}'
    run tool_project_list '{"owner": "shopware"}'
    assert_success
    assert_output --partial "Sprint Board"
}

@test "project_list derives owner from default repo" {
    GH_STUB_OUTPUT='{"projects":[]}'
    run tool_project_list '{}'
    assert_success
}

# ============================================================================
# project_view
# ============================================================================

@test "project_view requires number" {
    run tool_project_view '{}'
    assert_failure
    assert_output --partial "number is required"
}

@test "project_view returns project details" {
    GH_STUB_OUTPUT='{"number":1,"title":"Sprint Board","fields":{"nodes":[]}}'
    run tool_project_view '{"number": 1, "owner": "shopware"}'
    assert_success
    assert_output --partial "Sprint Board"
}
