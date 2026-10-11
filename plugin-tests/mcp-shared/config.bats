#!/usr/bin/env bats
# bats file_tags=mcp-core,config
# Tests for the shared config module's filename and environment-variable
# derivation from CONFIG_PREFIX (.mcp-<prefix>.json, MCP_*_CONFIG) and its
# required-input refusal.
# Sources the template source of truth (templates/mcp-shared/config.sh); every
# plugin copy is kept byte-identical to it by the template-sync CI check, so this
# one suite covers the module in all consuming plugins.
bats_require_minimum_version 1.11.0

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

setup() {
    CONFIG_SH="${REPO_ROOT}/templates/mcp-shared/config.sh"
}

@test "CONFIG_FILE_NAME is .mcp-php-tooling.json and CONFIG_ENV_VAR is MCP_PHP_TOOLING_CONFIG" {
    run bash -c "
        set -euo pipefail
        log() { :; }
        export -f log
        CONFIG_PREFIX='php-tooling'
        source '${CONFIG_SH}'
        printf '%s|%s\n' \"\${CONFIG_FILE_NAME}\" \"\${CONFIG_ENV_VAR}\"
    "
    assert_success
    assert_line --index -1 ".mcp-php-tooling.json|MCP_PHP_TOOLING_CONFIG"
}

@test "Missing CONFIG_PREFIX fails" {
    run bash -c "
        set -euo pipefail
        log() { :; }
        export -f log
        unset CONFIG_PREFIX
        source '${CONFIG_SH}'
    "
    assert_failure
    assert_output --partial "CONFIG_PREFIX must be set"
}
