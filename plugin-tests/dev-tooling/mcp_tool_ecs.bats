#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,php
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

setup() {
    setup_php_mcp_env "${PLUGIN_DIR}" "${PLUGIN_DIR}/mcp-server-php/lib/ecs.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE
}

@test "ecs: check uses composer ecs" {
    run tool_ecs_check '{}'
    assert_success
    assert_output --partial "composer ecs"
}

@test "ecs: fix uses composer ecs-fix" {
    run tool_ecs_fix '{}'
    assert_success
    assert_output --partial "composer ecs-fix"
}

@test "ecs: check with json format adds --format=json" {
    run tool_ecs_check '{"output_format":"json"}'
    assert_success
    assert_output --partial "--format=json"
}

@test "ecs: check with text format (default) does not add --format flag" {
    run tool_ecs_check '{}'
    assert_success
    refute_output --partial "--format"
}

@test "ecs: check with paths appended after --" {
    run tool_ecs_check '{"paths":["src/"]}'
    assert_success
    assert_output --partial '-- "src/"'
}

@test "ecs: fix with paths appended after --" {
    run tool_ecs_fix '{"paths":["src/"]}'
    assert_success
    assert_output --partial '-- "src/"'
}

@test "ecs: check config file adds --config flag" {
    run tool_ecs_check '{"config":"ecs.php"}'
    assert_success
    assert_output --partial '--config="ecs.php"'
}

@test "ecs: check config read from config file default" {
    echo '{"environment":"native","ecs":{"config":"ecs.dist.php"}}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    run tool_ecs_check '{}'
    assert_success
    assert_output --partial '--config="ecs.dist.php"'
}

# --- Quoting of caller-supplied values ---

@test "ecs: check path with a space is quoted as one argument" {
    run tool_ecs_check '{"paths":["src/My Bundle"]}'
    assert_success
    assert_output --partial '"src/My Bundle"'
}

@test "ecs: fix path with a space is quoted as one argument" {
    run tool_ecs_fix '{"paths":["src/My Bundle"]}'
    assert_success
    assert_output --partial '"src/My Bundle"'
}

@test "ecs: check path with a pipe is quoted as one argument" {
    run tool_ecs_check '{"paths":["src/A|B"]}'
    assert_success
    assert_output --partial '"src/A|B"'
}

# --- Malformed and unquotable input is refused ---

ecs_refuses_bare_string_paths() {
    local tool="$1"
    run "${tool}" '{"paths":"src/"}'
    assert_failure
    assert_output --partial '"paths" must be an array of strings'
}

bats_test_function --description "ecs: check with paths sent as a bare string is refused" \
    -- ecs_refuses_bare_string_paths tool_ecs_check
bats_test_function --description "ecs: fix with paths sent as a bare string is refused" \
    -- ecs_refuses_bare_string_paths tool_ecs_fix

ecs_refuses_single_quote() {
    local tool="$1" payload="$2"
    run "${tool}" "${payload}"
    assert_failure
    assert_output --partial "Refusing to run"
    assert_output --partial "contains a single quote"
}

bats_test_function --description "ecs: check path containing a single quote is refused" \
    -- ecs_refuses_single_quote tool_ecs_check "{\"paths\":[\"src/It's\"]}"
bats_test_function --description "ecs: fix path containing a single quote is refused" \
    -- ecs_refuses_single_quote tool_ecs_fix "{\"paths\":[\"src/It's\"]}"
bats_test_function --description "ecs: check config containing a single quote is refused" \
    -- ecs_refuses_single_quote tool_ecs_check "{\"config\":\"e'cs.php\"}"
bats_test_function --description "ecs: fix config containing a single quote is refused" \
    -- ecs_refuses_single_quote tool_ecs_fix "{\"config\":\"e'cs.php\"}"

# --- Line breaks cannot be embedded in a single command ---

ecs_refuses_linebreak() {
    local tool="$1" payload="$2"
    run "${tool}" "${payload}"
    assert_failure
    assert_output --partial "Refusing to run: arguments contain a line break, which cannot be embedded in a single command."
}

bats_test_function --description "ecs: check path containing an interior line break is refused" \
    -- ecs_refuses_linebreak tool_ecs_check "{\"paths\":[\"src/Foo\\nBar\"]}"
bats_test_function --description "ecs: fix path containing an interior line break is refused" \
    -- ecs_refuses_linebreak tool_ecs_fix "{\"paths\":[\"src/Foo\\nBar\"]}"
bats_test_function --description "ecs: check config containing a trailing line break is refused" \
    -- ecs_refuses_linebreak tool_ecs_check "{\"config\":\"ecs.php\\n\"}"
bats_test_function --description "ecs: fix config containing a trailing line break is refused" \
    -- ecs_refuses_linebreak tool_ecs_fix "{\"config\":\"ecs.php\\n\"}"
