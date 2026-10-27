#!/usr/bin/env bats
# bats file_tags=dev-tooling,scope,hooks
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

SCRIPT="${REPO_ROOT}/plugins/dev-tooling/hooks/scripts/session-start.sh"

setup() {
    unset MCP_PHP_TOOLING_CONFIG MCP_JS_TOOLING_CONFIG
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

# The flag controls the directives that steer to the tools, not the scope
# metadata those tools accept, so an opted-out server keeps its scopes section.
@test "session-start: php enforcement disabled -> php scopes still present" {
    cat > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json" <<'JSON'
{"enforce_mcp_tools":false,"scopes":{"plugin-x":{"cwd":"custom/plugins/X"}}}
JSON
    cat > "${BATS_TEST_TMPDIR}/.mcp-js-tooling.json" <<'JSON'
{"scopes":{"plugin-j":{"cwd":"custom/plugins/J"}}}
JSON
    run bash -c "echo '{}' | ${SCRIPT}"
    assert_success
    assert_output --partial "## php-tooling scopes"
    assert_output --partial "plugin-x"
    refute_output --partial "phpstan_analyze"
    assert_output --partial "## js-tooling scopes"
    assert_output --partial "plugin-j"
}

@test "session-start: no default_scope -> implicit shopware shown" {
    cat > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X"}}}
JSON
    run bash -c "echo '{}' | ${SCRIPT}"
    assert_success
    assert_output --partial "Default scope: shopware"
}

# The servers merge every config file they find, so scopes declared in the root
# file stay in force when a `.claude/` file sets other keys.
@test "session-start: root scopes plus a .claude config without scopes -> section rendered" {
    _write_two_scopes_config
    mkdir -p "${BATS_TEST_TMPDIR}/.claude"
    echo '{"environment":"native"}' > "${BATS_TEST_TMPDIR}/.claude/.mcp-php-tooling.json"
    run bash -c "echo '{}' | ${SCRIPT}"
    assert_success
    assert_output --partial "Declared scopes: shopware (implicit), plugin-x, plugin-y"
}
