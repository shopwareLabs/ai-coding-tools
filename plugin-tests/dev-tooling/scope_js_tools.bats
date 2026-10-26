#!/usr/bin/env bats
# bats file_tags=dev-tooling,scope,js
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

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
    source "${PLUGIN_DIR}/shared/js_paths.sh"
    source "${PLUGIN_DIR}/shared/scope.sh"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    export PROJECT_ROOT
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/shared/worktree.sh"
    worktree_state_init
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
                shopware_trunk_script_body administration "${name%\"}"
                ;;
            *)
                printf '%s\n' "${cmd}"
                ;;
        esac
    }
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/eslint.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/stylelint.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/prettier.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/tsc.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/jest.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/lint-all.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/tsc.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/build.sh"
    source "${PLUGIN_DIR}/mcp-server-js-storefront/lib/build.sh"
}

teardown() {
    worktree_state_cleanup
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE JS_CONTEXT SCOPE_CWD SCOPE_NAME SCOPE_JS_SUBDIR CALLS_FILE \
        PROJECT_ROOT DEV_TOOLING_STATE_FILE
}

js_tool_refuses_string_section() {
    local function_name="$1" section="$2"
    jq --arg section "${section}" '.scopes["plugin-x"][$section] = "invalid"' "${LINT_CONFIG_FILE}" > "${LINT_CONFIG_FILE}.new"
    mv "${LINT_CONFIG_FILE}.new" "${LINT_CONFIG_FILE}"
    run "${function_name}" '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial 'Config error: jq could not evaluate'
    assert_output --partial 'Cannot index string'
    [ ! -e "${CALLS_FILE}" ]
}

bats_test_function --description "admin eslint_check: string section refuses without executing" -- js_tool_refuses_string_section tool_eslint_check eslint
bats_test_function --description "admin eslint_fix: string section refuses without executing" -- js_tool_refuses_string_section tool_eslint_fix eslint
bats_test_function --description "admin stylelint_check: string section refuses without executing" -- js_tool_refuses_string_section tool_stylelint_check stylelint
bats_test_function --description "admin stylelint_fix: string section refuses without executing" -- js_tool_refuses_string_section tool_stylelint_fix stylelint
bats_test_function --description "admin prettier_check: string section refuses without executing" -- js_tool_refuses_string_section tool_prettier_check prettier
bats_test_function --description "admin prettier_fix: string section refuses without executing" -- js_tool_refuses_string_section tool_prettier_fix prettier
bats_test_function --description "admin tsc_check: string section refuses without executing" -- js_tool_refuses_string_section tool_tsc_check tsc
bats_test_function --description "admin jest_run: string section refuses without executing" -- js_tool_refuses_string_section tool_jest_run jest

@test "jest: an invalid install flag refuses before running a command" {
    jq '.scopes["plugin-x"].jest.install_if_missing = "true"' "${LINT_CONFIG_FILE}" > "${LINT_CONFIG_FILE}.new"
    mv "${LINT_CONFIG_FILE}.new" "${LINT_CONFIG_FILE}"
    run tool_jest_run '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial 'jest.install_if_missing must be a boolean (found string)'
    [ ! -e "${CALLS_FILE}" ]
}

@test "jest: explicit null install flag refuses before running a command" {
    jq '.scopes["plugin-x"].jest.install_if_missing = null' "${LINT_CONFIG_FILE}" > "${LINT_CONFIG_FILE}.new"
    mv "${LINT_CONFIG_FILE}.new" "${LINT_CONFIG_FILE}"
    run tool_jest_run '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial 'jest.install_if_missing must be a boolean (found null)'
    [ ! -e "${CALLS_FILE}" ]
}

@test "jest: an invalid env map refuses with jq's error" {
    jq '.scopes["plugin-x"].jest.env = "invalid" | .scopes["plugin-x"].jest.install_if_missing = false' "${LINT_CONFIG_FILE}" > "${LINT_CONFIG_FILE}.new"
    mv "${LINT_CONFIG_FILE}.new" "${LINT_CONFIG_FILE}"
    run tool_jest_run '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial 'string ("invalid") has no keys'
    [ ! -e "${CALLS_FILE}" ]
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

# The scope runs in the plugin root, so a plugin's own administration tree is a
# path below that root and gets no rebase onto the core package directory.
@test "eslint scoped: a repo-root path under the scope cwd keeps its path below the plugin root" {
    mkdir -p "${BATS_TEST_TMPDIR}/custom/plugins/X/src/Resources/app/administration/src"
    touch "${BATS_TEST_TMPDIR}/custom/plugins/X/src/Resources/app/administration/src/x.ts"
    run tool_eslint_check '{"scope":"plugin-x","paths":["custom/plugins/X/src/Resources/app/administration/src/x.ts"]}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --regexp '^\[scope=custom/plugins/X\|sub=\] npm exec --no -- eslint .* "src/Resources/app/administration/src/x\.ts"$'
}

@test "stylelint scoped with paths: probes for and runs the local binary under the scope cwd" {
    run tool_stylelint_check '{"scope":"plugin-x","paths":["src/scss/base.scss"]}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --partial '[scope=custom/plugins/X|sub=] npm exec --no -c "test -x node_modules/.bin/stylelint'
    assert_line '[scope=custom/plugins/X|sub=] npm exec --no -- stylelint --cache -f string "src/scss/base.scss"'
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
    assert_output --partial 'NODE_OPTIONS="--require ./bootstrap.js" npm run unit'
}

@test "jest scoped: an env value containing a line break is refused" {
    _set_jest_env '{"NODE_OPTIONS":"--require\n./bootstrap.js"}'
    run tool_jest_run '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial 'declares a jest.env entry containing a line break'
}

@test "jest scoped: a refused test path pattern installs nothing" {
    # node_modules deliberately missing, so install_if_missing would run npm ci
    mkdir -p "${BATS_TEST_TMPDIR}/custom/plugins/X/tests/jest/administration"
    touch "${CALLS_FILE}"
    run tool_jest_run '{"scope":"plugin-x","testPathPatterns":"a\nb"}'
    assert_failure
    assert_output --partial "contains a line break"
    run cat "${CALLS_FILE}"
    refute_output --partial "npm ci"
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

@test "jest scoped: install_if_missing measures the host path under a container environment" {
    # The [[ -d ]] runs on the host, and LINT_WORKDIR is environment-side under
    # a container — composed from it, the test was always false and every
    # scoped run paid a full `npm ci` although node_modules existed.
    LINT_ENV="docker"
    LINT_WORKDIR="/srv/app"
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

@test "lint_all scoped: runs under scope cwd" {
    run tool_lint_all '{"scope":"plugin-x"}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --partial "[scope=custom/plugins/X|sub=]"
}

@test "lint_twig scoped: runs under scope cwd" {
    run tool_lint_twig '{"scope":"plugin-x"}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --partial "[scope=custom/plugins/X|sub=]"
}

@test "unit_setup scoped: runs under scope cwd" {
    run tool_unit_setup '{"scope":"plugin-x"}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --partial "[scope=custom/plugins/X|sub=]"
}

@test "vite_build scoped: runs under scope cwd" {
    run tool_vite_build '{"scope":"plugin-x"}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --partial "[scope=custom/plugins/X|sub=]"
}

@test "webpack_build scoped: runs under scope cwd" {
    run tool_webpack_build '{"scope":"plugin-x"}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --partial "[scope=custom/plugins/X|sub=]"
}

# The core-only tools run scripts a plugin package does not define, so a
# default_scope pinned to a plugin must not move them into it.
_assert_core_tool_ignores_default_scope() {
    local pinned
    pinned=$(jq '.default_scope = "plugin-x"' "${LINT_CONFIG_FILE}")
    printf '%s\n' "${pinned}" > "${LINT_CONFIG_FILE}"
    run "tool_$1" '{}'
    assert_success
    run cat "${CALLS_FILE}"
    refute_line --partial "[scope=custom/plugins/X"
    assert_line --partial "[scope=<unscoped>|sub=]"
}

bats_test_function --description "lint_all: a default_scope pinned to a plugin still runs in the core package" \
    -- _assert_core_tool_ignores_default_scope lint_all
bats_test_function --description "lint_twig: a default_scope pinned to a plugin still runs in the core package" \
    -- _assert_core_tool_ignores_default_scope lint_twig
bats_test_function --description "unit_setup: a default_scope pinned to a plugin still runs in the core package" \
    -- _assert_core_tool_ignores_default_scope unit_setup
bats_test_function --description "tsc_check: a default_scope pinned to a plugin still runs in the core package" \
    -- _assert_core_tool_ignores_default_scope tsc_check
bats_test_function --description "vite_build: a default_scope pinned to a plugin still runs in the core package" \
    -- _assert_core_tool_ignores_default_scope vite_build
bats_test_function --description "webpack_build: a default_scope pinned to a plugin still runs in the core package" \
    -- _assert_core_tool_ignores_default_scope webpack_build
