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
        stylelint:app)
            printf '%s\n' '"stylelint --config stylelint.config.js --cache"' ;;
        lint:scss)
            printf '%s\n' '"npm run stylelint:app -- ./src/scss"' ;;
        lint:scss-fix)
            printf '%s\n' '"npm run lint:scss -- --fix"' ;;
        jest:base)
            printf '%s\n' '"jest --config jest.config.js"' ;;
        unit)
            # A package that declares jest:base writes "unit" in terms of it.
            # A package that does not — the pre-refactor layout the fallback
            # route exists for — spells the runner out instead. Keying on
            # FAKE_ABSENT_SCRIPTS keeps both configurations describing a
            # package.json that could actually exist.
            case " ${FAKE_ABSENT_SCRIPTS} " in
                *" jest:base "*) printf '%s\n' '"jest --config jest.config.js --ci"' ;;
                *)               printf '%s\n' '"npm run jest:base -- --ci"' ;;
            esac
            ;;
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

@test "storefront eslint check: refuses a path-scoped app-tree run when eslint:app is absent" {
    FAKE_ABSENT_SCRIPTS="eslint:app"
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js"]}'
    assert_failure
    assert_output --partial "Refusing to lint the app tree with paths"
    assert_output --partial '"eslint:app"'
}

@test "storefront eslint check: refuses a path-scoped components-tree run when eslint:components is absent" {
    FAKE_ABSENT_SCRIPTS="eslint:components"
    run tool_eslint_check '{"paths":["views/components/checkout/cart.js"]}'
    assert_failure
    assert_output --partial "Refusing to lint the components tree with paths"
    assert_output --partial '"eslint:components"'
}

@test "storefront eslint check: never substitutes the lint:js aggregate even when it would accept arguments" {
    FAKE_ABSENT_SCRIPTS="eslint:app"
    FAKE_BODY_NAME="lint:js"
    FAKE_BODY="eslint --no-error-on-unmatched-pattern"
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js"]}'
    assert_failure
    assert_output --partial 'The aggregate "lint:js" script is not a substitute'
    refute_output --partial "npm run"
}

@test "storefront eslint fix: names lint:js:fix as the aggregate it will not substitute" {
    FAKE_ABSENT_SCRIPTS="eslint:app"
    run tool_eslint_fix '{"paths":["src/plugin/cart.plugin.js"]}'
    assert_failure
    assert_output --partial 'The aggregate "lint:js:fix" script is not a substitute'
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

# --- Stylelint: no paths keeps the aggregate script ---

@test "storefront stylelint check: no paths appends no path target" {
    run tool_stylelint_check '{}'
    assert_success
    assert_output "npm run lint:scss -- -f string"
}

@test "storefront stylelint check: no paths leaves the script's own target out of the command" {
    run tool_stylelint_check '{}'
    assert_success
    refute_output --partial "./src/scss"
}

@test "storefront stylelint fix: no paths runs lint:scss-fix bare" {
    run tool_stylelint_fix '{}'
    assert_success
    assert_output "npm run lint:scss-fix"
}

@test "storefront stylelint fix: no paths adds no second --fix on top of the aggregate body" {
    run tool_stylelint_fix '{}'
    assert_success
    refute_output --partial "--fix"
}

# --- Stylelint: paths route at the target-less base script ---

@test "storefront stylelint check: paths route at stylelint:app as the only targets" {
    run tool_stylelint_check '{"paths":["src/scss/base.scss"]}'
    assert_success
    assert_output 'npm run stylelint:app -- -f string "src/scss/base.scss"'
}

@test "storefront stylelint fix: paths route at stylelint:app as the only targets" {
    run tool_stylelint_fix '{"paths":["src/scss/base.scss"]}'
    assert_success
    assert_output 'npm run stylelint:app -- --fix "src/scss/base.scss"'
}

@test "storefront stylelint fix: paths route carries --fix, which the base script body lacks" {
    run tool_stylelint_fix '{"paths":["src/scss/base.scss"]}'
    assert_success
    assert_output --partial "-- --fix "
}

@test "storefront stylelint check: paths route carries no --fix" {
    run tool_stylelint_check '{"paths":["src/scss/base.scss"]}'
    assert_success
    refute_output --partial "--fix"
}

@test "storefront stylelint fix: a path-scoped run never reaches the aggregate fix script" {
    run tool_stylelint_fix '{"paths":["src/scss/base.scss"]}'
    assert_success
    refute_output --partial "lint:scss-fix"
}

@test "storefront stylelint fix: fails when stylelint:app is absent and paths were supplied" {
    FAKE_ABSENT_SCRIPTS="stylelint:app"
    run tool_stylelint_fix '{"paths":["src/scss/base.scss"]}'
    assert_failure
    assert_output --partial "stylelint:app"
}

@test "storefront stylelint fix: refuses rather than falling back to the aggregate fix script" {
    FAKE_ABSENT_SCRIPTS="stylelint:app"
    run tool_stylelint_fix '{"paths":["src/scss/base.scss"]}'
    assert_failure
    refute_output --partial "npm run lint:scss"
}

@test "storefront stylelint check: refuses a path that holds no file Stylelint reads" {
    FAKE_PROBE_OUTPUT="UNMATCHED:src/plugin"
    run tool_stylelint_check '{"paths":["src/plugin"]}'
    assert_failure
    assert_output --partial "Accepted extensions"
}

@test "storefront stylelint check: a glob path skips the existence guard" {
    FAKE_PROBE_OUTPUT="MISSING:src/**/*.scss"
    run tool_stylelint_check '{"paths":["src/**/*.scss"]}'
    assert_success
    assert_output 'npm run stylelint:app -- -f string "src/**/*.scss"'
}

@test "storefront stylelint check: a glob path is quoted so the shell cannot expand it" {
    run tool_stylelint_check '{"paths":["src/**/*.scss"]}'
    assert_success
    assert_output --partial '"src/**/*.scss"'
}

@test "storefront stylelint check: a literal path alongside a glob still passes the guard" {
    FAKE_PROBE_OUTPUT="UNMATCHED:src/plugin"
    run tool_stylelint_check '{"paths":["src/**/*.scss","src/plugin"]}'
    assert_failure
    assert_output --partial "src/plugin"
}

# --- Jest ---

@test "storefront jest: base command routes at jest:base" {
    run tool_jest_run '{}'
    assert_success
    assert_output "npm run jest:base"
}

@test "storefront jest: default run appends no --ci" {
    run tool_jest_run '{}'
    assert_success
    refute_output --partial "--ci"
}

@test "storefront jest: ci=true appends --ci" {
    run tool_jest_run '{"ci":true}'
    assert_success
    assert_output "npm run jest:base -- --ci"
}

@test "storefront jest: testPathPatterns flag added when provided" {
    run tool_jest_run '{"testPathPatterns":"CartPlugin"}'
    assert_success
    assert_output 'npm run jest:base -- --testPathPatterns="CartPlugin"'
}

@test "storefront jest: coverage flag added when coverage=true" {
    run tool_jest_run '{"coverage":true}'
    assert_success
    assert_output --partial "--coverage"
}

@test "storefront jest: keeps a multi-word test name pattern in one argument" {
    run tool_jest_run '{"testNamePattern":"adds to cart"}'
    assert_success
    assert_output 'npm run jest:base -- --testNamePattern="adds to cart"'
}

@test "storefront jest: fails hard when the unit fallback cannot take arguments" {
    FAKE_ABSENT_SCRIPTS="jest:base"
    FAKE_BODY_NAME="unit"
    FAKE_BODY="npm run unit:ci"
    run tool_jest_run '{"testNamePattern":"adds to cart"}'
    assert_failure
    assert_output --partial "cannot take appended arguments"
}

@test "storefront jest: falls back to npm run unit when jest:base is absent" {
    FAKE_ABSENT_SCRIPTS="jest:base"
    run tool_jest_run '{}'
    assert_success
    assert_line --index 1 "npm run unit"
}

@test "storefront jest: the jest:base fallback announces that --ci is forced" {
    FAKE_ABSENT_SCRIPTS="jest:base"
    run tool_jest_run '{}'
    assert_success
    assert_line --index 0 --partial "Notice: the npm script \"jest:base\" is unavailable"
}

@test "storefront jest: the jest:base fallback announces the lost new snapshots" {
    FAKE_ABSENT_SCRIPTS="jest:base"
    run tool_jest_run '{}'
    assert_success
    assert_line --index 0 --partial "writes no new snapshots where it otherwise would have"
}

@test "storefront jest: the jest:base fallback states that updateSnapshots still applies" {
    FAKE_ABSENT_SCRIPTS="jest:base"
    run tool_jest_run '{}'
    assert_success
    assert_line --index 0 --partial "\"updateSnapshots\" itself still takes effect"
}

@test "storefront jest: ci and updateSnapshots together keep --updateSnapshot, which wins over --ci" {
    run tool_jest_run '{"ci":true,"updateSnapshots":true}'
    assert_success
    assert_output "npm run jest:base -- --updateSnapshot --ci"
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
