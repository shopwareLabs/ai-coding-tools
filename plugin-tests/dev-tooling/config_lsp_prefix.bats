#!/usr/bin/env bats

# Unit tests for shared/config.sh filename/env-var prefix parameterization.
# Verifies:
#  - MCP path (no CONFIG_FILE_PREFIX set) produces .mcp-<prefix>.json, MCP_*_CONFIG
#  - LSP path (CONFIG_FILE_PREFIX=".lsp-") produces .lsp-<prefix>.json, LSP_*_CONFIG
#  - Missing CONFIG_PREFIX still fails as before

setup() {
    SHARED_DIR="$(cd "${BATS_TEST_DIRNAME}/../../plugins/dev-tooling/shared" && pwd)"
}

@test "MCP path: CONFIG_FILE_NAME is .mcp-php-tooling.json when CONFIG_FILE_PREFIX unset" {
    run bash -c "
        set -euo pipefail
        log() { :; }
        export -f log
        CONFIG_PREFIX='php-tooling'
        unset CONFIG_FILE_PREFIX CONFIG_ENV_VAR_PREFIX
        source '${SHARED_DIR}/config.sh'
        echo \"\${CONFIG_FILE_NAME}|\${CONFIG_ENV_VAR}\"
    "
    [ "$status" -eq 0 ]
    [[ "${lines[-1]}" == ".mcp-php-tooling.json|MCP_PHP_TOOLING_CONFIG" ]]
}

@test "LSP path: CONFIG_FILE_NAME is .lsp-php-tooling.json when CONFIG_FILE_PREFIX=.lsp-" {
    run bash -c "
        set -euo pipefail
        log() { :; }
        export -f log
        CONFIG_PREFIX='php-tooling'
        CONFIG_FILE_PREFIX='.lsp-'
        CONFIG_ENV_VAR_PREFIX='LSP'
        source '${SHARED_DIR}/config.sh'
        echo \"\${CONFIG_FILE_NAME}|\${CONFIG_ENV_VAR}\"
    "
    [ "$status" -eq 0 ]
    [[ "${lines[-1]}" == ".lsp-php-tooling.json|LSP_PHP_TOOLING_CONFIG" ]]
}

@test "LSP path fails when CONFIG_FILE_PREFIX set but CONFIG_ENV_VAR_PREFIX unset" {
    run bash -c "
        set -euo pipefail
        log() { :; }
        export -f log
        CONFIG_PREFIX='php-tooling'
        CONFIG_FILE_PREFIX='.lsp-'
        unset CONFIG_ENV_VAR_PREFIX
        source '${SHARED_DIR}/config.sh'
    "
    [ "$status" -ne 0 ]
    [[ "$output" == *"CONFIG_ENV_VAR_PREFIX required"* ]]
}

@test "Missing CONFIG_PREFIX still fails (regression guard for MCP path)" {
    run bash -c "
        set -euo pipefail
        log() { :; }
        export -f log
        unset CONFIG_PREFIX CONFIG_FILE_PREFIX CONFIG_ENV_VAR_PREFIX
        source '${SHARED_DIR}/config.sh'
    "
    [ "$status" -ne 0 ]
    [[ "$output" == *"CONFIG_PREFIX must be set"* ]]
}
