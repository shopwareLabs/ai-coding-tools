#!/usr/bin/env bats
# bats file_tags=mcp-core,config
# Tests for the shared config module's filename and environment-variable
# derivation from CONFIG_PREFIX (.mcp-<prefix>.json, MCP_*_CONFIG), its
# required-input refusal, and the merge of more than one discovered file.
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

# The merge runs whenever two discovery locations hold a file, and its temp file
# is the server's for the rest of the process. The EXIT trap config.sh installs
# is what removes it, so the observation is made after the process has exited.
@test "the merged config of two discovered files is removed when the process exits" {
    local project="${BATS_TEST_TMPDIR}/project"
    mkdir -p "${project}/.claude" "${BATS_TEST_TMPDIR}/tmp"
    printf '{"environment":"native"}\n' > "${project}/.mcp-php-tooling.json"
    printf '{"default_scope":"x"}\n' > "${project}/.claude/.mcp-php-tooling.json"

    run bash -c "
        set -euo pipefail
        log() { :; }
        # Places the merge's temp file where the test can list it; macOS mktemp
        # ignores TMPDIR when it is called without a template.
        mktemp() { command mktemp '${BATS_TEST_TMPDIR}/tmp/merged.XXXXXX'; }
        CONFIG_PREFIX='php-tooling'
        source '${CONFIG_SH}'
        load_config '${project}'
        jq -c . \"\${LINT_CONFIG_FILE}\"
        printf '%s\n' \"\${LINT_CONFIG_FILE}\"
    "
    assert_success
    assert_line --index 0 '{"environment":"native","default_scope":"x"}'
    assert_line --index 1 --regexp "^${BATS_TEST_TMPDIR}/tmp/"
    run find "${BATS_TEST_TMPDIR}/tmp" -type f
    assert_output ""
}

@test "a discovered config that is not valid JSON fails the merge, naming the file" {
    local project="${BATS_TEST_TMPDIR}/project"
    mkdir -p "${project}/.claude"
    printf '{"environment":"native"}\n' > "${project}/.mcp-php-tooling.json"
    printf '{bad\n' > "${project}/.claude/.mcp-php-tooling.json"

    run bash -c "
        set -euo pipefail
        log() { printf '%s: %s\n' \"\$1\" \"\$2\"; }
        CONFIG_PREFIX='php-tooling'
        source '${CONFIG_SH}'
        if load_config '${project}'; then
            printf 'loaded: %s\n' \"\${LINT_CONFIG_FILE:-}\"
        else
            printf 'load_config failed\n'
        fi
    "
    assert_success
    assert_line "ERROR: ${project}/.claude/.mcp-php-tooling.json is not valid JSON: a config file must hold one JSON object"
    assert_line --index -1 "load_config failed"
}
