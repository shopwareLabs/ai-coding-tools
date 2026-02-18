#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,php

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/code-quality/dev-tooling"

setup() {
    setup_php_mcp_env "${PLUGIN_DIR}" "${PLUGIN_DIR}/mcp-server-php/lib/console.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE
}

# --- Basic command construction ---

@test "console: runs bin/console with command name" {
    run tool_console_run '{"command":"cache:clear"}'
    assert_success
    assert_output --partial "bin/console cache:clear"
}

@test "console: missing command returns error" {
    run tool_console_run '{}'
    assert_failure
    assert_output --partial "'command' parameter is required"
}

@test "console: invalid command chars are rejected" {
    run tool_console_run '{"command":"cache:clear; rm -rf /"}'
    assert_failure
    assert_output --partial "Invalid command name format"
}

@test "console: arguments are appended after command" {
    run tool_console_run '{"command":"plugin:install","arguments":["MyPlugin"]}'
    assert_success
    assert_output --partial "plugin:install MyPlugin"
}

# --- Environment and verbosity ---

@test "console: env option adds --env flag" {
    run tool_console_run '{"command":"cache:clear","env":"prod"}'
    assert_success
    assert_output --partial "--env=prod"
}

@test "console: verbosity quiet adds -q" {
    run tool_console_run '{"command":"cache:clear","verbosity":"quiet"}'
    assert_success
    assert_output --partial "-q"
}

@test "console: verbosity very-verbose adds -vv" {
    run tool_console_run '{"command":"cache:clear","verbosity":"very-verbose"}'
    assert_success
    assert_output --partial "-vv"
}

@test "console: no_debug=true adds --no-debug flag" {
    run tool_console_run '{"command":"cache:clear","no_debug":true}'
    assert_success
    assert_output --partial "--no-debug"
}

@test "console: no_interaction=true adds --no-interaction flag" {
    run tool_console_run '{"command":"cache:clear","no_interaction":true}'
    assert_success
    assert_output --partial "--no-interaction"
}

# --- Options object types ---

@test "console: boolean option true becomes --flag" {
    run tool_console_run '{"command":"cache:clear","options":{"force":true}}'
    assert_success
    assert_output --partial "--force"
}

@test "console: boolean option false is skipped" {
    run tool_console_run '{"command":"cache:clear","options":{"force":false}}'
    assert_success
    refute_output --partial "--force"
}

@test "console: string option becomes --key=value" {
    run tool_console_run '{"command":"cache:clear","options":{"output":"json"}}'
    assert_success
    assert_output --partial "--output=json"
}

# --- Console list ---

@test "console list: non-llm format passes --format to bin/console" {
    run tool_console_list '{"format":"json"}'
    assert_success
    assert_output --partial "bin/console list --format=json"
}
