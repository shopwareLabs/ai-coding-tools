#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,php
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

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
    assert_output --partial 'bin/console "cache:clear"'
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
    assert_output --partial '"plugin:install" "MyPlugin"'
}

@test "console: argument with a pipe is quoted as one argument" {
    run tool_console_run '{"command":"plugin:install","arguments":["Foo|Bar"]}'
    assert_success
    assert_output --partial '"Foo|Bar"'
}

@test "console: argument with a space is quoted as one argument" {
    run tool_console_run '{"command":"plugin:install","arguments":["My Plugin"]}'
    assert_success
    assert_output --partial '"My Plugin"'
}

# --- Environment and verbosity ---

@test "console: env option adds --env flag" {
    run tool_console_run '{"command":"cache:clear","env":"prod"}'
    assert_success
    assert_output --partial '--env="prod"'
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
    assert_output --partial -- '--"force"'
}

@test "console: boolean option false is skipped" {
    run tool_console_run '{"command":"cache:clear","options":{"force":false}}'
    assert_success
    refute_output --partial "force"
}

@test "console: string option becomes --key=value" {
    run tool_console_run '{"command":"cache:clear","options":{"output":"json"}}'
    assert_success
    assert_output --partial -- '--"output"="json"'
}

@test "console: string option value with a pipe is quoted as one argument" {
    run tool_console_run '{"command":"cache:clear","options":{"output":"a|b"}}'
    assert_success
    assert_output --partial -- '--"output"="a|b"'
}

@test "console: array option value with a space is quoted as one argument" {
    run tool_console_run '{"command":"cache:clear","options":{"tag":["my tag"]}}'
    assert_success
    assert_output --partial -- '--"tag"="my tag"'
}

# --- Values that cannot be quoted safely are refused ---

console_refuses_single_quote() {
    local payload="$1"
    run tool_console_run "${payload}"
    assert_failure
    assert_output --partial "Refusing to run"
    assert_output --partial "contains a single quote"
}

bats_test_function --description "console: argument containing a single quote is refused" \
    -- console_refuses_single_quote "{\"command\":\"plugin:install\",\"arguments\":[\"My'Plugin\"]}"
bats_test_function --description "console: env containing a single quote is refused" \
    -- console_refuses_single_quote "{\"command\":\"cache:clear\",\"env\":\"pr'od\"}"
bats_test_function --description "console: option name containing a single quote is refused" \
    -- console_refuses_single_quote "{\"command\":\"cache:clear\",\"options\":{\"out'put\":\"json\"}}"
bats_test_function --description "console: string option value containing a single quote is refused" \
    -- console_refuses_single_quote "{\"command\":\"cache:clear\",\"options\":{\"output\":\"js'on\"}}"
bats_test_function --description "console: array option value containing a single quote is refused" \
    -- console_refuses_single_quote "{\"command\":\"cache:clear\",\"options\":{\"tag\":[\"my'tag\"]}}"

# --- Line breaks cannot be embedded in a single command ---

console_refuses_linebreak() {
    local payload="$1"
    run tool_console_run "${payload}"
    assert_failure
    assert_output --partial "Refusing to run: arguments contain a line break, which cannot be embedded in a single command."
}

bats_test_function --description "console: argument containing an interior line break is refused" \
    -- console_refuses_linebreak "{\"command\":\"plugin:install\",\"arguments\":[\"My\\nPlugin\"]}"
bats_test_function --description "console: array option value containing an interior line break is refused" \
    -- console_refuses_linebreak "{\"command\":\"cache:clear\",\"options\":{\"tag\":[\"my\\ntag\"]}}"
bats_test_function --description "console: env containing a trailing line break is refused" \
    -- console_refuses_linebreak "{\"command\":\"cache:clear\",\"env\":\"prod\\n\"}"
bats_test_function --description "console: option name containing a line break is refused" \
    -- console_refuses_linebreak "{\"command\":\"cache:clear\",\"options\":{\"bad\\nkey\":\"x\"}}"

# --- Console list ---

@test "console list: non-llm format passes --format to bin/console" {
    run tool_console_list '{"format":"json"}'
    assert_success
    assert_output --partial 'bin/console list --format="json"'
}

@test "console list: namespace is quoted as one argument" {
    run tool_console_list '{"namespace":"cache","format":"json"}'
    assert_success
    assert_output --partial 'bin/console list "cache" --format="json"'
}

@test "console list: format containing a trailing line break is refused" {
    run tool_console_list "{\"format\":\"json\\n\"}"
    assert_failure
    assert_output --partial "Refusing to run: arguments contain a line break, which cannot be embedded in a single command."
}
