#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,php

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
    assert_output --partial "-- src/"
}

@test "ecs: fix with paths appended after --" {
    run tool_ecs_fix '{"paths":["src/"]}'
    assert_success
    assert_output --partial "-- src/"
}

@test "ecs: check config file adds --config flag" {
    run tool_ecs_check '{"config":"ecs.php"}'
    assert_success
    assert_output --partial "--config=ecs.php"
}

@test "ecs: check config read from config file default" {
    echo '{"environment":"native","ecs":{"config":"ecs.dist.php"}}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    run tool_ecs_check '{}'
    assert_success
    assert_output --partial "--config=ecs.dist.php"
}
