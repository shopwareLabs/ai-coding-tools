#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,php
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

setup() {
    setup_php_mcp_env "${PLUGIN_DIR}" "${PLUGIN_DIR}/mcp-server-php/lib/phpstan.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE
}

@test "phpstan: runs composer phpstan by default" {
    run tool_phpstan_analyze '{}'
    assert_success
    assert_output --partial "composer phpstan"
}

@test "phpstan: paths are appended after --" {
    run tool_phpstan_analyze '{"paths":["src/"]}'
    assert_success
    assert_output --partial '-- "src/"'
}

@test "phpstan: path with a shell metacharacter is quoted as one argument" {
    run tool_phpstan_analyze '{"paths":["src/My Bundle"]}'
    assert_success
    assert_output --partial '"src/My Bundle"'
}

@test "phpstan: paths sent as a bare string are refused" {
    run tool_phpstan_analyze '{"paths":"src/"}'
    assert_failure
    assert_output --partial '"paths" must be an array of strings'
}

@test "phpstan: level flag added when level provided" {
    run tool_phpstan_analyze '{"level":8}'
    assert_success
    assert_output --partial '--level="8"'
}

@test "phpstan: json error format added by default" {
    run tool_phpstan_analyze '{}'
    assert_success
    assert_output --partial "--error-format=json"
}

@test "phpstan: table error format when specified" {
    run tool_phpstan_analyze '{"error_format":"table"}'
    assert_success
    assert_output --partial "--error-format=table"
}

@test "phpstan: raw error format when specified" {
    run tool_phpstan_analyze '{"error_format":"raw"}'
    assert_success
    assert_output --partial "--error-format=raw"
}

@test "phpstan: config file adds --configuration flag" {
    run tool_phpstan_analyze '{"config":"phpstan.neon"}'
    assert_success
    assert_output --partial '--configuration="phpstan.neon"'
}

@test "phpstan: memory limit adds --memory-limit flag" {
    run tool_phpstan_analyze '{"memory_limit":"2G"}'
    assert_success
    assert_output --partial '--memory-limit="2G"'
}

@test "phpstan: config read from config file default" {
    echo '{"environment":"native","phpstan":{"config":"phpstan.neon.dist"}}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    run tool_phpstan_analyze '{}'
    assert_success
    assert_output --partial '--configuration="phpstan.neon.dist"'
}

@test "phpstan: memory_limit read from config file default" {
    echo '{"environment":"native","phpstan":{"memory_limit":"512M"}}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    run tool_phpstan_analyze '{}'
    assert_success
    assert_output --partial '--memory-limit="512M"'
}

# --- Malformed top-level arguments are refused, not silently defaulted ---

@test "phpstan: malformed top-level JSON is refused rather than defaulting silently" {
    run tool_phpstan_analyze '{not valid json'
    assert_failure
    assert_output --partial "Refusing to run: could not parse arguments as JSON"
}

# --- Values that cannot be quoted safely are refused ---

phpstan_refuses_single_quote() {
    local payload="$1"
    run tool_phpstan_analyze "${payload}"
    assert_failure
    assert_output --partial "Refusing to run"
    assert_output --partial "contains a single quote"
}

bats_test_function --description "phpstan: path containing a single quote is refused" \
    -- phpstan_refuses_single_quote "{\"paths\":[\"src/It's\"]}"
bats_test_function --description "phpstan: config containing a single quote is refused" \
    -- phpstan_refuses_single_quote "{\"config\":\"phps'tan.neon\"}"
bats_test_function --description "phpstan: memory_limit containing a single quote is refused" \
    -- phpstan_refuses_single_quote "{\"memory_limit\":\"2'G\"}"
bats_test_function --description "phpstan: level containing a single quote is refused" \
    -- phpstan_refuses_single_quote "{\"level\":\"8'\"}"

# --- Line breaks cannot be embedded in a single command ---

phpstan_refuses_linebreak() {
    local payload="$1"
    run tool_phpstan_analyze "${payload}"
    assert_failure
    assert_output --partial "Refusing to run: arguments contain a line break, which cannot be embedded in a single command."
}

bats_test_function --description "phpstan: path containing an interior line break is refused" \
    -- phpstan_refuses_linebreak "{\"paths\":[\"src/Foo\\nBar\"]}"
bats_test_function --description "phpstan: config containing a trailing line break is refused" \
    -- phpstan_refuses_linebreak "{\"config\":\"phpstan.neon\\n\"}"
