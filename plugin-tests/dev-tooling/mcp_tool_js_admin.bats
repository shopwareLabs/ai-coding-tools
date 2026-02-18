#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,js-admin

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

setup() {
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    JS_CONTEXT="admin"
    log() { :; }
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/shared/environment.sh"
    exec_npm_command() { echo "$1"; }
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/eslint.sh"
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/stylelint.sh"
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/prettier.sh"
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/jest.sh"
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/tsc.sh"
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/lint-all.sh"
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/build.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR JS_CONTEXT
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
    assert_output --partial "src/app/component"
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

@test "admin stylelint check: defaults to **/*.scss glob" {
    run tool_stylelint_check '{}'
    assert_success
    assert_output --partial "**/*.scss"
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

@test "admin jest: testPathPattern flag added when provided" {
    run tool_jest_run '{"testPathPattern":"CartService"}'
    assert_success
    assert_output --partial "--testPathPattern='CartService'"
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
