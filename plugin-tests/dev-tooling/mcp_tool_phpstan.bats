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
    assert_output --partial "-- src/"
}

@test "phpstan: level flag added when level provided" {
    run tool_phpstan_analyze '{"level":8}'
    assert_success
    assert_output --partial "--level=8"
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

@test "phpstan: config file adds --configuration flag" {
    run tool_phpstan_analyze '{"config":"phpstan.neon"}'
    assert_success
    assert_output --partial "--configuration=phpstan.neon"
}

@test "phpstan: memory limit adds --memory-limit flag" {
    run tool_phpstan_analyze '{"memory_limit":"2G"}'
    assert_success
    assert_output --partial "--memory-limit=2G"
}

@test "phpstan: config read from config file default" {
    echo '{"environment":"native","phpstan":{"config":"phpstan.neon.dist"}}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    run tool_phpstan_analyze '{}'
    assert_success
    assert_output --partial "--configuration=phpstan.neon.dist"
}

@test "phpstan: memory_limit read from config file default" {
    echo '{"environment":"native","phpstan":{"memory_limit":"512M"}}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    run tool_phpstan_analyze '{}'
    assert_success
    assert_output --partial "--memory-limit=512M"
}
