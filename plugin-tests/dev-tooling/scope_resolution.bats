#!/usr/bin/env bats
# bats file_tags=dev-tooling,scope
# shellcheck disable=SC2016  # snippets passed to _scope_sh use ${SCOPE_NAME}/${SCOPE_CWD} that must expand in the subshell after sourcing scope.sh, not here
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

setup() {
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    log() { :; }
    source "${PLUGIN_DIR}/shared/scope.sh"
}

teardown() {
    unset LINT_CONFIG_FILE SCOPE_NAME SCOPE_CWD
}

_write_config() {
    echo "$1" > "${LINT_CONFIG_FILE}"
}

# Run a bash snippet in a subshell with scope.sh sourced and a silent log().
# The snippet typically ends with: resolve_scope "..."; echo "${SCOPE_NAME}|${SCOPE_CWD}"
# Arguments after the snippet arrive as "$1", "$2", … inside it. A scope name
# under test belongs there rather than in the snippet text: the subshell parses
# the snippet as shell source, so a name carrying `$(...)` spliced into it would
# be expanded by this harness before scope.sh ever saw the value.
_scope_sh() {
    local snippet="$1"
    shift
    bash -c "source \"${PLUGIN_DIR}/shared/scope.sh\"; LINT_CONFIG_FILE=\"${LINT_CONFIG_FILE}\"; log(){ :; }; ${snippet}" bash ${@+"$@"}
}

# Assert that resolve_scope refuses a scope name, treating it as literal data
# rather than as text that becomes part of the jq filter program.
_assert_scope_refused() {
    run _scope_sh 'resolve_scope "$1"' "$1"
    assert_failure
    assert_output --partial 'is not declared'
}

@test "resolve_scope: no arg, no default -> shopware + empty cwd" {
    _write_config '{"environment":"native"}'
    # shellcheck disable=SC2016  # ${SCOPE_NAME}/${SCOPE_CWD} must expand inside the _scope_sh subshell
    run _scope_sh 'resolve_scope ""; echo "${SCOPE_NAME}|${SCOPE_CWD}"'
    assert_output "shopware|"
}

@test "resolve_scope: default_scope set -> uses it" {
    _write_config '{"environment":"native","default_scope":"plugin-x","scopes":{"plugin-x":{"cwd":"custom/plugins/X"}}}'
    # shellcheck disable=SC2016  # ${SCOPE_NAME}/${SCOPE_CWD} must expand inside the _scope_sh subshell
    run _scope_sh 'resolve_scope ""; echo "${SCOPE_NAME}|${SCOPE_CWD}"'
    assert_success
    assert_output "plugin-x|custom/plugins/X"
}

@test "resolve_scope: explicit arg overrides default" {
    _write_config '{"environment":"native","default_scope":"plugin-x","scopes":{"plugin-x":{"cwd":"custom/plugins/X"}}}'
    # shellcheck disable=SC2016  # ${SCOPE_NAME}/${SCOPE_CWD} must expand inside the _scope_sh subshell
    run _scope_sh 'resolve_scope "shopware"; echo "${SCOPE_NAME}|${SCOPE_CWD}"'
    assert_success
    assert_output "shopware|"
}

@test "resolve_scope: explicit declared scope -> that scope's cwd" {
    _write_config '{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X"}}}'
    # shellcheck disable=SC2016  # ${SCOPE_NAME}/${SCOPE_CWD} must expand inside the _scope_sh subshell
    run _scope_sh 'resolve_scope "plugin-x"; echo "${SCOPE_NAME}|${SCOPE_CWD}"'
    assert_success
    assert_output "plugin-x|custom/plugins/X"
}

@test "resolve_scope: undeclared scope -> error listing declared names" {
    _write_config '{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X"}}}'
    run _scope_sh 'resolve_scope "plugin-y"'
    assert_failure
    assert_output --partial 'Scope "plugin-y" is not declared'
    assert_output --partial 'plugin-x'
}

@test "resolve_scope: scope name carrying jq filter syntax -> refused as undeclared" {
    _write_config '{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X"}}}'
    _assert_scope_refused '" // {"cwd":"$(printf PWNED)"} // .scopes."missing'
}

@test "resolve_scope: scope name containing a double quote -> refused as undeclared" {
    _write_config '{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X"}}}'
    _assert_scope_refused 'plugin-"x'
}

@test "scope_validate: reserved name shopware in scopes -> error" {
    _write_config '{"environment":"native","scopes":{"shopware":{"cwd":"x"}}}'
    run _scope_sh 'scope_validate'
    assert_failure
    assert_output --partial 'shopware" is reserved'
}

@test "scope_validate: default_scope references missing scope -> error" {
    _write_config '{"environment":"native","default_scope":"ghost"}'
    run _scope_sh 'scope_validate'
    assert_failure
    assert_output --partial 'default_scope "ghost" is not declared'
}

@test "scope_validate: default_scope = shopware -> ok" {
    _write_config '{"environment":"native","default_scope":"shopware"}'
    run _scope_sh 'scope_validate'
    assert_success
}

@test "scope_validate: declared default_scope -> ok" {
    _write_config '{"environment":"native","default_scope":"plugin-x","scopes":{"plugin-x":{"cwd":"custom/plugins/X"}}}'
    run _scope_sh 'scope_validate'
    assert_success
}

@test "scope_get_tool_field: returns scoped value when present" {
    _write_config '{"environment":"native","scopes":{"plugin-x":{"cwd":"p","phpstan":{"config":"phpstan.neon"}}}}'
    run _scope_sh 'SCOPE_NAME=plugin-x; scope_get_tool_field phpstan config'
    assert_success
    assert_output "phpstan.neon"
}

@test "scope_get_tool_field: empty when scope = shopware" {
    _write_config '{"environment":"native","scopes":{"plugin-x":{"cwd":"p","phpstan":{"config":"phpstan.neon"}}}}'
    run _scope_sh 'SCOPE_NAME=shopware; scope_get_tool_field phpstan config'
    assert_success
    assert_output ""
}

@test "scope_get_bootstrap: returns newline-separated commands" {
    _write_config '{"environment":"native","scopes":{"plugin-x":{"cwd":"p","phpstan":{"bootstrap":["a b","c d"]}}}}'
    run _scope_sh 'SCOPE_NAME=plugin-x; scope_get_bootstrap phpstan'
    assert_success
    assert_line --index 0 "a b"
    assert_line --index 1 "c d"
}

@test "scope_get_bootstrap: empty when no bootstrap declared" {
    _write_config '{"environment":"native","scopes":{"plugin-x":{"cwd":"p"}}}'
    run _scope_sh 'SCOPE_NAME=plugin-x; scope_get_bootstrap phpstan'
    assert_success
    assert_output ""
}
