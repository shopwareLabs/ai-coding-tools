#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,php
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

setup() {
    setup_php_mcp_env "${PLUGIN_DIR}" "${PLUGIN_DIR}/mcp-server-php/lib/rector.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE
}

# --- rector_fix (preferred tool) ---

@test "rector_fix: defaults — composer rector, json, no-progress-bar, no dry-run" {
    run tool_rector_fix '{}'
    assert_success
    assert_output --partial "composer rector"
    assert_output --partial "--output-format=json"
    assert_output --partial "--no-progress-bar"
    refute_output --partial "--dry-run"
}

@test "rector_fix: console output format" {
    run tool_rector_fix '{"output_format":"console"}'
    assert_success
    assert_output --partial "--output-format=console"
}

@test "rector_fix: paths appended after --" {
    run tool_rector_fix '{"paths":["src/Core/"]}'
    assert_success
    assert_output --partial "'src/Core/'"
}

@test "rector_fix: multiple paths" {
    run tool_rector_fix '{"paths":["src/Core/","src/Storefront/"]}'
    assert_success
    assert_output --partial "'src/Core/'"
    assert_output --partial "'src/Storefront/'"
}

@test "rector_fix: config flag" {
    run tool_rector_fix '{"config":"rector-custom.php"}'
    assert_success
    assert_output --partial "--config=rector-custom.php"
}

@test "rector_fix: config read from config file default" {
    echo '{"environment":"native","rector":{"config":"rector.dist.php"}}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    run tool_rector_fix '{}'
    assert_success
    assert_output --partial "--config=rector.dist.php"
}

@test "rector_fix: only flag filters to single rule" {
    run tool_rector_fix '{"only":"CountArrayToEmptyArrayComparisonRector"}'
    assert_success
    assert_output --partial "--only=CountArrayToEmptyArrayComparisonRector"
}

@test "rector_fix: only_suffix flag" {
    run tool_rector_fix '{"only_suffix":"Controller"}'
    assert_success
    assert_output --partial "--only-suffix=Controller"
}

@test "rector_fix: clear_cache flag" {
    run tool_rector_fix '{"clear_cache":true}'
    assert_success
    assert_output --partial "--clear-cache"
}

@test "rector_fix: clear_cache false does not add flag" {
    run tool_rector_fix '{"clear_cache":false}'
    assert_success
    refute_output --partial "--clear-cache"
}

# --- rector_check (dry-run) ---

@test "rector_check: defaults — composer rector, dry-run, json, no-progress-bar" {
    run tool_rector_check '{}'
    assert_success
    assert_output --partial "composer rector"
    assert_output --partial "--dry-run"
    assert_output --partial "--output-format=json"
    assert_output --partial "--no-progress-bar"
}

@test "rector_check: all flags combined" {
    run tool_rector_check '{"paths":["src/"],"config":"rector.php","only":"SomeRector","only_suffix":"Controller","clear_cache":true,"output_format":"console"}'
    assert_success
    assert_output --partial "--dry-run"
    assert_output --partial "--no-progress-bar"
    assert_output --partial "--output-format=console"
    assert_output --partial "--config=rector.php"
    assert_output --partial "--only=SomeRector"
    assert_output --partial "--only-suffix=Controller"
    assert_output --partial "--clear-cache"
    assert_output --partial "'src/'"
}
