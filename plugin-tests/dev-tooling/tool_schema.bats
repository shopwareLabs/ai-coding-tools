#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,schema
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

teardown() {
    unset MCP_TOOLS_LIST_FILE
}

# Put one argument set through the vendored MCP validator against a server's
# real tools.json, the way the server does before it dispatches a tool.
# Args: $1 = tools.json path, $2 = tool name, $3 = arguments JSON
_validate_tool_call() {
    MCP_TOOLS_LIST_FILE="$1"
    # shellcheck source=/dev/null  # sourced for validate_tool_arguments only
    source "${PLUGIN_DIR}/shared/mcpserver_core.sh"
    validate_tool_arguments "$2" "$3"
}

@test "php-tooling schema: an unknown parameter on phpstan_analyze is refused" {
    run _validate_tool_call "${PLUGIN_DIR}/mcp-server-php/tools.json" "phpstan_analyze" '{"levell":8}'
    assert_failure
    assert_output --partial "Unknown parameter(s): levell"
}

@test "js-admin-tooling schema: an unknown parameter on eslint_check is refused" {
    run _validate_tool_call "${PLUGIN_DIR}/mcp-server-js-admin/tools.json" "eslint_check" '{"output_formatt":"json"}'
    assert_failure
    assert_output --partial "Unknown parameter(s): output_formatt"
}

@test "js-storefront-tooling schema: an unknown parameter on jest_run is refused" {
    run _validate_tool_call "${PLUGIN_DIR}/mcp-server-js-storefront/tools.json" "jest_run" '{"testNamePatternn":"foo"}'
    assert_failure
    assert_output --partial "Unknown parameter(s): testNamePatternn"
}
