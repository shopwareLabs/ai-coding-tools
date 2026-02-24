#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,php
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

setup() {
    setup_php_mcp_env "${PLUGIN_DIR}" "${PLUGIN_DIR}/mcp-server-php/lib/phpunit.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE
}

# --- Basic command construction ---

@test "phpunit: runs vendor/bin/phpunit by default" {
    run tool_phpunit_run '{}'
    assert_success
    assert_output --partial "vendor/bin/phpunit"
}

@test "phpunit: testsuite flag added when testsuite provided" {
    run tool_phpunit_run '{"testsuite":"unit"}'
    assert_success
    assert_output --partial "--testsuite=unit"
}

@test "phpunit: paths override testsuite" {
    run tool_phpunit_run '{"testsuite":"unit","paths":["tests/Unit/FooTest.php"]}'
    assert_success
    assert_output --partial "tests/Unit/FooTest.php"
    refute_output --partial "--testsuite"
}

@test "phpunit: filter flag added when filter provided" {
    run tool_phpunit_run '{"filter":"testMyMethod"}'
    assert_success
    assert_output --partial "--filter='testMyMethod'"
}

@test "phpunit: filter with pipe characters is properly quoted" {
    run tool_phpunit_run '{"filter":"testFoo|testBar|testBaz"}'
    assert_success
    assert_output --partial "--filter='testFoo|testBar|testBaz'"
}

@test "phpunit: stop_on_failure adds flag" {
    run tool_phpunit_run '{"stop_on_failure":true}'
    assert_success
    assert_output --partial "--stop-on-failure"
}

@test "phpunit: testdox output format adds flag" {
    run tool_phpunit_run '{"output_format":"testdox"}'
    assert_success
    assert_output --partial "--testdox"
}

@test "phpunit: config file adds --configuration flag" {
    run tool_phpunit_run '{"config":"phpunit.xml.dist"}'
    assert_success
    assert_output --partial "--configuration=phpunit.xml.dist"
}

# --- Coverage formats ---

@test "phpunit: coverage=true with default format adds --coverage-text" {
    run tool_phpunit_run '{"coverage":true}'
    assert_success
    assert_output --partial "--coverage-text"
}

phpunit_coverage_format() {
    local format="$1" expected_flag="$2"
    run tool_phpunit_run "{\"coverage\":true,\"coverage_format\":\"${format}\"}"
    assert_success
    assert_output --partial "${expected_flag}"
}

bats_test_function --description "phpunit: coverage html adds --coverage-html"           -- phpunit_coverage_format html      "--coverage-html=coverage/"
bats_test_function --description "phpunit: coverage clover adds --coverage-clover"       -- phpunit_coverage_format clover    "--coverage-clover=coverage.xml"
bats_test_function --description "phpunit: coverage cobertura adds --coverage-cobertura" -- phpunit_coverage_format cobertura "--coverage-cobertura=coverage.xml"

# --- Always-on console output for file-based formats ---

@test "phpunit: coverage html also emits --coverage-text" {
    run tool_phpunit_run '{"coverage":true,"coverage_format":"html"}'
    assert_success
    assert_output --partial "--coverage-text"
}

@test "phpunit: coverage clover also emits --coverage-text" {
    run tool_phpunit_run '{"coverage":true,"coverage_format":"clover"}'
    assert_success
    assert_output --partial "--coverage-text"
}

@test "phpunit: coverage cobertura also emits --coverage-text" {
    run tool_phpunit_run '{"coverage":true,"coverage_format":"cobertura"}'
    assert_success
    assert_output --partial "--coverage-text"
}

# --- coverage_path: custom output path ---

@test "phpunit: coverage_path overrides default html output directory" {
    run tool_phpunit_run '{"coverage":true,"coverage_format":"html","coverage_path":"build/coverage-html"}'
    assert_success
    assert_output --partial "--coverage-html=build/coverage-html"
    refute_output --partial "--coverage-html=coverage/"
}

@test "phpunit: coverage_path overrides default clover output file" {
    run tool_phpunit_run '{"coverage":true,"coverage_format":"clover","coverage_path":"build/clover.xml"}'
    assert_success
    assert_output --partial "--coverage-clover=build/clover.xml"
    refute_output --partial "--coverage-clover=coverage.xml"
}

@test "phpunit: coverage_path overrides default cobertura output file" {
    run tool_phpunit_run '{"coverage":true,"coverage_format":"cobertura","coverage_path":"build/cobertura.xml"}'
    assert_success
    assert_output --partial "--coverage-cobertura=build/cobertura.xml"
    refute_output --partial "--coverage-cobertura=coverage.xml"
}

@test "phpunit: coverage_path with custom path still emits --coverage-text" {
    run tool_phpunit_run '{"coverage":true,"coverage_format":"clover","coverage_path":"build/clover.xml"}'
    assert_success
    assert_output --partial "--coverage-text"
}

@test "phpunit: coverage_path omitted uses default coverage.xml for clover" {
    run tool_phpunit_run '{"coverage":true,"coverage_format":"clover"}'
    assert_success
    assert_output --partial "--coverage-clover=coverage.xml"
}

@test "phpunit: coverage_path omitted uses default coverage/ for html" {
    run tool_phpunit_run '{"coverage":true,"coverage_format":"html"}'
    assert_success
    assert_output --partial "--coverage-html=coverage/"
}

# --- Coverage driver: xdebug ---

@test "phpunit: coverage_driver=xdebug prepends XDEBUG_MODE=coverage" {
    run tool_phpunit_run '{"coverage":true,"coverage_driver":"xdebug"}'
    assert_success
    assert_output --partial "XDEBUG_MODE=coverage vendor/bin/phpunit"
}

@test "phpunit: coverage_driver=pcov does not prepend XDEBUG_MODE" {
    run tool_phpunit_run '{"coverage":true,"coverage_driver":"pcov"}'
    assert_success
    refute_output --partial "XDEBUG_MODE"
    assert_output --partial "vendor/bin/phpunit"
}

@test "phpunit: no coverage_driver does not prepend XDEBUG_MODE" {
    run tool_phpunit_run '{"coverage":true}'
    assert_success
    refute_output --partial "XDEBUG_MODE"
    assert_output --partial "vendor/bin/phpunit"
}

# --- Config file defaults ---

@test "phpunit: coverage_driver read from config file when not in tool args" {
    echo '{"environment":"native","phpunit":{"coverage_driver":"xdebug"}}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    run tool_phpunit_run '{"coverage":true}'
    assert_success
    assert_output --partial "XDEBUG_MODE=coverage"
}

@test "phpunit: tool arg coverage_driver overrides config file default" {
    echo '{"environment":"native","phpunit":{"coverage_driver":"pcov"}}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    run tool_phpunit_run '{"coverage":true,"coverage_driver":"xdebug"}'
    assert_success
    assert_output --partial "XDEBUG_MODE=coverage"
}

# --- Guard: coverage=false ---

@test "phpunit: coverage=false does not inject XDEBUG_MODE even when driver set" {
    run tool_phpunit_run '{"coverage":false,"coverage_driver":"xdebug"}'
    assert_success
    refute_output --partial "XDEBUG_MODE"
    refute_output --partial "--coverage"
}
