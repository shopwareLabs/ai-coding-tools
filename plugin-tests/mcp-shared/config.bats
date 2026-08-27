#!/usr/bin/env bats
# bats file_tags=mcp-core,config
# Tests for the shared config module's filename and environment-variable prefix
# parameterization: the MCP path (.mcp-<prefix>.json, MCP_*_CONFIG), the LSP path
# (.lsp-<prefix>.json, LSP_*_CONFIG), and the two required-input refusals.
# Sources the template source of truth (templates/mcp-shared/config.sh); every
# plugin copy is kept byte-identical to it by the template-sync CI check, so this
# one suite covers the module in all consuming plugins.
bats_require_minimum_version 1.11.0

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

setup() {
    CONFIG_SH="${REPO_ROOT}/templates/mcp-shared/config.sh"
}

@test "MCP path: CONFIG_FILE_NAME is .mcp-php-tooling.json when CONFIG_FILE_PREFIX unset" {
    run bash -c "
        set -euo pipefail
        log() { :; }
        export -f log
        CONFIG_PREFIX='php-tooling'
        unset CONFIG_FILE_PREFIX CONFIG_ENV_VAR_PREFIX
        source '${CONFIG_SH}'
        printf '%s|%s\n' \"\${CONFIG_FILE_NAME}\" \"\${CONFIG_ENV_VAR}\"
    "
    assert_success
    assert_line --index -1 ".mcp-php-tooling.json|MCP_PHP_TOOLING_CONFIG"
}

@test "LSP path: CONFIG_FILE_NAME is .lsp-php-tooling.json when CONFIG_FILE_PREFIX=.lsp-" {
    run bash -c "
        set -euo pipefail
        log() { :; }
        export -f log
        CONFIG_PREFIX='php-tooling'
        CONFIG_FILE_PREFIX='.lsp-'
        CONFIG_ENV_VAR_PREFIX='LSP'
        source '${CONFIG_SH}'
        printf '%s|%s\n' \"\${CONFIG_FILE_NAME}\" \"\${CONFIG_ENV_VAR}\"
    "
    assert_success
    assert_line --index -1 ".lsp-php-tooling.json|LSP_PHP_TOOLING_CONFIG"
}

@test "LSP path fails when CONFIG_FILE_PREFIX set but CONFIG_ENV_VAR_PREFIX unset" {
    run bash -c "
        set -euo pipefail
        log() { :; }
        export -f log
        CONFIG_PREFIX='php-tooling'
        CONFIG_FILE_PREFIX='.lsp-'
        unset CONFIG_ENV_VAR_PREFIX
        source '${CONFIG_SH}'
    "
    assert_failure
    assert_output --partial "CONFIG_ENV_VAR_PREFIX required"
}

@test "Missing CONFIG_PREFIX fails on the MCP path" {
    run bash -c "
        set -euo pipefail
        log() { :; }
        export -f log
        unset CONFIG_PREFIX CONFIG_FILE_PREFIX CONFIG_ENV_VAR_PREFIX
        source '${CONFIG_SH}'
    "
    assert_failure
    assert_output --partial "CONFIG_PREFIX must be set"
}
