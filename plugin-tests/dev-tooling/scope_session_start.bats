#!/usr/bin/env bats
# bats file_tags=dev-tooling,scope,hooks
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

SCRIPT="${REPO_ROOT}/plugins/dev-tooling/hooks/scripts/session-start.sh"

setup() {
    export CLAUDE_PROJECT_DIR="${BATS_TEST_TMPDIR}"
}

teardown() {
    unset CLAUDE_PROJECT_DIR
}

@test "session-start: no scopes -> section absent" {
    echo '{"environment":"native"}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    run bash -c "echo '{}' | ${SCRIPT}"
    assert_success
    refute_output --partial "-tooling scopes"
}

_write_two_scopes_config() {
    cat > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json" <<'JSON'
{
  "environment":"native",
  "default_scope":"plugin-x",
  "scopes":{"plugin-x":{"cwd":"custom/plugins/X"},"plugin-y":{"cwd":"custom/plugins/Y"}}
}
JSON
}

@test "session-start: with scopes -> section header rendered with declared names" {
    _write_two_scopes_config
    run bash -c "echo '{}' | ${SCRIPT}"
    assert_success
    assert_output --partial "php-tooling scopes"
    assert_output --partial "plugin-x"
    assert_output --partial "plugin-y"
}

@test "session-start: with scopes -> default_scope line present" {
    _write_two_scopes_config
    run bash -c "echo '{}' | ${SCRIPT}"
    assert_success
    assert_output --partial "Default scope: plugin-x"
}

@test "session-start: with scopes -> implicit shopware entry listed" {
    _write_two_scopes_config
    run bash -c "echo '{}' | ${SCRIPT}"
    assert_success
    assert_output --partial "shopware (implicit)"
}

@test "session-start: no default_scope -> implicit shopware shown" {
    cat > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X"}}}
JSON
    run bash -c "echo '{}' | ${SCRIPT}"
    assert_success
    assert_output --partial "Default scope: shopware"
}
