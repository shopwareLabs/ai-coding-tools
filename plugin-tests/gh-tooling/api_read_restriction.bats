#!/usr/bin/env bats
# bats file_tags=gh-tooling,api-restriction
# Tests that tool_api_read rejects non-GET methods
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/gh-tooling"
GH_LIB_DIR="${PLUGIN_DIR}/mcp-server-gh/lib"

setup() {
    log() { :; }
    GH_DEFAULT_REPO="shopware/shopware"
    GH_TOOLING_CONFIG_FILE=""
    source "${GH_LIB_DIR}/common.sh"
    source "${GH_LIB_DIR}/api.sh"

    gh() {
        [[ -n "${GH_STUB_STDERR:-}" ]] && echo "${GH_STUB_STDERR}" >&2
        [[ -n "${GH_STUB_OUTPUT:-}" ]] && printf '%s\n' "${GH_STUB_OUTPUT}"
        return "${GH_STUB_EXIT:-0}"
    }
    GH_STUB_OUTPUT=""
    GH_STUB_STDERR=""
    GH_STUB_EXIT=0
}

@test "tool_api_read allows GET method" {
    GH_STUB_OUTPUT='{"id": 1}'
    run tool_api_read '{"endpoint": "repos/shopware/shopware/pulls/123", "method": "GET"}'
    assert_success
}

@test "tool_api_read defaults to GET when method omitted" {
    GH_STUB_OUTPUT='{"id": 1}'
    run tool_api_read '{"endpoint": "repos/shopware/shopware/pulls/123"}'
    assert_success
}

@test "tool_api_read rejects POST method" {
    run tool_api_read '{"endpoint": "repos/shopware/shopware/pulls", "method": "POST"}'
    assert_failure
    assert_output --partial "read-only"
    assert_output --partial "GET"
}

@test "tool_api_read rejects PATCH method" {
    run tool_api_read '{"endpoint": "repos/shopware/shopware/pulls/123", "method": "PATCH"}'
    assert_failure
    assert_output --partial "read-only"
}

@test "tool_api_read rejects PUT method" {
    run tool_api_read '{"endpoint": "repos/shopware/shopware/pulls/123/merge", "method": "PUT"}'
    assert_failure
    assert_output --partial "read-only"
}

@test "tool_api_read rejects DELETE method" {
    run tool_api_read '{"endpoint": "repos/shopware/shopware/pulls/123", "method": "DELETE"}'
    assert_failure
    assert_output --partial "read-only"
}

@test "tool_api (write) allows POST method" {
    GH_STUB_OUTPUT='{"id": 1}'
    run tool_api '{"endpoint": "repos/shopware/shopware/pulls", "method": "POST"}'
    assert_success
}
