#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,js-storefront
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

# Answers the `npm pkg get "scripts.<name>"` probe with the body the Shopware
# Storefront package.json declares. FAKE_ABSENT_SCRIPTS makes a script look
# undefined; FAKE_BODY_NAME/FAKE_BODY makes one report a different body.
_fake_script_body() {
    local name="$1"

    case " ${FAKE_ABSENT_SCRIPTS} " in
        *" ${name} "*) printf '%s\n' '{}'; return ;;
    esac

    if [[ -n "${FAKE_BODY_NAME}" && "${name}" == "${FAKE_BODY_NAME}" ]]; then
        printf '%s\n' "\"${FAKE_BODY}\""
        return
    fi

    case "${name}" in
        eslint:app)
            printf '%s\n' '"eslint --no-error-on-unmatched-pattern --report-unused-disable-directives"' ;;
        eslint:components)
            printf '%s\n' '"cd ../.. && eslint --no-error-on-unmatched-pattern --config ./app/storefront/eslint.config.js --report-unused-disable-directives"' ;;
        lint:js)
            printf '%s\n' '"npm run lint:js:app && npm run lint:js:components"' ;;
        lint:js:fix)
            printf '%s\n' '"npm run lint:js:app:fix && npm run lint:js:components:fix"' ;;
        lint:scss)
            printf '%s\n' '"stylelint --config stylelint.config.js ./src/scss --cache"' ;;
        lint:scss-fix)
            printf '%s\n' '"npm run lint:scss -- --fix"' ;;
        unit)
            printf '%s\n' '"jest --config jest.config.js --ci"' ;;
        unit:components)
            printf '%s\n' '"vitest run --config vitest.config.mts"' ;;
        unit:components:coverage)
            printf '%s\n' '"vitest run --coverage --config vitest.config.mts"' ;;
        *)
            printf '%s\n' '{}' ;;
    esac
}

setup() {
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-js-tooling.json"
    echo '{"environment":"native"}' > "${LINT_CONFIG_FILE}"
    JS_CONTEXT="storefront"
    FAKE_ABSENT_SCRIPTS=""
    FAKE_BODY_NAME=""
    FAKE_BODY=""
    FAKE_PROBE_OUTPUT=""
    FAKE_PROBE_FILE="${BATS_TEST_TMPDIR}/probe.txt"
    log() { :; }
    source "${PLUGIN_DIR}/shared/environment.sh"
    source "${PLUGIN_DIR}/shared/scope.sh"
    exec_npm_command() {
        local cmd="$1"
        case "${cmd}" in
            'npm pkg get "scripts.'*)
                local name="${cmd#npm pkg get \"scripts.}"
                _fake_script_body "${name%\"}"
                ;;
            'cd "'*)
                printf '%s\n' "$1" > "${FAKE_PROBE_FILE}"
                printf '%s\n' "${FAKE_PROBE_OUTPUT}"
                ;;
            *)
                printf '%s\n' "${cmd}"
                ;;
        esac
    }
    exec_command() { printf '%s\n' "$1"; }
    source "${PLUGIN_DIR}/mcp-server-js-storefront/lib/eslint.sh"
    source "${PLUGIN_DIR}/mcp-server-js-storefront/lib/stylelint.sh"
    source "${PLUGIN_DIR}/mcp-server-js-storefront/lib/jest.sh"
    source "${PLUGIN_DIR}/mcp-server-js-storefront/lib/vitest.sh"
    source "${PLUGIN_DIR}/mcp-server-js-storefront/lib/ludtwig.sh"
    source "${PLUGIN_DIR}/mcp-server-js-storefront/lib/build.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE JS_CONTEXT SCOPE_NAME SCOPE_CWD \
        SCOPE_JS_SUBDIR FAKE_ABSENT_SCRIPTS FAKE_BODY_NAME FAKE_BODY FAKE_PROBE_OUTPUT \
        FAKE_PROBE_FILE
}

# --- ESLint: no paths runs the aggregate script bare ---

@test "storefront eslint check: no paths runs lint:js bare" {
    run tool_eslint_check '{}'
    assert_success
    assert_output "npm run lint:js"
}

@test "storefront eslint fix: no paths runs lint:js:fix bare" {
    run tool_eslint_fix '{}'
    assert_success
    assert_output "npm run lint:js:fix"
}

# --- ESLint: tree routing and rebasing ---

@test "storefront eslint check: app-tree path uses eslint:app rebased to the package dir" {
    run tool_eslint_check '{"paths":["src/Storefront/Resources/app/storefront/src/plugin/cart.plugin.js"]}'
    assert_success
    assert_output --partial 'npm run eslint:app -- -f stylish "src/plugin/cart.plugin.js"'
}

@test "storefront eslint check: tree-relative app path is passed through unchanged" {
    run tool_eslint_check '{"paths":["build/webpack/config.js"]}'
    assert_success
    assert_output --partial 'npm run eslint:app -- -f stylish "build/webpack/config.js"'
}

@test "storefront eslint check: components path uses eslint:components rebased to the resources dir" {
    run tool_eslint_check '{"paths":["src/Storefront/Resources/views/components/checkout/cart.js"]}'
    assert_success
    assert_output --partial 'npm run eslint:components -- -f stylish "views/components/checkout/cart.js"'
}

@test "storefront eslint check: tree-relative components path keeps its views/components prefix" {
    run tool_eslint_check '{"paths":["views/components/checkout/cart.js"]}'
    assert_success
    assert_output --partial 'npm run eslint:components -- -f stylish "views/components/checkout/cart.js"'
}

@test "storefront eslint check: mixed paths run the app tree" {
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js","views/components/checkout/cart.js"]}'
    assert_success
    assert_output --partial 'npm run eslint:app -- -f stylish "src/plugin/cart.plugin.js"'
}

@test "storefront eslint check: mixed paths run the components tree" {
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js","views/components/checkout/cart.js"]}'
    assert_success
    assert_output --partial 'npm run eslint:components -- -f stylish "views/components/checkout/cart.js"'
}

@test "storefront eslint check: json format applied when paths are supplied" {
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js"],"output_format":"json"}'
    assert_success
    assert_output --partial "-f json"
}

@test "storefront eslint fix: appends --fix ahead of the paths" {
    run tool_eslint_fix '{"paths":["src/plugin/cart.plugin.js"]}'
    assert_success
    assert_output --partial 'npm run eslint:app -- --fix "src/plugin/cart.plugin.js"'
}

# --- ESLint: fallback and hard failures ---

@test "storefront eslint check: falls back to lint:js when eslint:app is absent" {
    FAKE_ABSENT_SCRIPTS="eslint:app"
    FAKE_BODY_NAME="lint:js"
    FAKE_BODY="eslint --no-error-on-unmatched-pattern"
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js"]}'
    assert_success
    assert_output --partial 'npm run lint:js -- -f stylish "src/plugin/cart.plugin.js"'
}

@test "storefront eslint check: fails hard when the lint:js fallback only chains bare run-scripts" {
    FAKE_ABSENT_SCRIPTS="eslint:app"
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js"]}'
    assert_failure
    assert_output --partial "lint:js"
    assert_output --partial "cannot take appended arguments"
}

@test "storefront eslint check: fails hard when the selected script cannot take arguments" {
    FAKE_BODY_NAME="eslint:app"
    FAKE_BODY="a && (cd .. && b)"
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js"]}'
    assert_failure
    assert_output --partial "eslint:app"
    assert_output --partial "cannot take appended arguments"
}

@test "storefront eslint check: refuses to lint a path that does not exist" {
    FAKE_PROBE_OUTPUT="MISSING:src/gone.js"
    run tool_eslint_check '{"paths":["src/gone.js"]}'
    assert_failure
    assert_output --partial "src/gone.js"
    assert_output --partial "do not exist"
}

@test "storefront eslint check: refuses a path that holds no file ESLint reads" {
    FAKE_PROBE_OUTPUT="UNMATCHED:src/scss"
    run tool_eslint_check '{"paths":["src/scss"]}'
    assert_failure
    assert_output --partial "src/scss"
    assert_output --partial "Accepted extensions"
}

@test "storefront eslint check: probes for the extensions ESLint reads" {
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js"]}'
    assert_success
    run cat "${FAKE_PROBE_FILE}"
    assert_output --partial '*.js|*.ts|*.mjs|*.cjs|*.jsx|*.tsx|*.vue|*.json'
    assert_output --partial '-name "*.vue"'
}

@test "storefront eslint check: keeps a path containing a space in one argument" {
    run tool_eslint_check '{"paths":["src/plugin/cart plugin.js"]}'
    assert_success
    assert_output --partial 'npm run eslint:app -- -f stylish "src/plugin/cart plugin.js"'
}

@test "storefront eslint check: refuses a path containing a single quote" {
    run tool_eslint_check "{\"paths\":[\"src/it's.js\"]}"
    assert_failure
    assert_output --partial "single quote"
}

@test "storefront eslint check: refuses an empty string path instead of widening the run" {
    run tool_eslint_check '{"paths":[""]}'
    assert_failure
    refute_output --partial "npm run lint:js"
    assert_output --partial "non-empty strings"
}

@test "storefront eslint check: refuses a paths value that is not an array" {
    run tool_eslint_check '{"paths":"src/plugin/cart.plugin.js"}'
    assert_failure
    refute_output --partial "npm run lint:js"
    assert_output --partial "must be an array of strings"
}

@test "storefront eslint check: refuses a scoped run without paths" {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X","eslint":{"config":"eslint.config.mjs"}}}}
JSON
    run tool_eslint_check '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial "plugin-x"
    assert_output --partial "eslint.config.mjs"
    assert_output --partial "npm run lint:js"
}

# --- Stylelint ---

@test "storefront stylelint check: no paths appends no path target" {
    run tool_stylelint_check '{}'
    assert_success
    assert_output "npm run lint:scss -- -f string"
}

@test "storefront stylelint check: appends format and paths when paths are supplied" {
    run tool_stylelint_check '{"paths":["src/scss/base.scss"]}'
    assert_success
    assert_output 'npm run lint:scss -- -f string "src/scss/base.scss"'
}

@test "storefront stylelint fix: no paths runs lint:scss-fix bare" {
    run tool_stylelint_fix '{}'
    assert_success
    assert_output "npm run lint:scss-fix"
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
    assert_output --partial '--testPathPatterns="CartPlugin"'
}

@test "storefront jest: coverage flag added when coverage=true" {
    run tool_jest_run '{"coverage":true}'
    assert_success
    assert_output --partial "--coverage"
}

@test "storefront jest: keeps a multi-word test name pattern in one argument" {
    run tool_jest_run '{"testNamePattern":"adds to cart"}'
    assert_success
    assert_output --partial '--testNamePattern="adds to cart"'
}

@test "storefront jest: fails hard when the unit script cannot take arguments" {
    FAKE_BODY_NAME="unit"
    FAKE_BODY="npm run unit:ci"
    run tool_jest_run '{"testNamePattern":"adds to cart"}'
    assert_failure
    assert_output --partial "unit"
    assert_output --partial "cannot take appended arguments"
}

@test "storefront jest: runs bare without consulting the append gate" {
    FAKE_ABSENT_SCRIPTS="unit"
    run tool_jest_run '{}'
    assert_success
    assert_output "npm run unit"
}

@test "storefront jest: refuses a test path pattern containing a single quote" {
    run tool_jest_run "{\"testPathPatterns\":\"it's\"}"
    assert_failure
    assert_output --partial "single quote"
}

@test "storefront jest: rejects a views/components test path pattern" {
    run tool_jest_run '{"testPathPatterns":"views/components/checkout"}'
    assert_failure
    assert_output --partial "vitest_run"
}

@test "storefront jest: rejects a components/ test path pattern" {
    run tool_jest_run '{"testPathPatterns":"components/checkout"}'
    assert_failure
    assert_output --partial "vitest_run"
}

# --- Vitest ---

@test "storefront vitest: no arguments runs unit:components bare" {
    run tool_vitest_run '{}'
    assert_success
    assert_output "npm run unit:components"
}

@test "storefront vitest: coverage selects unit:components:coverage" {
    run tool_vitest_run '{"coverage":true}'
    assert_success
    assert_output "npm run unit:components:coverage"
}

@test "storefront vitest: testNamePattern maps to -t" {
    run tool_vitest_run '{"testNamePattern":"renders the cart"}'
    assert_success
    assert_output 'npm run unit:components -- -t "renders the cart"'
}

@test "storefront vitest: updateSnapshots maps to -u" {
    run tool_vitest_run '{"updateSnapshots":true}'
    assert_success
    assert_output "npm run unit:components -- -u"
}

@test "storefront vitest: paths are rebased onto views/components" {
    run tool_vitest_run '{"paths":["src/Storefront/Resources/views/components/checkout/cart.test.js"]}'
    assert_success
    assert_output 'npm run unit:components -- "views/components/checkout/cart.test.js"'
}

@test "storefront vitest: keeps a multi-word test name pattern in one argument" {
    run tool_vitest_run '{"testNamePattern":"adds to cart"}'
    assert_success
    assert_output 'npm run unit:components -- -t "adds to cart"'
}

@test "storefront vitest: refuses a component path that does not exist" {
    FAKE_PROBE_OUTPUT="MISSING:views/components/gone.test.js"
    run tool_vitest_run '{"paths":["views/components/gone.test.js"]}'
    assert_failure
    assert_output --partial "views/components/gone.test.js"
    assert_output --partial "do not exist"
}

# --- ludtwig ---

@test "storefront ludtwig check: runs composer ludtwig:storefront" {
    run tool_ludtwig_check '{}'
    assert_success
    assert_output "composer ludtwig:storefront"
}

@test "storefront ludtwig fix: runs composer ludtwig:storefront:fix" {
    run tool_ludtwig_fix '{}'
    assert_success
    assert_output "composer ludtwig:storefront:fix"
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
