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
    assert_output --partial '--output-format="json"'
    assert_output --partial "--no-progress-bar"
    refute_output --partial "--dry-run"
}

@test "rector_fix: console output format" {
    run tool_rector_fix '{"output_format":"console"}'
    assert_success
    assert_output --partial '--output-format="console"'
}

@test "rector_fix: paths appended after --" {
    run tool_rector_fix '{"paths":["src/Core/"]}'
    assert_success
    assert_output --partial '"src/Core/"'
}

@test "rector_fix: multiple paths" {
    run tool_rector_fix '{"paths":["src/Core/","src/Storefront/"]}'
    assert_success
    assert_output --partial '"src/Core/"'
    assert_output --partial '"src/Storefront/"'
}

@test "rector_fix: config flag" {
    run tool_rector_fix '{"config":"rector-custom.php"}'
    assert_success
    assert_output --partial '--config="rector-custom.php"'
}

@test "rector_fix: config read from config file default" {
    echo '{"environment":"native","rector":{"config":"rector.dist.php"}}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    run tool_rector_fix '{}'
    assert_success
    assert_output --partial '--config="rector.dist.php"'
}

@test "rector_fix: only flag filters to single rule" {
    run tool_rector_fix '{"only":"CountArrayToEmptyArrayComparisonRector"}'
    assert_success
    assert_output --partial '--only="CountArrayToEmptyArrayComparisonRector"'
}

@test "rector_fix: only_suffix flag" {
    run tool_rector_fix '{"only_suffix":"Controller"}'
    assert_success
    assert_output --partial '--only-suffix="Controller"'
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
    assert_output --partial '--output-format="json"'
    assert_output --partial "--no-progress-bar"
}

@test "rector_check: all flags combined" {
    run tool_rector_check '{"paths":["src/"],"config":"rector.php","only":"SomeRector","only_suffix":"Controller","clear_cache":true,"output_format":"console"}'
    assert_success
    assert_output --partial "--dry-run"
    assert_output --partial "--no-progress-bar"
    assert_output --partial '--output-format="console"'
    assert_output --partial '--config="rector.php"'
    assert_output --partial '--only="SomeRector"'
    assert_output --partial '--only-suffix="Controller"'
    assert_output --partial "--clear-cache"
    assert_output --partial '"src/"'
}

# --- Quoting of caller-supplied values ---

@test "rector_fix: path with a space is quoted as one argument" {
    run tool_rector_fix '{"paths":["src/My Bundle"]}'
    assert_success
    assert_output --partial '"src/My Bundle"'
}

@test "rector_fix: only rule with a pipe is quoted as one argument" {
    run tool_rector_fix '{"only":"FooRector|BarRector"}'
    assert_success
    assert_output --partial '--only="FooRector|BarRector"'
}

# --- Malformed and unquotable input is refused ---

rector_refuses_bare_string_paths() {
    local tool="$1"
    run "${tool}" '{"paths":"src/"}'
    assert_failure
    assert_output --partial '"paths" must be an array of strings'
}

bats_test_function --description "rector_fix: paths sent as a bare string are refused" \
    -- rector_refuses_bare_string_paths tool_rector_fix
bats_test_function --description "rector_check: paths sent as a bare string are refused" \
    -- rector_refuses_bare_string_paths tool_rector_check

rector_refuses_single_quote() {
    local tool="$1" payload="$2"
    run "${tool}" "${payload}"
    assert_failure
    assert_output --partial "Refusing to run"
    assert_output --partial "contains a single quote"
}

bats_test_function --description "rector_fix: path containing a single quote is refused" \
    -- rector_refuses_single_quote tool_rector_fix "{\"paths\":[\"src/It's\"]}"
bats_test_function --description "rector_check: path containing a single quote is refused" \
    -- rector_refuses_single_quote tool_rector_check "{\"paths\":[\"src/It's\"]}"
bats_test_function --description "rector_fix: config containing a single quote is refused" \
    -- rector_refuses_single_quote tool_rector_fix "{\"config\":\"rec'tor.php\"}"
bats_test_function --description "rector_fix: only rule containing a single quote is refused" \
    -- rector_refuses_single_quote tool_rector_fix "{\"only\":\"Some'Rector\"}"
bats_test_function --description "rector_fix: only_suffix containing a single quote is refused" \
    -- rector_refuses_single_quote tool_rector_fix "{\"only_suffix\":\"Contro'ller\"}"

# --- Line breaks cannot be embedded in a single command ---

rector_refuses_linebreak() {
    local tool="$1" payload="$2"
    run "${tool}" "${payload}"
    assert_failure
    assert_output --partial "Refusing to run: arguments contain a line break, which cannot be embedded in a single command."
}

bats_test_function --description "rector_fix: path containing an interior line break is refused" \
    -- rector_refuses_linebreak tool_rector_fix "{\"paths\":[\"src/Foo\\nBar\"]}"
bats_test_function --description "rector_check: path containing an interior line break is refused" \
    -- rector_refuses_linebreak tool_rector_check "{\"paths\":[\"src/Foo\\nBar\"]}"
bats_test_function --description "rector_fix: config containing a trailing line break is refused" \
    -- rector_refuses_linebreak tool_rector_fix "{\"config\":\"rector.php\\n\"}"

# --- Malformed top-level arguments are refused, not silently defaulted ---

rector_refuses_malformed_json() {
    local tool="$1"
    run "${tool}" '{not valid json'
    assert_failure
    assert_output --partial "Refusing to run: could not parse arguments as JSON"
}

bats_test_function --description "rector_fix: malformed top-level JSON is refused rather than defaulting silently" \
    -- rector_refuses_malformed_json tool_rector_fix
bats_test_function --description "rector_check: malformed top-level JSON is refused rather than defaulting silently" \
    -- rector_refuses_malformed_json tool_rector_check
