#!/usr/bin/env bats
# bats file_tags=dev-tooling,scope,js
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

# Answers the `npm pkg get "scripts.<name>"` probe with the body the Shopware
# Administration package.json declares.
_fake_admin_script_body() {
    local name="$1"

    case "${name}" in
        lint)
            printf '%s\n' '"eslint src test build.ts --cache"' ;;
        lint:fix)
            printf '%s\n' '"npm run lint -- --fix"' ;;
        lint:debugging)
            printf '%s\n' '"eslint"' ;;
        lint:scss)
            printf '%s\n' '"npm run stylelint:base -- **/*.scss"' ;;
        lint:scss-fix)
            printf '%s\n' '"npm run lint:scss -- --fix"' ;;
        jest:base)
            printf '%s\n' '"jest --config jest.config.js"' ;;
        *)
            printf '%s\n' '{}' ;;
    esac
}

setup() {
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-js-tooling.json"
    JS_CONTEXT="admin"
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{
  "environment":"native",
  "scopes":{
    "plugin-x":{
      "cwd":"custom/plugins/X",
      "eslint":{"config":"eslint.config.mjs"},
      "jest":{
        "cwd":"tests/jest/administration",
        "env":{"ADMIN_PATH":"../../../../../../src/Administration/Resources/app/administration"},
        "install_if_missing":true
      }
    }
  }
}
JSON
    log() { :; }
    CALLS_FILE="${BATS_TEST_TMPDIR}/calls.log"
    source "${PLUGIN_DIR}/shared/environment.sh"
    source "${PLUGIN_DIR}/shared/scope.sh"
    # Set LINT_ENV/LINT_WORKDIR AFTER sourcing environment.sh so its module-level
    # initializers ("") don't clobber our test values.
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    # Override after environment.sh so our stub wins.
    exec_npm_command() {
        local cmd="$1"
        printf '%s\n' "[scope=${SCOPE_CWD:-<unscoped>}|sub=${SCOPE_JS_SUBDIR:-}] ${cmd}" >> "${CALLS_FILE}"
        case "${cmd}" in
            'npm pkg get "scripts.'*)
                local name="${cmd#npm pkg get \"scripts.}"
                _fake_admin_script_body "${name%\"}"
                ;;
            *)
                printf '%s\n' "${cmd}"
                ;;
        esac
    }
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/eslint.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/jest.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE JS_CONTEXT SCOPE_CWD SCOPE_NAME SCOPE_JS_SUBDIR CALLS_FILE
}

@test "eslint scoped: runs under scope cwd" {
    run tool_eslint_check '{"scope":"plugin-x"}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --partial "[scope=custom/plugins/X|sub=]"
}

@test "eslint scoped: uses scope config" {
    run tool_eslint_check '{"scope":"plugin-x"}'
    assert_success
    assert_output --partial "eslint.config.mjs"
}

@test "eslint unscoped: backward compat, no SCOPE_CWD leaked" {
    run tool_eslint_check '{}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --partial "[scope=<unscoped>|sub=]"
}

@test "eslint scoped: undeclared scope -> hard error" {
    run tool_eslint_check '{"scope":"ghost"}'
    assert_failure
    assert_output --partial 'Scope "ghost" is not declared'
}

@test "jest scoped: runs in scope cwd + jest.cwd" {
    mkdir -p "${BATS_TEST_TMPDIR}/custom/plugins/X/tests/jest/administration/node_modules"
    run tool_jest_run '{"scope":"plugin-x"}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --partial "[scope=custom/plugins/X|sub=tests/jest/administration]"
}

@test "jest scoped: exports env vars for npm command" {
    mkdir -p "${BATS_TEST_TMPDIR}/custom/plugins/X/tests/jest/administration/node_modules"
    run tool_jest_run '{"scope":"plugin-x"}'
    assert_success
    assert_output --partial 'ADMIN_PATH="../../../../../../src/Administration/Resources/app/administration"'
}

# Replace the scope's jest.env map, keeping the rest of the arrange setup() wrote.
_set_jest_env() {
    local updated
    updated=$(jq --argjson env "$1" '.scopes["plugin-x"].jest.env = $env' "${LINT_CONFIG_FILE}")
    printf '%s\n' "${updated}" > "${LINT_CONFIG_FILE}"
    mkdir -p "${BATS_TEST_TMPDIR}/custom/plugins/X/tests/jest/administration/node_modules"
}

@test "jest scoped: an env value containing a space stays one assignment" {
    _set_jest_env '{"NODE_OPTIONS":"--require ./bootstrap.js"}'
    run tool_jest_run '{"scope":"plugin-x"}'
    assert_success
    assert_output --partial 'NODE_OPTIONS="--require ./bootstrap.js" npm run jest:base'
}

@test "jest scoped: an env value containing a line break is refused" {
    _set_jest_env '{"NODE_OPTIONS":"--require\n./bootstrap.js"}'
    run tool_jest_run '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial 'declares a jest.env entry containing a line break'
}

@test "jest scoped: install_if_missing runs npm ci when node_modules absent" {
    # node_modules deliberately missing
    mkdir -p "${BATS_TEST_TMPDIR}/custom/plugins/X/tests/jest/administration"
    run tool_jest_run '{"scope":"plugin-x"}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --index 0 --partial "npm ci"
}

@test "jest scoped: install_if_missing skipped when node_modules present" {
    mkdir -p "${BATS_TEST_TMPDIR}/custom/plugins/X/tests/jest/administration/node_modules"
    run tool_jest_run '{"scope":"plugin-x"}'
    assert_success
    run cat "${CALLS_FILE}"
    refute_line --partial "npm ci"
}

@test "jest unscoped: no ADMIN_PATH env export in command" {
    run tool_jest_run '{}'
    assert_success
    refute_output --partial "ADMIN_PATH"
}

@test "jest unscoped: no install_if_missing npm ci runs" {
    run tool_jest_run '{}'
    assert_success
    run cat "${CALLS_FILE}"
    refute_line --partial "npm ci"
}

@test "jest scoped: routes at jest:base, not the fallback aggregate" {
    mkdir -p "${BATS_TEST_TMPDIR}/custom/plugins/X/tests/jest/administration/node_modules"
    run tool_jest_run '{"scope":"plugin-x"}'
    assert_success
    assert_output --partial "npm run jest:base"
    refute_output --partial "npm run unit"
}
