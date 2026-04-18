#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,js-storefront
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

setup() {
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-js-tooling.json"
    echo '{"environment":"native"}' > "${LINT_CONFIG_FILE}"
    JS_CONTEXT="storefront"
    log() { :; }
    source "${PLUGIN_DIR}/shared/environment.sh"
    source "${PLUGIN_DIR}/shared/scope.sh"
    exec_npm_command() { echo "$1"; }
    source "${PLUGIN_DIR}/mcp-server-js-storefront/lib/eslint.sh"
    source "${PLUGIN_DIR}/mcp-server-js-storefront/lib/stylelint.sh"
    source "${PLUGIN_DIR}/mcp-server-js-storefront/lib/jest.sh"
    source "${PLUGIN_DIR}/mcp-server-js-storefront/lib/build.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE JS_CONTEXT SCOPE_NAME SCOPE_CWD
}

# --- ESLint (storefront uses lint:js, not lint) ---

@test "storefront eslint check: uses npm run lint:js" {
    run tool_eslint_check '{}'
    assert_success
    assert_output --partial "npm run lint:js"
    refute_output --partial "npm run lint "
}

@test "storefront eslint check: json format when specified" {
    run tool_eslint_check '{"output_format":"json"}'
    assert_success
    assert_output --partial "-f json"
}

@test "storefront eslint fix: uses npm run lint:js:fix" {
    run tool_eslint_fix '{}'
    assert_success
    assert_output --partial "npm run lint:js:fix"
}

# --- Stylelint ---

@test "storefront stylelint check: uses npm run lint:scss" {
    run tool_stylelint_check '{}'
    assert_success
    assert_output --partial "npm run lint:scss"
}

@test "storefront stylelint check: defaults to **/*.scss glob" {
    run tool_stylelint_check '{}'
    assert_success
    assert_output --partial "**/*.scss"
}

@test "storefront stylelint fix: uses npm run lint:scss-fix" {
    run tool_stylelint_fix '{}'
    assert_success
    assert_output --partial "npm run lint:scss-fix"
}

# --- Jest ---

@test "storefront jest: base command uses npm run unit" {
    run tool_jest_run '{}'
    assert_success
    assert_output --partial "npm run unit"
}

@test "storefront jest: testPathPatterns flag added when provided" {
    run tool_jest_run '{"testPathPatterns":"CartPlugin"}'
    assert_success
    assert_output --partial "--testPathPatterns='CartPlugin'"
}

@test "storefront jest: coverage flag added when coverage=true" {
    run tool_jest_run '{"coverage":true}'
    assert_success
    assert_output --partial "--coverage"
}

# --- Webpack build ---

@test "storefront webpack build: production mode by default" {
    run tool_webpack_build '{}'
    assert_success
    assert_output --partial "npm run production"
}

@test "storefront webpack build: development mode when specified" {
    run tool_webpack_build '{"mode":"development"}'
    assert_success
    assert_output --partial "npm run development"
}

@test "storefront webpack build: watch/hot mode is rejected" {
    run tool_webpack_build '{"mode":"hot"}'
    assert_failure
    assert_output --partial "Watch mode is not supported"
}
