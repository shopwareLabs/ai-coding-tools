#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,js-admin
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
        lint:scss)
            printf '%s\n' '"stylelint **/*.scss --cache"' ;;
        lint:scss-fix)
            printf '%s\n' '"npm run lint:scss -- --fix"' ;;
        *)
            printf '%s\n' '{}' ;;
    esac
}

setup() {
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-js-tooling.json"
    echo '{"environment":"native"}' > "${LINT_CONFIG_FILE}"
    JS_CONTEXT="admin"
    log() { :; }
    source "${PLUGIN_DIR}/shared/environment.sh"
    source "${PLUGIN_DIR}/shared/scope.sh"
    exec_npm_command() {
        local cmd="$1"
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
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/stylelint.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/prettier.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/jest.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/tsc.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/lint-all.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/build.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE JS_CONTEXT SCOPE_NAME SCOPE_CWD
}

# --- ESLint ---

@test "admin eslint check: uses npm run lint" {
    run tool_eslint_check '{}'
    assert_success
    assert_output --partial "npm run lint"
}

@test "admin eslint check: stylish format by default" {
    run tool_eslint_check '{}'
    assert_success
    assert_output --partial "-f stylish"
}

@test "admin eslint check: json format when specified" {
    run tool_eslint_check '{"output_format":"json"}'
    assert_success
    assert_output --partial "-f json"
}

@test "admin eslint check: paths appended to command" {
    run tool_eslint_check '{"paths":["src/app/component"]}'
    assert_success
    assert_output 'npm run lint -- -f stylish "src/app/component"'
}

@test "admin eslint check: keeps a path containing a space in one argument" {
    run tool_eslint_check '{"paths":["src/app/my component"]}'
    assert_success
    assert_output 'npm run lint -- -f stylish "src/app/my component"'
}

@test "admin eslint check: refuses a path containing a single quote" {
    run tool_eslint_check "{\"paths\":[\"src/it's.js\"]}"
    assert_failure
    assert_output --partial "single quote"
}

@test "admin eslint check: refuses an empty string path instead of widening the run" {
    run tool_eslint_check '{"paths":[""]}'
    assert_failure
    refute_output --partial "npm run lint --"
    assert_output --partial "non-empty strings"
}

@test "admin eslint check: refuses a paths value that is not an array" {
    run tool_eslint_check '{"paths":"src/app/component"}'
    assert_failure
    refute_output --partial "npm run lint --"
    assert_output --partial "must be an array of strings"
}

@test "admin eslint fix: uses npm run lint:fix" {
    run tool_eslint_fix '{}'
    assert_success
    assert_output --partial "npm run lint:fix"
}

# --- Stylelint ---

@test "admin stylelint check: uses npm run lint:scss" {
    run tool_stylelint_check '{}'
    assert_success
    assert_output --partial "npm run lint:scss"
}

@test "admin stylelint check: no paths appends no path target" {
    run tool_stylelint_check '{}'
    assert_success
    assert_output "npm run lint:scss -- -f string"
    refute_output --partial "**/*.scss"
}

@test "admin stylelint check: json format when specified" {
    run tool_stylelint_check '{"output_format":"json"}'
    assert_success
    assert_output --partial "-f json"
}

@test "admin stylelint fix: uses npm run lint:scss-fix" {
    run tool_stylelint_fix '{}'
    assert_success
    assert_output --partial "npm run lint:scss-fix"
}

# --- Prettier ---

@test "admin prettier check: uses npm run format" {
    run tool_prettier_check
    assert_success
    assert_output --partial "npm run format"
}

@test "admin prettier fix: uses npm run format:fix" {
    run tool_prettier_fix
    assert_success
    assert_output --partial "npm run format:fix"
}

# --- TypeScript ---

@test "admin tsc check: uses npm run lint:types" {
    run tool_tsc_check
    assert_success
    assert_output --partial "npm run lint:types"
}

# --- Lint all / Twig ---

@test "admin lint_all: uses npm run lint:all" {
    run tool_lint_all
    assert_success
    assert_output --partial "npm run lint:all"
}

@test "admin lint_twig: uses npm run lint:twig" {
    run tool_lint_twig
    assert_success
    assert_output --partial "npm run lint:twig"
}

# --- Jest ---

@test "admin jest: base command uses npm run unit" {
    run tool_jest_run '{}'
    assert_success
    assert_output --partial "npm run unit"
}

@test "admin jest: testPathPatterns flag added when provided" {
    run tool_jest_run '{"testPathPatterns":"CartService"}'
    assert_success
    assert_output --partial "--testPathPatterns='CartService'"
}

@test "admin jest: coverage flag added when coverage=true" {
    run tool_jest_run '{"coverage":true}'
    assert_success
    assert_output --partial "--coverage"
}

# --- Vite build ---

@test "admin vite build: production mode by default" {
    run tool_vite_build '{}'
    assert_success
    assert_output --partial "npm run build -- --mode production"
}
