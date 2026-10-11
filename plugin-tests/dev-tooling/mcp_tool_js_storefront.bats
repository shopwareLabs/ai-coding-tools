#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,js-storefront
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

# Answers the `npm pkg get "scripts.<name>"` probe from the Shopware trunk
# Storefront package.json (fixtures/shopware-trunk). FAKE_ABSENT_SCRIPTS makes
# a script look undefined; FAKE_BODY_NAME/FAKE_BODY makes one report a
# different body.
#
# "jest:base" is the one script answered that trunk does not define: the jest
# tool routes at it when a package declares it, and these tests model such a
# package. FAKE_ABSENT_SCRIPTS="jest:base" restores the trunk layout, where the
# tool falls back to "unit".
_fake_script_body() {
    local name="$1"

    case " ${FAKE_ABSENT_SCRIPTS} " in
        *" ${name} "*) printf '%s\n' '{}'; return ;;
    esac

    if [[ -n "${FAKE_BODY_NAME}" && "${name}" == "${FAKE_BODY_NAME}" ]]; then
        printf '%s\n' "\"${FAKE_BODY}\""
        return
    fi

    if [[ "${name}" == "jest:base" ]]; then
        printf '%s\n' '"jest --config jest.config.js"'
        return
    fi

    shopware_trunk_script_body storefront "${name}"
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
    JS_CONTEXT="storefront"
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
    # Binaries the package's node_modules/.bin lacks, as the local-binary
    # probe of a path-scoped run sees it.
    FAKE_MISSING_BINARIES=""
    # Output of a binary probe that fails before it can test anything, such as
    # a stopped container.
    FAKE_BINARY_PROBE_ERROR=""
    # Output of a directory test that fails before it can test anything.
    FAKE_DIRECTORY_PROBE_ERROR=""
    log() { :; }
    source "${PLUGIN_DIR}/shared/environment.sh"
    source "${PLUGIN_DIR}/shared/scope.sh"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    export PROJECT_ROOT
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/shared/worktree.sh"
    worktree_state_init
    exec_npm_command() {
        local cmd="$1"
        printf '%s\n' "${cmd}" >> "${FAKE_CALL_LOG}"
        case "${cmd}" in
            'npm pkg get "scripts.'*)
                local name="${cmd#npm pkg get \"scripts.}"
                _fake_script_body "${name%\"}"
                ;;
            'npm exec --no -c "[ -d '*)
                # The directory test runs for real, as sh in the package
                # directory, so it answers about the files a test created.
                if [[ -n "${FAKE_DIRECTORY_PROBE_ERROR}" ]]; then
                    printf '%s\n' "${FAKE_DIRECTORY_PROBE_ERROR}"
                    return 1
                fi
                # LINT_WORKDIR is empty here: environment.sh resets it when
                # sourced, and setup() sets it before that.
                (LINT_WORKDIR="${BATS_TEST_TMPDIR}"; cd "$(get_js_workdir)" 2>/dev/null || true; eval "sh -c ${cmd#npm exec --no -c }")
                ;;
            'npm exec --no -c "test -x node_modules/.bin/'*)
                if [[ -n "${FAKE_BINARY_PROBE_ERROR}" ]]; then
                    printf '%s\n' "${FAKE_BINARY_PROBE_ERROR}"
                    return 1
                fi
                local binary="${cmd#npm exec --no -c \"test -x node_modules/.bin/}"
                case " ${FAKE_MISSING_BINARIES} " in
                    *" ${binary%% *} "*)
                        # The directory as the environment reports it, which
                        # under a container is not a host path.
                        printf '%s\n%s\n' "LOCAL_BINARY_MISSING_IN" "/var/www/html/src/Storefront/Resources/app/storefront"
                        return 3
                        ;;
                esac
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
                # npm refuses a script the package does not define before it
                # runs anything, so a route naming one fails as it would on a
                # real checkout.
                if [[ "${cmd}" == "npm run "* ]]; then
                    local script="${cmd#npm run }"
                    script="${script%% *}"
                    if [[ "$(_fake_script_body "${script}")" == "{}" ]]; then
                        printf '%s\n' "npm error Missing script: \"${script}\""
                        return 1
                    fi
                fi
                if [[ "${FAKE_RUN_WRITES_REPORT}" == "1" ]]; then
                    printf '%s\n' "${FAKE_REPORT_OUTPUT}" > "${FAKE_REPORT_STORE}"
                fi
                printf '%s\n' "${cmd}"
                return "${FAKE_RUN_EXIT}"
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
    worktree_state_cleanup
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE JS_CONTEXT SCOPE_NAME SCOPE_CWD \
        SCOPE_JS_SUBDIR FAKE_ABSENT_SCRIPTS FAKE_BODY_NAME FAKE_BODY FAKE_PROBE_OUTPUT \
        FAKE_PROBE_FILE FAKE_REPORT_OUTPUT FAKE_REPORT_STORE FAKE_RUN_WRITES_REPORT \
        FAKE_REPORT_READ_FILE FAKE_CALL_LOG FAKE_CLEAR_EXIT FAKE_CLEAR_OUTPUT FAKE_RUN_EXIT \
        FAKE_MISSING_BINARIES FAKE_BINARY_PROBE_ERROR FAKE_DIRECTORY_PROBE_ERROR PROJECT_ROOT DEV_TOOLING_STATE_FILE
}

# --- ESLint: no paths runs the aggregate script bare ---

@test "storefront eslint check: no paths runs lint:js bare" {
    run tool_eslint_check '{}'
    assert_success
    assert_line "npm run lint:js"
}

@test "storefront eslint fix: no paths runs lint:js:fix bare" {
    run tool_eslint_fix '{}'
    assert_success
    assert_line "npm run lint:js:fix"
}

# --- ESLint: paths run the package's own binary, one call per tree ---

@test "storefront eslint check: app-tree path runs the local eslint rebased to the package dir" {
    run tool_eslint_check '{"paths":["src/Storefront/Resources/app/storefront/src/plugin/cart.plugin.js"]}'
    assert_success
    assert_line 'npm exec --no -- eslint --no-error-on-unmatched-pattern --report-unused-disable-directives -f stylish "src/plugin/cart.plugin.js"'
}

@test "storefront eslint fix: app-tree path runs the local eslint with --fix" {
    run tool_eslint_fix '{"paths":["src/plugin/cart.plugin.js"]}'
    assert_success
    assert_line 'npm exec --no -- eslint --no-error-on-unmatched-pattern --report-unused-disable-directives --fix "src/plugin/cart.plugin.js"'
}

@test "storefront eslint check: tree-relative app path is passed through unchanged" {
    run tool_eslint_check '{"paths":["build/webpack/config.js"]}'
    assert_success
    assert_output --partial '-f stylish "build/webpack/config.js"'
}

@test "storefront eslint check: components path runs from ../.. with the components config" {
    run tool_eslint_check '{"paths":["src/Storefront/Resources/views/components/checkout/cart.js"]}'
    assert_success
    assert_line 'npm exec --no -c "cd ../.. && eslint --no-error-on-unmatched-pattern --report-unused-disable-directives --config ./app/storefront/eslint.config.js -f stylish \"views/components/checkout/cart.js\""'
}

@test "storefront eslint fix: components path runs from ../.. with --fix" {
    run tool_eslint_fix '{"paths":["views/components/checkout/cart.js"]}'
    assert_success
    assert_line 'npm exec --no -c "cd ../.. && eslint --no-error-on-unmatched-pattern --report-unused-disable-directives --config ./app/storefront/eslint.config.js --fix \"views/components/checkout/cart.js\""'
}

@test "storefront eslint check: tree-relative components path keeps its views/components prefix" {
    run tool_eslint_check '{"paths":["views/components/checkout/cart.js"]}'
    assert_success
    assert_output --partial '-f stylish \"views/components/checkout/cart.js\""'
}

@test "storefront eslint check: mixed paths run each tree on its own paths only" {
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js","views/components/checkout/cart.js"]}'
    assert_success
    assert_line 'npm exec --no -- eslint --no-error-on-unmatched-pattern --report-unused-disable-directives -f stylish "src/plugin/cart.plugin.js"'
    assert_line 'npm exec --no -c "cd ../.. && eslint --no-error-on-unmatched-pattern --report-unused-disable-directives --config ./app/storefront/eslint.config.js -f stylish \"views/components/checkout/cart.js\""'
}

@test "storefront eslint check: paths route carries no --fix" {
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js","views/components/checkout/cart.js"]}'
    assert_success
    refute_output --partial "--fix"
}

@test "storefront eslint check: json format applied when paths are supplied" {
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js"],"output_format":"json"}'
    assert_success
    assert_output --partial "-f json"
}

_set_eslint_scope() {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X","eslint":{"config":"eslint.config.mjs"}}}}
JSON
}

@test "storefront eslint check: an app path under a scope runs with the scope config" {
    _set_eslint_scope
    run tool_eslint_check '{"scope":"plugin-x","paths":["src/main.js"]}'
    assert_success
    assert_line 'npm exec --no -- eslint --no-error-on-unmatched-pattern --report-unused-disable-directives -f stylish --config eslint.config.mjs "src/main.js"'
}

@test "storefront eslint check: a components path under a scope refuses" {
    _set_eslint_scope
    run tool_eslint_check '{"scope":"plugin-x","paths":["views/components/checkout/cart.js"]}'
    assert_failure
    assert_output --partial 'scope "plugin-x" runs in "custom/plugins/X", but these paths route to the core Storefront components tree'
}

@test "storefront eslint fix: a refused components path under a scope runs nothing" {
    _set_eslint_scope
    run tool_eslint_fix '{"scope":"plugin-x","paths":["src/main.js","views/components/checkout/cart.js"]}'
    assert_failure
    run cat "${FAKE_CALL_LOG}"
    refute_output --partial "npm exec"
}

@test "storefront eslint check: refuses with paths when the package has no local eslint" {
    FAKE_MISSING_BINARIES="eslint"
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js"]}'
    assert_failure
    assert_output --partial "\"node_modules/.bin/eslint\" is not installed in the package directory \"/var/www/html/src/Storefront/Resources/app/storefront\""
}

@test "storefront eslint fix: runs neither eslint nor the aggregate when the local eslint is missing" {
    FAKE_MISSING_BINARIES="eslint"
    run tool_eslint_fix '{"paths":["src/plugin/cart.plugin.js","views/components/checkout/cart.js"]}'
    assert_failure
    run cat "${FAKE_CALL_LOG}"
    refute_output --partial "eslint --no-error-on-unmatched-pattern"
    refute_output --partial "npm run"
}

@test "storefront eslint check: a probe that fails before testing is not reported as a missing binary" {
    FAKE_BINARY_PROBE_ERROR='Error response from daemon: container shopware-web-1 is not running'
    run tool_eslint_check '{"paths":["src/plugin/cart.plugin.js"]}'
    assert_failure
    assert_output --partial "could not check whether the package's own eslint binary is installed; the probe exited with 1. Probe output: Error response from daemon"
    refute_output --partial "is not installed"
}

@test "storefront eslint fix: names lint:js:fix as the aggregate it will not substitute" {
    FAKE_MISSING_BINARIES="eslint"
    run tool_eslint_fix '{"paths":["src/plugin/cart.plugin.js"]}'
    assert_failure
    assert_output --partial 'the aggregate "lint:js:fix" script is not a substitute'
}

# --- ESLint: the built commands executed through each environment wrapper ---

# The command a components-tree check builds for one path holding a space.
_components_check_command() {
    tool_eslint_check '{"paths":["views/components/my dir/cart.js"]}' > /dev/null
    grep '^npm exec --no -c "cd ../.. ' "${FAKE_CALL_LOG}"
}

_assert_components_run_from_resources() {
    assert_success
    assert_output "cwd=${BATS_TEST_TMPDIR}/src/Storefront/Resources
[--no-error-on-unmatched-pattern]
[--report-unused-disable-directives]
[--config]
[./app/storefront/eslint.config.js]
[-f]
[stylish]
[views/components/my dir/cart.js]"
}

@test "storefront eslint components command: runs from ../.. with its paths intact under native" {
    run js_execute_in_env native "$(_components_check_command)"
    _assert_components_run_from_resources
}

@test "storefront eslint components command: runs from ../.. with its paths intact under docker" {
    run js_execute_in_env docker "$(_components_check_command)"
    _assert_components_run_from_resources
}

@test "storefront eslint components command: runs from ../.. with its paths intact under docker-compose" {
    run js_execute_in_env docker-compose "$(_components_check_command)"
    _assert_components_run_from_resources
}

@test "storefront eslint components command: runs from ../.. with its paths intact under vagrant" {
    run js_execute_in_env vagrant "$(_components_check_command)"
    _assert_components_run_from_resources
}

@test "storefront eslint components command: runs from ../.. with its paths intact under ddev" {
    run js_execute_in_env ddev "$(_components_check_command)"
    _assert_components_run_from_resources
}

@test "storefront eslint components command: runs from ../.. with its paths intact under ddev on a worktree" {
    run js_execute_in_env ddev-worktree "$(_components_check_command)"
    _assert_components_run_from_resources
}

# --- Stylelint: the built commands executed through each environment wrapper ---

_stylelint_probe_command() {
    tool_stylelint_check '{"paths":["src/scss/base.scss"]}' > /dev/null
    grep '^npm exec --no -c "test -x node_modules/.bin/stylelint ' "${FAKE_CALL_LOG}"
}

_stylelint_check_command() {
    tool_stylelint_check '{"paths":["src/scss/my dir/base.scss"]}' > /dev/null
    grep '^npm exec --no -- stylelint ' "${FAKE_CALL_LOG}"
}

# The package installs no stylelint, so the probe misses.
_assert_probe_reports_missing_stylelint() {
    JS_FAKE_BINARIES="eslint"
    run js_execute_in_env "$1" "$(_stylelint_probe_command)"
    assert_failure 3
    assert_output "LOCAL_BINARY_MISSING_IN
${BATS_TEST_TMPDIR}/src/Storefront/Resources/app/storefront"
}

_assert_stylelint_check_runs_in_package_dir() {
    run js_execute_in_env "$1" "$(_stylelint_check_command)"
    assert_success
    assert_output "cwd=${BATS_TEST_TMPDIR}/src/Storefront/Resources/app/storefront
[--config]
[stylelint.config.js]
[--cache]
[-f]
[string]
[src/scss/my dir/base.scss]"
}

@test "storefront local-binary probe: reports the missing stylelint and its directory under native" {
    _assert_probe_reports_missing_stylelint native
}

@test "storefront local-binary probe: reports the missing stylelint and its directory under docker" {
    _assert_probe_reports_missing_stylelint docker
}

@test "storefront local-binary probe: reports the missing stylelint and its directory under docker-compose" {
    _assert_probe_reports_missing_stylelint docker-compose
}

@test "storefront local-binary probe: reports the missing stylelint and its directory under vagrant" {
    _assert_probe_reports_missing_stylelint vagrant
}

@test "storefront local-binary probe: reports the missing stylelint and its directory under ddev" {
    _assert_probe_reports_missing_stylelint ddev
}

@test "storefront local-binary probe: reports the missing stylelint and its directory under ddev on a worktree" {
    _assert_probe_reports_missing_stylelint ddev-worktree
}

@test "storefront stylelint command: runs in the package dir with its paths intact under native" {
    _assert_stylelint_check_runs_in_package_dir native
}

@test "storefront stylelint command: runs in the package dir with its paths intact under docker" {
    _assert_stylelint_check_runs_in_package_dir docker
}

@test "storefront stylelint command: runs in the package dir with its paths intact under docker-compose" {
    _assert_stylelint_check_runs_in_package_dir docker-compose
}

@test "storefront stylelint command: runs in the package dir with its paths intact under vagrant" {
    _assert_stylelint_check_runs_in_package_dir vagrant
}

@test "storefront stylelint command: runs in the package dir with its paths intact under ddev" {
    _assert_stylelint_check_runs_in_package_dir ddev
}

@test "storefront stylelint command: runs in the package dir with its paths intact under ddev on a worktree" {
    _assert_stylelint_check_runs_in_package_dir ddev-worktree
}

@test "storefront stylelint check: a directory reaches Stylelint as its .scss and .css files only" {
    local dir="${BATS_TEST_TMPDIR}/src/Storefront/Resources/app/storefront/src/sty"
    mkdir -p "${dir}/nested"
    touch "${dir}/a.scss" "${dir}/nested/b.css" "${dir}/e.js" "${dir}/f.json" "${dir}/g.twig" "${dir}/h.md" "${dir}/notes.txt"
    tool_stylelint_check '{"paths":["src/sty/"]}' > /dev/null
    run js_execute_in_env native "$(grep '^npm exec --no -- stylelint ' "${FAKE_CALL_LOG}")"
    assert_success
    assert_line '[src/sty/**/*.{scss,css}]'
    run grep '^match:' <<< "${output}"
    assert_output "match:src/sty/a.scss
match:src/sty/nested/b.css"
}

@test "storefront eslint app command: runs in the package dir with its paths intact under ddev on a worktree" {
    tool_eslint_check '{"paths":["src/my plugin/cart.plugin.js"]}' > /dev/null
    run js_execute_in_env ddev-worktree "$(grep '^npm exec --no -- eslint ' "${FAKE_CALL_LOG}")"
    assert_success
    assert_output "cwd=${BATS_TEST_TMPDIR}/src/Storefront/Resources/app/storefront
[--no-error-on-unmatched-pattern]
[--report-unused-disable-directives]
[-f]
[stylish]
[src/my plugin/cart.plugin.js]"
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
    assert_output --partial '-f stylish "src/plugin/cart plugin.js"'
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
    assert_line "npm run lint:scss -- -f string"
}

@test "storefront stylelint check: no paths leaves the script's own target out of the command" {
    run tool_stylelint_check '{}'
    assert_success
    refute_output --partial "./src/scss"
}

@test "storefront stylelint fix: no paths runs lint:scss-fix bare" {
    run tool_stylelint_fix '{}'
    assert_success
    assert_line "npm run lint:scss-fix"
}

@test "storefront stylelint fix: no paths adds no second --fix on top of the aggregate body" {
    run tool_stylelint_fix '{}'
    assert_success
    refute_output --partial "--fix"
}

# Trunk's "lint:scss" passes --config stylelint.config.js, and "lint:scss-fix"
# reaches it through `npm run lint:scss`. Stylelint exits with "The flag
# --config can only be set once." on a second --config, so appending a scope
# config to either cannot run.
_set_stylelint_scope() {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X","stylelint":{"config":".stylelintrc.plugin"}}}}
JSON
}

@test "storefront stylelint check: a scoped config without paths refuses when lint:scss passes its own config" {
    _set_stylelint_scope
    run tool_stylelint_check '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial "\"npm run lint:scss\" already passes a config of its own"
}

@test "storefront stylelint fix: a scoped config without paths refuses when lint:scss-fix reaches a script passing its own config" {
    _set_stylelint_scope
    run tool_stylelint_fix '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial "\"npm run lint:scss-fix\" already passes a config of its own"
}

@test "storefront stylelint fix: the refused scoped run executes no aggregate script" {
    _set_stylelint_scope
    run tool_stylelint_fix '{"scope":"plugin-x"}'
    assert_failure
    run cat "${FAKE_CALL_LOG}"
    refute_output --partial "npm run lint:scss"
}

# --- Stylelint: paths run the package's own binary as the only targets ---

@test "storefront stylelint check: paths run the local stylelint with the lint:scss flags" {
    run tool_stylelint_check '{"paths":["src/scss/base.scss"]}'
    assert_success
    assert_line 'npm exec --no -- stylelint --config stylelint.config.js --cache -f string "src/scss/base.scss"'
}

@test "storefront stylelint fix: paths run the local stylelint with --fix" {
    run tool_stylelint_fix '{"paths":["src/scss/base.scss"]}'
    assert_success
    assert_line 'npm exec --no -- stylelint --config stylelint.config.js --cache --fix "src/scss/base.scss"'
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

# Stylelint exits with "The flag --config can only be set once." on a second
# --config, so the scoped one has to replace the package's rather than follow it.
@test "storefront stylelint fix: a scoped config replaces stylelint.config.js" {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X","stylelint":{"config":".stylelintrc.plugin"}}}}
JSON
    run tool_stylelint_fix '{"scope":"plugin-x","paths":["src/scss/base.scss"]}'
    assert_success
    assert_line 'npm exec --no -- stylelint --cache --config .stylelintrc.plugin --fix "src/scss/base.scss"'
}

@test "storefront stylelint fix: a directory path is refused under ddev on a worktree" {
    LINT_ENV="ddev"
    _env_targets_worktree() { return 0; }
    run tool_stylelint_fix '{"paths":["src/scss/"]}'
    assert_failure
    assert_output --partial "under ddev on a worktree these paths would reach Stylelint as glob patterns"
}

@test "storefront stylelint check: a directory named like a .css file reaches Stylelint as its .scss and .css files" {
    mkdir -p "${BATS_TEST_TMPDIR}/src/Storefront/Resources/app/storefront/src/legacy.css"
    run tool_stylelint_check '{"paths":["src/legacy.css"]}'
    assert_success
    assert_line 'npm exec --no -- stylelint --config stylelint.config.js --cache -f string "src/legacy.css/**/*.{scss,css}"'
}

_set_stylelint_scope_with_body() {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X","stylelint":{"config":".stylelintrc.plugin"}}}}
JSON
    FAKE_BODY_NAME="lint:scss"
    FAKE_BODY="$1"
}

@test "storefront stylelint check: a scoped config without paths refuses when lint:scss passes -c=" {
    _set_stylelint_scope_with_body "stylelint -c=stylelint.config.js ./src/scss"
    run tool_stylelint_check '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial "\"npm run lint:scss\" already passes a config of its own"
}

# The -c belongs to eslint, the command before the stylelint one.
@test "storefront stylelint check: a scoped config without paths is appended when only another program in lint:scss takes -c" {
    _set_stylelint_scope_with_body "eslint -c eslint.config.js ./src && stylelint ./src/scss"
    run tool_stylelint_check '{"scope":"plugin-x"}'
    assert_success
    assert_line "npm run lint:scss -- -f string --config .stylelintrc.plugin"
}

@test "storefront stylelint check: a scope without a Stylelint config names no --config" {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X"}}}
JSON
    run tool_stylelint_check '{"scope":"plugin-x","paths":["src/scss/base.scss"]}'
    assert_success
    assert_line 'npm exec --no -- stylelint --cache -f string "src/scss/base.scss"'
}

@test "storefront stylelint fix: refuses with paths when the package has no local stylelint" {
    FAKE_MISSING_BINARIES="stylelint"
    run tool_stylelint_fix '{"paths":["src/scss/base.scss"]}'
    assert_failure
    assert_output --partial "\"node_modules/.bin/stylelint\" is not installed in the package directory \"/var/www/html/src/Storefront/Resources/app/storefront\""
}

@test "storefront stylelint fix: runs neither stylelint nor the aggregate when the local stylelint is missing" {
    FAKE_MISSING_BINARIES="stylelint"
    run tool_stylelint_fix '{"paths":["src/scss/base.scss"]}'
    assert_failure
    run cat "${FAKE_CALL_LOG}"
    refute_output --partial "-- stylelint"
    refute_output --partial "npm run"
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
    assert_line 'npm exec --no -- stylelint --config stylelint.config.js --cache -f string "src/**/*.scss"'
}

@test "storefront stylelint check: a literal path alongside a glob still passes the guard" {
    FAKE_PROBE_OUTPUT="UNMATCHED:src/plugin"
    run tool_stylelint_check '{"paths":["src/**/*.scss","src/plugin"]}'
    assert_failure
    assert_output --partial "src/plugin"
}

# --- Every tool with a paths parameter, against the trunk package.json ---

# A path-scoped route that names an npm script Shopware does not define refuses
# every call on a real checkout. The tool list comes from tools.json, so a tool
# that gains a paths parameter is covered without an edit here.
@test "storefront tools: no path-scoped call names an npm script the trunk package.json lacks" {
    local -a tools=()
    local tool
    while IFS= read -r tool; do
        tools+=("${tool}")
    done < <(jq -r '.tools[] | select(.inputSchema.properties.paths) | .name' \
        "${PLUGIN_DIR}/mcp-server-js-storefront/tools.json")

    local refused=""
    for tool in "${tools[@]}"; do
        if ! "tool_${tool}" '{"paths":["views/components/checkout/cart.js"]}' > "${BATS_TEST_TMPDIR}/out.txt" 2>&1 \
            || grep -q -e "is not defined in package.json" -e "Missing script" "${BATS_TEST_TMPDIR}/out.txt"; then
            refused="${refused} ${tool}: $(cat "${BATS_TEST_TMPDIR}/out.txt")"
        fi
    done

    assert [ "${#tools[@]}" -ge 5 ]
    assert_equal "${refused}" ""
}

# --- Jest ---

@test "storefront jest: base command routes at jest:base and asks for the JSON report" {
    run tool_jest_run '{}'
    assert_success
    assert_line --index 2 "npm run jest:base -- --json --outputFile=\"${STOREFRONT_JEST_REPORT_FILE}\""
}

@test "storefront jest: default run appends no --ci" {
    run tool_jest_run '{}'
    assert_success
    refute_output --partial "--ci"
}

@test "storefront jest: ci=true appends --ci and still asks for the JSON report" {
    run tool_jest_run '{"ci":true}'
    assert_success
    assert_line --index 2 "npm run jest:base -- --ci --json --outputFile=\"${STOREFRONT_JEST_REPORT_FILE}\""
}

@test "storefront jest: testPathPatterns flag added when provided" {
    run tool_jest_run '{"testPathPatterns":"CartPlugin"}'
    assert_success
    assert_line --index 2 --partial 'npm run jest:base -- --testPathPatterns="CartPlugin" --json'
}

@test "storefront jest: coverage flag added when coverage=true" {
    run tool_jest_run '{"coverage":true}'
    assert_success
    assert_output --partial "--coverage"
}

@test "storefront jest: keeps a multi-word test name pattern in one argument" {
    run tool_jest_run '{"testNamePattern":"adds to cart"}'
    assert_success
    assert_line --index 2 --partial 'npm run jest:base -- --testNamePattern="adds to cart" --json'
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
    assert_line --index 3 "npm run unit -- --json --outputFile=\"${STOREFRONT_JEST_REPORT_FILE}\""
}

@test "storefront jest: the jest:base fallback announces that --ci is forced" {
    FAKE_ABSENT_SCRIPTS="jest:base"
    run tool_jest_run '{}'
    assert_success
    assert_line --partial "Notice: the npm script \"jest:base\" is unavailable"
}

@test "storefront jest: the jest:base fallback announces the lost new snapshots" {
    FAKE_ABSENT_SCRIPTS="jest:base"
    run tool_jest_run '{}'
    assert_success
    assert_line --partial "writes no new snapshots where it otherwise would have"
}

@test "storefront jest: the jest:base fallback states that updateSnapshots still applies" {
    FAKE_ABSENT_SCRIPTS="jest:base"
    run tool_jest_run '{}'
    assert_success
    assert_line --partial "\"updateSnapshots\" itself still takes effect"
}

@test "storefront jest: ci and updateSnapshots together keep --updateSnapshot, which wins over --ci" {
    run tool_jest_run '{"ci":true,"updateSnapshots":true}'
    assert_success
    assert_line --index 2 --partial "--updateSnapshot"
    assert_line --index 2 --partial "--ci"
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

# --- Jest: the result comes from the JSON report, not the exit code ---

@test "storefront jest: the counts summary precedes the command output" {
    run tool_jest_run '{}'
    assert_success
    assert_line --index 1 "Jest report: 13 tests total, 13 passed, 0 failed, 0 pending; 1 test suites total, 0 failed. Process exit code: 0. The status below is derived from this report."
}

@test "storefront jest: the report read is issued as its own command with nothing chained onto it" {
    run tool_jest_run '{}'
    assert_success
    run cat "${FAKE_REPORT_READ_FILE}"
    assert_output "cat -- \"${STOREFRONT_JEST_REPORT_FILE}\" 2>/dev/null"
}

# --- Jest: a report is this run's report only when the path was cleared first ---

@test "storefront jest: the report path is cleared before the jest command is issued" {
    run tool_jest_run '{}'
    assert_success
    run cat "${FAKE_CALL_LOG}"
    assert_line --index 1 "rm -f -- \"${STOREFRONT_JEST_REPORT_FILE}\""
    assert_line --index 2 "npm run jest:base -- --json --outputFile=\"${STOREFRONT_JEST_REPORT_FILE}\""
}

@test "storefront jest: a run that writes no report fails instead of reusing the report left by the previous run" {
    _jest_report 13 13 0 1 0 > "${FAKE_REPORT_STORE}"
    FAKE_RUN_WRITES_REPORT=0
    FAKE_RUN_EXIT=1
    run tool_jest_run '{}'
    assert_failure 1
    refute_output --partial "13 tests total"
}

@test "storefront jest: refuses to run when the report path cannot be cleared" {
    FAKE_CLEAR_EXIT=1
    FAKE_CLEAR_OUTPUT="rm: /tmp/report.json: Permission denied"
    run tool_jest_run '{}'
    assert_failure 1
    assert_output --partial "could not be cleared before the run"
}

@test "storefront jest: issues no jest command when the report path cannot be cleared" {
    FAKE_CLEAR_EXIT=1
    FAKE_CLEAR_OUTPUT="rm: /tmp/report.json: Permission denied"
    run tool_jest_run '{}'
    assert_failure 1
    run cat "${FAKE_CALL_LOG}"
    refute_output --partial "npm run jest:base --"
}

@test "storefront jest: failed tests in the report fail the tool even when the process exited 0" {
    FAKE_REPORT_OUTPUT="$(_jest_report 127 123 4 12 1)"
    FAKE_RUN_EXIT=0
    run tool_jest_run '{}'
    assert_failure
    assert_line --partial "127 tests total, 123 passed, 4 failed"
}

@test "storefront jest: a failed test suite fails the tool when no individual test failed" {
    FAKE_REPORT_OUTPUT="$(_jest_report 13 13 0 2 1)"
    FAKE_RUN_EXIT=0
    run tool_jest_run '{}'
    assert_failure
    assert_line --partial "2 test suites total, 1 failed"
}

@test "storefront jest: a report of zero tests fails the tool" {
    FAKE_REPORT_OUTPUT="$(_jest_report 0 0 0 0 0)"
    FAKE_RUN_EXIT=0
    run tool_jest_run '{}'
    assert_failure
    assert_output --partial "No test matched, so the run executed nothing."
}

@test "storefront jest: the zero-test failure names the patterns that were in effect" {
    FAKE_REPORT_OUTPUT="$(_jest_report 0 0 0 0 0)"
    run tool_jest_run '{"testPathPatterns":"CartPlguin","testNamePattern":"adds to cart"}'
    assert_failure
    assert_output --partial "testPathPatterns: CartPlguin. testNamePattern: adds to cart."
}

@test "storefront jest: the zero-test failure names both patterns as absent when neither was given" {
    FAKE_REPORT_OUTPUT="$(_jest_report 0 0 0 0 0)"
    run tool_jest_run '{}'
    assert_failure
    assert_output --partial "testPathPatterns: (none). testNamePattern: (none)."
}

@test "storefront jest: all tests passed with a non-zero process exit still succeeds" {
    FAKE_RUN_EXIT=7
    run tool_jest_run '{}'
    assert_success
}

@test "storefront jest: all tests passed with a non-zero process exit reports that exit code" {
    FAKE_RUN_EXIT=7
    run tool_jest_run '{}'
    assert_line --index 2 --partial "every test passed, but the jest process still exited with code 7"
}

@test "storefront jest: all tests passed with a non-zero process exit keeps the command output" {
    FAKE_RUN_EXIT=7
    run tool_jest_run '{}'
    assert_line --index 3 --partial "npm run jest:base"
}

@test "storefront jest: a report that is not JSON propagates the process exit code" {
    FAKE_REPORT_OUTPUT="Cannot open file /tmp/nope.json"
    FAKE_RUN_EXIT=3
    run tool_jest_run '{}'
    assert_failure 3
    assert_line --partial "could not be read or parsed, so the status below is the process exit code (3)"
}

@test "storefront jest: a JSON report without the count fields propagates the process exit code" {
    FAKE_REPORT_OUTPUT='{"someOtherField":true}'
    FAKE_RUN_EXIT=3
    run tool_jest_run '{}'
    assert_failure 3
    assert_line --partial "could not be read or parsed, so the status below is the process exit code (3)"
}

@test "storefront jest: an unreadable report announces the exit-code fallback rather than a report-derived status" {
    FAKE_REPORT_OUTPUT=""
    run tool_jest_run '{}'
    assert_success
    assert_line --partial "could not be read or parsed, so the status below is the process exit code (0)"
    refute_output --partial "Jest report:"
}

@test "storefront jest: the config banner ahead of the JSON is stripped rather than breaking the parse" {
    FAKE_REPORT_OUTPUT="Run Jest in local mode
$(_jest_report 13 13 0 1 0)"
    run tool_jest_run '{}'
    assert_success
    assert_line --partial "13 tests total, 13 passed, 0 failed"
}

# --- Vitest ---

@test "storefront vitest: no arguments runs unit:components bare" {
    run tool_vitest_run '{}'
    assert_success
    assert_line "npm run unit:components"
}

@test "storefront vitest: coverage selects unit:components:coverage" {
    run tool_vitest_run '{"coverage":true}'
    assert_success
    assert_line "npm run unit:components:coverage"
}

@test "storefront vitest: testNamePattern maps to -t" {
    run tool_vitest_run '{"testNamePattern":"renders the cart"}'
    assert_success
    assert_line 'npm run unit:components -- -t "renders the cart"'
}

@test "storefront vitest: updateSnapshots maps to -u" {
    run tool_vitest_run '{"updateSnapshots":true}'
    assert_success
    assert_line "npm run unit:components -- -u"
}

@test "storefront vitest: paths are rebased onto views/components" {
    run tool_vitest_run '{"paths":["src/Storefront/Resources/views/components/checkout/cart.test.js"]}'
    assert_success
    assert_line 'npm run unit:components -- "views/components/checkout/cart.test.js"'
}

@test "storefront vitest: keeps a multi-word test name pattern in one argument" {
    run tool_vitest_run '{"testNamePattern":"adds to cart"}'
    assert_success
    assert_line 'npm run unit:components -- -t "adds to cart"'
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
    assert_line "composer ludtwig:storefront"
}

@test "storefront ludtwig fix: runs composer ludtwig:storefront:fix" {
    run tool_ludtwig_fix '{}'
    assert_success
    assert_line "composer ludtwig:storefront:fix"
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
