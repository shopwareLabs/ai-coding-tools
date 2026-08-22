#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,js-admin
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

# Answers the `npm pkg get "scripts.<name>"` probe with the body the Shopware
# Administration package.json declares. Quoted glob arguments are reproduced
# unquoted: the append gate reads command shape, not quoting, and embedded
# double quotes would need escaping through this fake's own JSON-ish string.
# FAKE_ABSENT_SCRIPTS makes a script look undefined; FAKE_BODY_NAME/FAKE_BODY
# makes one report a different body.
_fake_admin_script_body() {
    local name="$1"

    case " ${FAKE_ABSENT_SCRIPTS} " in
        *" ${name} "*) printf '%s\n' '{}'; return ;;
    esac

    if [[ -n "${FAKE_BODY_NAME}" && "${name}" == "${FAKE_BODY_NAME}" ]]; then
        printf '%s\n' "\"${FAKE_BODY}\""
        return
    fi

    case "${name}" in
        lint)
            printf '%s\n' '"eslint src test build.ts --cache"' ;;
        lint:fix)
            printf '%s\n' '"npm run lint -- --fix"' ;;
        lint:debugging)
            printf '%s\n' '"eslint"' ;;
        stylelint:base)
            printf '%s\n' '"stylelint --cache"' ;;
        lint:scss)
            printf '%s\n' '"npm run stylelint:base -- **/*.scss"' ;;
        lint:scss-fix)
            printf '%s\n' '"npm run lint:scss -- --fix"' ;;
        prettier:base)
            printf '%s\n' '"prettier"' ;;
        format)
            printf '%s\n' '"npm run prettier:base -- --check src/**/*.{js,ts} build.ts"' ;;
        format:fix)
            printf '%s\n' '"npm run prettier:base -- --write src/**/*.{js,ts} build.ts --cache"' ;;
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
        *)
            printf '%s\n' '{}' ;;
    esac
}

# Builds a Jest JSON report body carrying the counts a test needs.
# Args: total, passed, failed, suites total, suites failed
_jest_report() {
    printf '{"numTotalTests":%s,"numPassedTests":%s,"numFailedTests":%s,"numPendingTests":0,"numTotalTestSuites":%s,"numFailedTestSuites":%s,"success":true}\n' \
        "$1" "$2" "$3" "$4" "$5"
}

setup() {
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-js-tooling.json"
    echo '{"environment":"native"}' > "${LINT_CONFIG_FILE}"
    JS_CONTEXT="admin"
    FAKE_ABSENT_SCRIPTS=""
    FAKE_BODY_NAME=""
    FAKE_BODY=""
    FAKE_PROBE_OUTPUT=""
    FAKE_PROBE_FILE="${BATS_TEST_TMPDIR}/probe.txt"
    # The report path the jest tool uses is modelled as a real file rather than
    # a canned answer, so a report left behind by an earlier run and a report
    # written by this one are distinguishable: the run writes
    # FAKE_REPORT_OUTPUT into the store (unless FAKE_RUN_WRITES_REPORT is 0),
    # the delete removes it, and the read returns whatever is there.
    FAKE_REPORT_OUTPUT="$(_jest_report 13 13 0 1 0)"
    FAKE_REPORT_STORE="${BATS_TEST_TMPDIR}/jest-report-store.json"
    FAKE_RUN_WRITES_REPORT=1
    # Records the command that read the report, so a test can assert its shape.
    FAKE_REPORT_READ_FILE="${BATS_TEST_TMPDIR}/report-read.txt"
    # Every wrapped command in order, so a test can assert call sequence.
    FAKE_CALL_LOG="${BATS_TEST_TMPDIR}/npm-calls.log"
    FAKE_CLEAR_EXIT=0
    FAKE_CLEAR_OUTPUT=""
    FAKE_RUN_EXIT=0
    log() { :; }
    source "${PLUGIN_DIR}/shared/environment.sh"
    source "${PLUGIN_DIR}/shared/scope.sh"
    exec_npm_command() {
        local cmd="$1"
        printf '%s\n' "${cmd}" >> "${FAKE_CALL_LOG}"
        case "${cmd}" in
            'npm pkg get "scripts.'*)
                local name="${cmd#npm pkg get \"scripts.}"
                _fake_admin_script_body "${name%\"}"
                ;;
            'cd "'*)
                printf '%s\n' "$1" > "${FAKE_PROBE_FILE}"
                printf '%s\n' "${FAKE_PROBE_OUTPUT}"
                ;;
            'rm -f -- '*)
                if [[ "${FAKE_CLEAR_EXIT}" -ne 0 ]]; then
                    printf '%s\n' "${FAKE_CLEAR_OUTPUT}"
                    return "${FAKE_CLEAR_EXIT}"
                fi
                rm -f -- "${FAKE_REPORT_STORE}"
                ;;
            'cat -- '*)
                printf '%s\n' "$1" > "${FAKE_REPORT_READ_FILE}"
                [[ -f "${FAKE_REPORT_STORE}" ]] || return 1
                cat -- "${FAKE_REPORT_STORE}"
                ;;
            *)
                if [[ "${FAKE_RUN_WRITES_REPORT}" == "1" ]]; then
                    printf '%s\n' "${FAKE_REPORT_OUTPUT}" > "${FAKE_REPORT_STORE}"
                fi
                printf '%s\n' "${cmd}"
                return "${FAKE_RUN_EXIT}"
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
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE JS_CONTEXT SCOPE_NAME SCOPE_CWD \
        SCOPE_JS_SUBDIR FAKE_ABSENT_SCRIPTS FAKE_BODY_NAME FAKE_BODY FAKE_PROBE_OUTPUT \
        FAKE_PROBE_FILE FAKE_REPORT_OUTPUT FAKE_REPORT_STORE FAKE_RUN_WRITES_REPORT \
        FAKE_REPORT_READ_FILE FAKE_CALL_LOG FAKE_CLEAR_EXIT FAKE_CLEAR_OUTPUT FAKE_RUN_EXIT
}

# --- ESLint: no paths keeps the aggregate script ---

@test "admin eslint check: no paths uses npm run lint" {
    run tool_eslint_check '{}'
    assert_success
    assert_output "npm run lint -- -f stylish"
}

@test "admin eslint check: json format when specified" {
    run tool_eslint_check '{"output_format":"json"}'
    assert_success
    assert_output --partial "-f json"
}

@test "admin eslint fix: no paths uses npm run lint:fix" {
    run tool_eslint_fix '{}'
    assert_success
    assert_output "npm run lint:fix -- --fix"
}

# --- ESLint: paths route at the target-less base script ---

@test "admin eslint check: paths route at lint:debugging as the only targets" {
    run tool_eslint_check '{"paths":["src/app/component"]}'
    assert_success
    assert_output 'npm run lint:debugging -- -f stylish "src/app/component"'
}

@test "admin eslint check: a path-scoped run carries no hardcoded upstream target" {
    run tool_eslint_check '{"paths":["src/app/component"]}'
    assert_success
    refute_output --partial "src test build.ts"
}

@test "admin eslint fix: paths route at lint:debugging with --fix" {
    run tool_eslint_fix '{"paths":["src/app/component"]}'
    assert_success
    assert_output 'npm run lint:debugging -- --fix "src/app/component"'
}

@test "admin eslint fix: a path-scoped run never reaches the aggregate lint:fix script" {
    run tool_eslint_fix '{"paths":["src/app/component"]}'
    assert_success
    refute_output --partial "npm run lint:fix"
}

@test "admin eslint check: repo-root-relative path is rebased onto the package dir" {
    run tool_eslint_check '{"paths":["src/Administration/Resources/app/administration/src/app/foo.ts"]}'
    assert_success
    assert_output 'npm run lint:debugging -- -f stylish "src/app/foo.ts"'
}

@test "admin eslint check: keeps a path containing a space in one argument" {
    run tool_eslint_check '{"paths":["src/app/my component"]}'
    assert_success
    assert_output 'npm run lint:debugging -- -f stylish "src/app/my component"'
}

# --- ESLint: hard failures instead of widening ---

@test "admin eslint check: fails when lint:debugging is absent and paths were supplied" {
    FAKE_ABSENT_SCRIPTS="lint:debugging"
    run tool_eslint_check '{"paths":["src/app/component"]}'
    assert_failure
    assert_output --partial "lint:debugging"
}

@test "admin eslint check: refuses rather than falling back to the aggregate script" {
    FAKE_ABSENT_SCRIPTS="lint:debugging"
    run tool_eslint_check '{"paths":["src/app/component"]}'
    assert_failure
    refute_output --partial "npm run lint"
}

@test "admin eslint fix: refuses rather than falling back to the aggregate fix script" {
    FAKE_ABSENT_SCRIPTS="lint:debugging"
    run tool_eslint_fix '{"paths":["src/app/component"]}'
    assert_failure
    refute_output --partial "npm run lint"
}

@test "admin eslint check: fails when lint:debugging cannot take appended arguments" {
    FAKE_BODY_NAME="lint:debugging"
    FAKE_BODY="a && (cd .. && eslint)"
    run tool_eslint_check '{"paths":["src/app/component"]}'
    assert_failure
    assert_output --partial "cannot take appended arguments"
}

@test "admin eslint check: refuses a path that holds no file ESLint reads" {
    FAKE_PROBE_OUTPUT="UNMATCHED:src/app/assets"
    run tool_eslint_check '{"paths":["src/app/assets"]}'
    assert_failure
    assert_output --partial "Accepted extensions"
}

@test "admin eslint check: refuses a path that does not exist" {
    FAKE_PROBE_OUTPUT="MISSING:src/gone.ts"
    run tool_eslint_check '{"paths":["src/gone.ts"]}'
    assert_failure
    assert_output --partial "do not exist"
}

@test "admin eslint check: probes for the extensions the Admin config matches" {
    run tool_eslint_check '{"paths":["src/app/component"]}'
    assert_success
    run cat "${FAKE_PROBE_FILE}"
    assert_output --partial '*.js|*.ts|*.tsx|*.vue|*.json|*.twig'
}

@test "admin eslint check: refuses a path containing a single quote" {
    run tool_eslint_check "{\"paths\":[\"src/it's.js\"]}"
    assert_failure
    assert_output --partial "single quote"
}

@test "admin eslint check: refuses an empty string path instead of widening the run" {
    run tool_eslint_check '{"paths":[""]}'
    assert_failure
    refute_output --partial "npm run lint"
    assert_output --partial "non-empty strings"
}

@test "admin eslint check: refuses a paths value that is not an array" {
    run tool_eslint_check '{"paths":"src/app/component"}'
    assert_failure
    refute_output --partial "npm run lint"
    assert_output --partial "must be an array of strings"
}

# --- Stylelint: no paths keeps the aggregate script ---

@test "admin stylelint check: no paths appends no path target" {
    run tool_stylelint_check '{}'
    assert_success
    assert_output "npm run lint:scss -- -f string"
}

@test "admin stylelint check: no paths leaves the script's own glob out of the command" {
    run tool_stylelint_check '{}'
    assert_success
    refute_output --partial "**/*.scss"
}

@test "admin stylelint check: json format when specified" {
    run tool_stylelint_check '{"output_format":"json"}'
    assert_success
    assert_output --partial "-f json"
}

@test "admin stylelint fix: no paths runs lint:scss-fix bare" {
    run tool_stylelint_fix '{}'
    assert_success
    assert_output "npm run lint:scss-fix"
}

@test "admin stylelint fix: no paths adds no second --fix on top of the aggregate body" {
    run tool_stylelint_fix '{}'
    assert_success
    refute_output --partial "--fix"
}

# --- Stylelint: paths route at the target-less base script ---

@test "admin stylelint check: paths route at stylelint:base as the only targets" {
    run tool_stylelint_check '{"paths":["src/app/assets/scss/base.scss"]}'
    assert_success
    assert_output 'npm run stylelint:base -- -f string "src/app/assets/scss/base.scss"'
}

@test "admin stylelint fix: paths route at stylelint:base as the only targets" {
    run tool_stylelint_fix '{"paths":["src/app/assets/scss/base.scss"]}'
    assert_success
    assert_output 'npm run stylelint:base -- --fix "src/app/assets/scss/base.scss"'
}

@test "admin stylelint fix: paths route carries --fix, which the base script body lacks" {
    run tool_stylelint_fix '{"paths":["src/app/assets/scss/base.scss"]}'
    assert_success
    assert_output --partial "-- --fix "
}

@test "admin stylelint check: paths route carries no --fix" {
    run tool_stylelint_check '{"paths":["src/app/assets/scss/base.scss"]}'
    assert_success
    refute_output --partial "--fix"
}

@test "admin stylelint fix: a path-scoped run never reaches the aggregate fix script" {
    run tool_stylelint_fix '{"paths":["src/app/assets/scss/base.scss"]}'
    assert_success
    refute_output --partial "lint:scss-fix"
}

@test "admin stylelint fix: fails when stylelint:base is absent and paths were supplied" {
    FAKE_ABSENT_SCRIPTS="stylelint:base"
    run tool_stylelint_fix '{"paths":["src/app/assets/scss/base.scss"]}'
    assert_failure
    assert_output --partial "stylelint:base"
}

@test "admin stylelint fix: refuses rather than falling back to the aggregate fix script" {
    FAKE_ABSENT_SCRIPTS="stylelint:base"
    run tool_stylelint_fix '{"paths":["src/app/assets/scss/base.scss"]}'
    assert_failure
    refute_output --partial "npm run lint:scss"
}

@test "admin stylelint check: refuses a path that holds no file Stylelint reads" {
    FAKE_PROBE_OUTPUT="UNMATCHED:src/app/component"
    run tool_stylelint_check '{"paths":["src/app/component"]}'
    assert_failure
    assert_output --partial "Accepted extensions"
}

@test "admin stylelint check: a glob path skips the existence guard" {
    FAKE_PROBE_OUTPUT="MISSING:src/**/*.scss"
    run tool_stylelint_check '{"paths":["src/**/*.scss"]}'
    assert_success
    assert_output 'npm run stylelint:base -- -f string "src/**/*.scss"'
}

@test "admin stylelint check: a glob path is quoted so the shell cannot expand it" {
    run tool_stylelint_check '{"paths":["src/**/*.scss"]}'
    assert_success
    assert_output --partial '"src/**/*.scss"'
}

@test "admin stylelint check: a literal path alongside a glob still passes the guard" {
    FAKE_PROBE_OUTPUT="UNMATCHED:src/app/component"
    run tool_stylelint_check '{"paths":["src/**/*.scss","src/app/component"]}'
    assert_failure
    assert_output --partial "src/app/component"
}

# --- Prettier: no paths keeps today's aggregate behavior ---

@test "admin prettier check: no paths uses npm run format" {
    run tool_prettier_check
    assert_success
    assert_output "npm run format"
}

@test "admin prettier fix: no paths uses npm run format:fix" {
    run tool_prettier_fix
    assert_success
    assert_output "npm run format:fix"
}

# --- Prettier: paths route at the target-less base script ---

@test "admin prettier check: paths route at prettier:base with --check" {
    run tool_prettier_check '{"paths":["src/app/main.ts"]}'
    assert_success
    assert_output 'npm run prettier:base -- --check "src/app/main.ts"'
}

@test "admin prettier fix: paths route at prettier:base with --write" {
    run tool_prettier_fix '{"paths":["src/app/main.ts"]}'
    assert_success
    assert_output 'npm run prettier:base -- --write "src/app/main.ts"'
}

@test "admin prettier fix: a path-scoped run never reaches the aggregate format script" {
    run tool_prettier_fix '{"paths":["src/app/main.ts"]}'
    assert_success
    refute_output --partial "npm run format"
}

@test "admin prettier check: fails when prettier:base is absent and paths were supplied" {
    FAKE_ABSENT_SCRIPTS="prettier:base"
    run tool_prettier_check '{"paths":["src/app/main.ts"]}'
    assert_failure
    assert_output --partial "prettier:base"
}

@test "admin prettier check: refuses rather than falling back to the aggregate script" {
    FAKE_ABSENT_SCRIPTS="prettier:base"
    run tool_prettier_check '{"paths":["src/app/main.ts"]}'
    assert_failure
    refute_output --partial "npm run format"
}

@test "admin prettier check: refuses a path that holds no file Prettier reads" {
    FAKE_PROBE_OUTPUT="UNMATCHED:src/app/assets/scss"
    run tool_prettier_check '{"paths":["src/app/assets/scss"]}'
    assert_failure
    assert_output --partial "Accepted extensions"
}

@test "admin prettier check: a glob path skips the existence guard" {
    FAKE_PROBE_OUTPUT="MISSING:src/**/*.ts"
    run tool_prettier_check '{"paths":["src/**/*.ts"]}'
    assert_success
    assert_output 'npm run prettier:base -- --check "src/**/*.ts"'
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

@test "admin jest: base command routes at jest:base and asks for the JSON report" {
    run tool_jest_run '{}'
    assert_success
    assert_line --index 1 "npm run jest:base -- --json --outputFile=\"${ADMIN_JEST_REPORT_FILE}\""
}

@test "admin jest: default run appends no --ci" {
    run tool_jest_run '{}'
    assert_success
    refute_output --partial "--ci"
}

@test "admin jest: ci=true appends --ci and still asks for the JSON report" {
    run tool_jest_run '{"ci":true}'
    assert_success
    assert_line --index 1 "npm run jest:base -- --ci --json --outputFile=\"${ADMIN_JEST_REPORT_FILE}\""
}

@test "admin jest: testPathPatterns flag added when provided" {
    run tool_jest_run '{"testPathPatterns":"CartService"}'
    assert_success
    assert_line --index 1 --partial 'npm run jest:base -- --testPathPatterns="CartService" --json'
}

@test "admin jest: coverage flag added when coverage=true" {
    run tool_jest_run '{"coverage":true}'
    assert_success
    assert_output --partial "--coverage"
}

@test "admin jest: keeps a multi-word test name pattern in one argument" {
    run tool_jest_run '{"testNamePattern":"adds to cart"}'
    assert_success
    assert_line --index 1 --partial 'npm run jest:base -- --testNamePattern="adds to cart" --json'
}

@test "admin jest: refuses a test name pattern containing a single quote" {
    run tool_jest_run "{\"testNamePattern\":\"it's\"}"
    assert_failure
    assert_output --partial "test name pattern"
    assert_output --partial "single quote"
}

@test "admin jest: refuses a test path pattern containing a single quote" {
    run tool_jest_run "{\"testPathPatterns\":\"it's\"}"
    assert_failure
    assert_output --partial "test path pattern"
    assert_output --partial "single quote"
}

@test "admin jest: a single-quote test name pattern reaches no npm command" {
    run tool_jest_run "{\"testNamePattern\":\"x'; printf INJECTED; #\"}"
    assert_failure
    refute_output --partial "npm run"
}

@test "admin jest: falls back to npm run unit when jest:base is absent" {
    FAKE_ABSENT_SCRIPTS="jest:base"
    run tool_jest_run '{}'
    assert_success
    assert_line --index 2 "npm run unit -- --json --outputFile=\"${ADMIN_JEST_REPORT_FILE}\""
}

@test "admin jest: the jest:base fallback announces that --ci is forced" {
    FAKE_ABSENT_SCRIPTS="jest:base"
    run tool_jest_run '{}'
    assert_success
    assert_line --index 0 --partial "Notice: the npm script \"jest:base\" is unavailable"
}

@test "admin jest: the jest:base fallback announces the suppressed summary" {
    FAKE_ABSENT_SCRIPTS="jest:base"
    run tool_jest_run '{}'
    assert_success
    assert_line --index 0 --partial "jest-silent-reporter"
}

# --- Jest: the result comes from the JSON report, not the exit code ---

@test "admin jest: the counts summary precedes the command output" {
    run tool_jest_run '{}'
    assert_success
    assert_line --index 0 "Jest report: 13 tests total, 13 passed, 0 failed, 0 pending; 1 test suites total, 0 failed. Process exit code: 0. The status below is derived from this report."
}

@test "admin jest: the report read is issued as its own command with nothing chained onto it" {
    run tool_jest_run '{}'
    assert_success
    run cat "${FAKE_REPORT_READ_FILE}"
    assert_output "cat -- \"${ADMIN_JEST_REPORT_FILE}\" 2>/dev/null"
}

# --- Jest: a report is this run's report only when the path was cleared first ---

@test "admin jest: the report path is cleared before the jest command is issued" {
    run tool_jest_run '{}'
    assert_success
    run cat "${FAKE_CALL_LOG}"
    assert_line --index 1 "rm -f -- \"${ADMIN_JEST_REPORT_FILE}\""
    assert_line --index 2 "npm run jest:base -- --json --outputFile=\"${ADMIN_JEST_REPORT_FILE}\""
}

@test "admin jest: a run that writes no report fails instead of reusing the report left by the previous run" {
    _jest_report 13 13 0 1 0 > "${FAKE_REPORT_STORE}"
    FAKE_RUN_WRITES_REPORT=0
    FAKE_RUN_EXIT=1
    run tool_jest_run '{}'
    assert_failure 1
    refute_output --partial "13 tests total"
}

@test "admin jest: refuses to run when the report path cannot be cleared" {
    FAKE_CLEAR_EXIT=1
    FAKE_CLEAR_OUTPUT="rm: /tmp/report.json: Permission denied"
    run tool_jest_run '{}'
    assert_failure 1
    assert_output --partial "could not be cleared before the run"
}

@test "admin jest: issues no jest command when the report path cannot be cleared" {
    FAKE_CLEAR_EXIT=1
    FAKE_CLEAR_OUTPUT="rm: /tmp/report.json: Permission denied"
    run tool_jest_run '{}'
    assert_failure 1
    run cat "${FAKE_CALL_LOG}"
    refute_output --partial "npm run jest:base --"
}

@test "admin jest: failed tests in the report fail the tool even when the process exited 0" {
    FAKE_REPORT_OUTPUT="$(_jest_report 127 123 4 12 1)"
    FAKE_RUN_EXIT=0
    run tool_jest_run '{}'
    assert_failure
    assert_line --index 0 --partial "127 tests total, 123 passed, 4 failed"
}

@test "admin jest: a failed test suite fails the tool when no individual test failed" {
    FAKE_REPORT_OUTPUT="$(_jest_report 13 13 0 2 1)"
    FAKE_RUN_EXIT=0
    run tool_jest_run '{}'
    assert_failure
    assert_line --index 0 --partial "2 test suites total, 1 failed"
}

@test "admin jest: a report of zero tests fails the tool" {
    FAKE_REPORT_OUTPUT="$(_jest_report 0 0 0 0 0)"
    FAKE_RUN_EXIT=0
    run tool_jest_run '{}'
    assert_failure
    assert_output --partial "No test matched, so the run executed nothing."
}

@test "admin jest: the zero-test failure names the patterns that were in effect" {
    FAKE_REPORT_OUTPUT="$(_jest_report 0 0 0 0 0)"
    run tool_jest_run '{"testPathPatterns":"CartServcie","testNamePattern":"adds to cart"}'
    assert_failure
    assert_output --partial "testPathPatterns: CartServcie. testNamePattern: adds to cart."
}

@test "admin jest: the zero-test failure names both patterns as absent when neither was given" {
    FAKE_REPORT_OUTPUT="$(_jest_report 0 0 0 0 0)"
    run tool_jest_run '{}'
    assert_failure
    assert_output --partial "testPathPatterns: (none). testNamePattern: (none)."
}

@test "admin jest: all tests passed with a non-zero process exit still succeeds" {
    FAKE_RUN_EXIT=7
    run tool_jest_run '{}'
    assert_success
}

@test "admin jest: all tests passed with a non-zero process exit reports that exit code" {
    FAKE_RUN_EXIT=7
    run tool_jest_run '{}'
    assert_line --index 1 --partial "every test passed, but the jest process still exited with code 7"
}

@test "admin jest: all tests passed with a non-zero process exit keeps the command output" {
    FAKE_RUN_EXIT=7
    run tool_jest_run '{}'
    assert_line --index 2 --partial "npm run jest:base"
}

@test "admin jest: a report that is not JSON propagates the process exit code" {
    FAKE_REPORT_OUTPUT="Cannot open file /tmp/nope.json"
    FAKE_RUN_EXIT=3
    run tool_jest_run '{}'
    assert_failure 3
    assert_line --index 0 --partial "could not be read or parsed, so the status below is the process exit code (3)"
}

@test "admin jest: a JSON report without the count fields propagates the process exit code" {
    FAKE_REPORT_OUTPUT='{"someOtherField":true}'
    FAKE_RUN_EXIT=3
    run tool_jest_run '{}'
    assert_failure 3
    assert_line --index 0 --partial "could not be read or parsed, so the status below is the process exit code (3)"
}

@test "admin jest: an unreadable report announces the exit-code fallback rather than a report-derived status" {
    FAKE_REPORT_OUTPUT=""
    run tool_jest_run '{}'
    assert_success
    assert_line --index 0 --partial "could not be read or parsed, so the status below is the process exit code (0)"
    refute_output --partial "Jest report:"
}

@test "admin jest: the config banner ahead of the JSON is stripped rather than breaking the parse" {
    FAKE_REPORT_OUTPUT="Run Jest in local mode
$(_jest_report 13 13 0 1 0)"
    run tool_jest_run '{}'
    assert_success
    assert_line --index 0 --partial "13 tests total, 13 passed, 0 failed"
}

# --- Vite build ---

@test "admin vite build: production mode by default" {
    run tool_vite_build '{}'
    assert_success
    assert_output --partial "npm run build -- --mode production"
}
