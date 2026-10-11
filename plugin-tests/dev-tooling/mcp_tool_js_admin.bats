#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,js-admin
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

# Answers the `npm pkg get "scripts.<name>"` probe from the Shopware trunk
# Administration package.json (fixtures/shopware-trunk). FAKE_ABSENT_SCRIPTS
# makes a script look undefined; FAKE_BODY_NAME/FAKE_BODY makes one report a
# different body.
#
# "jest:base" is the one script answered that trunk does not define: the jest
# tool routes at it when a package declares it, and these tests model such a
# package. FAKE_ABSENT_SCRIPTS="jest:base" restores the trunk layout, where the
# tool falls back to "unit".
_fake_admin_script_body() {
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

    shopware_trunk_script_body administration "${name}"
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
                _fake_admin_script_body "${name%\"}"
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
                        printf '%s\n%s\n' "LOCAL_BINARY_MISSING_IN" "/var/www/html/src/Administration/Resources/app/administration"
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
                    if [[ "$(_fake_admin_script_body "${script}")" == "{}" ]]; then
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
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/eslint.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/stylelint.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/prettier.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/jest.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/tsc.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/lint-all.sh"
    source "${PLUGIN_DIR}/mcp-server-js-admin/lib/build.sh"
}

teardown() {
    worktree_state_cleanup
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE JS_CONTEXT SCOPE_NAME SCOPE_CWD \
        SCOPE_JS_SUBDIR FAKE_ABSENT_SCRIPTS FAKE_BODY_NAME FAKE_BODY FAKE_PROBE_OUTPUT \
        FAKE_PROBE_FILE FAKE_REPORT_OUTPUT FAKE_REPORT_STORE FAKE_RUN_WRITES_REPORT \
        FAKE_REPORT_READ_FILE FAKE_CALL_LOG FAKE_CLEAR_EXIT FAKE_CLEAR_OUTPUT FAKE_RUN_EXIT \
        FAKE_MISSING_BINARIES FAKE_BINARY_PROBE_ERROR FAKE_DIRECTORY_PROBE_ERROR PROJECT_ROOT DEV_TOOLING_STATE_FILE
}

# --- ESLint: no paths keeps the aggregate script ---

@test "admin eslint check: no paths uses npm run lint" {
    run tool_eslint_check '{}'
    assert_success
    assert_line "npm run lint -- -f stylish"
}

@test "admin eslint check: json format when specified" {
    run tool_eslint_check '{"output_format":"json"}'
    assert_success
    assert_output --partial "-f json"
}

@test "admin eslint fix: no paths uses npm run lint:fix" {
    run tool_eslint_fix '{}'
    assert_success
    assert_line "npm run lint:fix -- --fix"
}

# --- ESLint: paths route at the target-less base script ---

@test "admin eslint check: paths route at lint:debugging as the only targets" {
    run tool_eslint_check '{"paths":["src/app/component"]}'
    assert_success
    assert_line 'npm run lint:debugging -- -f stylish "src/app/component"'
}

@test "admin eslint check: a path-scoped run carries no hardcoded upstream target" {
    run tool_eslint_check '{"paths":["src/app/component"]}'
    assert_success
    refute_output --partial "build/vue-setup-transform"
}

@test "admin eslint fix: paths route at lint:debugging with --fix" {
    run tool_eslint_fix '{"paths":["src/app/component"]}'
    assert_success
    assert_line 'npm run lint:debugging -- --fix "src/app/component"'
}

@test "admin eslint fix: a path-scoped run never reaches the aggregate lint:fix script" {
    run tool_eslint_fix '{"paths":["src/app/component"]}'
    assert_success
    refute_output --partial "npm run lint:fix"
}

@test "admin eslint check: repo-root-relative path is rebased onto the package dir" {
    run tool_eslint_check '{"paths":["src/Administration/Resources/app/administration/src/app/foo.ts"]}'
    assert_success
    assert_line 'npm run lint:debugging -- -f stylish "src/app/foo.ts"'
}

@test "admin eslint check: keeps a path containing a space in one argument" {
    run tool_eslint_check '{"paths":["src/app/my component"]}'
    assert_success
    assert_line 'npm run lint:debugging -- -f stylish "src/app/my component"'
}

# --- ESLint: hard failures instead of widening ---

@test "admin eslint check: refuses rather than falling back to the aggregate script" {
    FAKE_ABSENT_SCRIPTS="lint:debugging"
    run tool_eslint_check '{"paths":["src/app/component"]}'
    assert_failure
    assert_output --partial "lint:debugging"
    refute_output --partial "npm run lint"
}

@test "admin eslint fix: refuses rather than falling back to the aggregate fix script" {
    FAKE_ABSENT_SCRIPTS="lint:debugging"
    run tool_eslint_fix '{"paths":["src/app/component"]}'
    assert_failure
    assert_output --partial "lint:debugging"
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
    assert_line "npm run lint:scss -- -f string"
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
    assert_line "npm run lint:scss-fix"
}

@test "admin stylelint fix: no paths adds no second --fix on top of the aggregate body" {
    run tool_stylelint_fix '{}'
    assert_success
    refute_output --partial "--fix"
}

# Trunk's "lint:scss" passes no config of its own, so a scope config is
# appended to it, and to "lint:scss-fix", which reaches it through `npm run`.
@test "admin stylelint fix: a scoped config without paths is appended when no script in the chain passes a config" {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X","stylelint":{"config":".stylelintrc.plugin"}}}}
JSON
    run tool_stylelint_fix '{"scope":"plugin-x"}'
    assert_success
    assert_line "npm run lint:scss-fix -- --config .stylelintrc.plugin"
}

@test "admin stylelint fix: a scoped config without paths refuses when the chained lint:scss passes its own config" {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X","stylelint":{"config":".stylelintrc.plugin"}}}}
JSON
    FAKE_BODY_NAME="lint:scss"
    FAKE_BODY="stylelint --config .stylelintrc **/*.scss --cache"
    run tool_stylelint_fix '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial "\"npm run lint:scss-fix\" already passes a config of its own"
}

@test "admin stylelint check: a scoped config without paths refuses when lint:scss passes -c" {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X","stylelint":{"config":".stylelintrc.plugin"}}}}
JSON
    FAKE_BODY_NAME="lint:scss"
    FAKE_BODY="stylelint -c .stylelintrc **/*.scss"
    run tool_stylelint_check '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial "\"npm run lint:scss\" already passes a config of its own"
}

@test "admin stylelint check: a scoped config without paths refuses when lint:scss passes -c=" {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X","stylelint":{"config":".stylelintrc.plugin"}}}}
JSON
    FAKE_BODY_NAME="lint:scss"
    FAKE_BODY="stylelint -c=.stylelintrc **/*.scss"
    run tool_stylelint_check '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial "\"npm run lint:scss\" already passes a config of its own"
}

# The -c belongs to eslint, the command before the stylelint one.
@test "admin stylelint check: a scoped config without paths is appended when only another program in lint:scss takes -c" {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X","stylelint":{"config":".stylelintrc.plugin"}}}}
JSON
    FAKE_BODY_NAME="lint:scss"
    FAKE_BODY="eslint -c eslint.config.js . && stylelint **/*.scss"
    run tool_stylelint_check '{"scope":"plugin-x"}'
    assert_success
    assert_line "npm run lint:scss -- -f string --config .stylelintrc.plugin"
}

# --- Stylelint: paths run the package's own binary as the only targets ---

@test "admin stylelint check: paths run the local stylelint with the lint:scss flags" {
    run tool_stylelint_check '{"paths":["src/app/assets/scss/base.scss"]}'
    assert_success
    assert_line 'npm exec --no -- stylelint --cache -f string "src/app/assets/scss/base.scss"'
}

@test "admin stylelint fix: paths run the local stylelint with --fix" {
    run tool_stylelint_fix '{"paths":["src/app/assets/scss/base.scss"]}'
    assert_success
    assert_line 'npm exec --no -- stylelint --cache --fix "src/app/assets/scss/base.scss"'
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

@test "admin stylelint check: a scoped config follows the lint:scss flags" {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X","stylelint":{"config":".stylelintrc.plugin"}}}}
JSON
    run tool_stylelint_check '{"scope":"plugin-x","paths":["src/scss/base.scss"]}'
    assert_success
    assert_line 'npm exec --no -- stylelint --cache -f string --config .stylelintrc.plugin "src/scss/base.scss"'
}

@test "admin stylelint fix: refuses with paths when the package has no local stylelint" {
    FAKE_MISSING_BINARIES="stylelint"
    run tool_stylelint_fix '{"paths":["src/app/assets/scss/base.scss"]}'
    assert_failure
    assert_output --partial "\"node_modules/.bin/stylelint\" is not installed in the package directory \"/var/www/html/src/Administration/Resources/app/administration\""
}

@test "admin stylelint fix: runs neither stylelint nor the aggregate when the local stylelint is missing" {
    FAKE_MISSING_BINARIES="stylelint"
    run tool_stylelint_fix '{"paths":["src/app/assets/scss/base.scss"]}'
    assert_failure
    run cat "${FAKE_CALL_LOG}"
    refute_output --partial "-- stylelint"
    refute_output --partial "npm run"
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
    assert_line 'npm exec --no -- stylelint --cache -f string "src/**/*.scss"'
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
    assert_line "npm run format"
}

@test "admin prettier fix: no paths uses npm run format:fix" {
    run tool_prettier_fix
    assert_success
    assert_line "npm run format:fix"
}

# --- Prettier: paths run the package's own binary as the only targets ---

@test "admin prettier check: paths run the local prettier with --check" {
    run tool_prettier_check '{"paths":["src/app/main.ts"]}'
    assert_success
    assert_line 'npm exec --no -- prettier --check "src/app/main.ts"'
}

@test "admin prettier fix: paths run the local prettier with the format:fix flags" {
    run tool_prettier_fix '{"paths":["src/app/main.ts"]}'
    assert_success
    assert_line 'npm exec --no -- prettier --write --cache "src/app/main.ts"'
}

@test "admin prettier check: paths route carries no --write" {
    run tool_prettier_check '{"paths":["src/app/main.ts"]}'
    assert_success
    refute_output --partial "--write"
}

@test "admin prettier fix: a path-scoped run never reaches the aggregate format script" {
    run tool_prettier_fix '{"paths":["src/app/main.ts"]}'
    assert_success
    refute_output --partial "npm run format"
}

@test "admin prettier check: a scoped config follows the mode flag" {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X","prettier":{"config":".prettierrc.plugin"}}}}
JSON
    run tool_prettier_check '{"scope":"plugin-x","paths":["src/main.ts"]}'
    assert_success
    assert_line 'npm exec --no -- prettier --check --config .prettierrc.plugin "src/main.ts"'
}

@test "admin prettier check: refuses with paths when the package has no local prettier" {
    FAKE_MISSING_BINARIES="prettier"
    run tool_prettier_check '{"paths":["src/app/main.ts"]}'
    assert_failure
    assert_output --partial "\"node_modules/.bin/prettier\" is not installed in the package directory \"/var/www/html/src/Administration/Resources/app/administration\""
}

@test "admin prettier fix: runs neither prettier nor the aggregate when the local prettier is missing" {
    FAKE_MISSING_BINARIES="prettier"
    run tool_prettier_fix '{"paths":["src/app/main.ts"]}'
    assert_failure
    run cat "${FAKE_CALL_LOG}"
    refute_output --partial "-- prettier"
    refute_output --partial "npm run"
}

@test "admin prettier check: refuses a path that holds no file Prettier reads" {
    FAKE_PROBE_OUTPUT="UNMATCHED:src/app/assets/scss"
    run tool_prettier_check '{"paths":["src/app/assets/scss"]}'
    assert_failure
    assert_output --partial "Accepted extensions"
}

@test "admin prettier check: probes for the extensions the format scripts cover" {
    run tool_prettier_check '{"paths":["extension-tooling/index.mjs"]}'
    assert_success
    run cat "${FAKE_PROBE_FILE}"
    assert_output --partial '*.js|*.ts|*.mjs)'
}

@test "admin prettier check: a glob path skips the existence guard" {
    FAKE_PROBE_OUTPUT="MISSING:src/**/*.ts"
    run tool_prettier_check '{"paths":["src/**/*.ts"]}'
    assert_success
    assert_line 'npm exec --no -- prettier --check "src/**/*.ts"'
}

@test "admin stylelint check: probes a path for .scss files only, as lint:scss does" {
    run tool_stylelint_check '{"paths":["src/app/assets"]}'
    assert_success
    run cat "${FAKE_PROBE_FILE}"
    assert_output --partial 'in *.scss)'
}

@test "admin stylelint check: a directory reaches Stylelint as its .scss files only" {
    local dir="${BATS_TEST_TMPDIR}/src/Administration/Resources/app/administration/src/sty"
    mkdir -p "${dir}/nested"
    touch "${dir}/a.scss" "${dir}/nested/b.scss" "${dir}/c.css" "${dir}/e.js" "${dir}/f.json" "${dir}/g.twig" "${dir}/notes.txt"
    tool_stylelint_check '{"paths":["src/sty"]}' > /dev/null
    run js_execute_in_env native "$(grep '^npm exec --no -- stylelint ' "${FAKE_CALL_LOG}")"
    assert_success
    assert_line '[src/sty/**/*.scss]'
    run grep '^match:' <<< "${output}"
    assert_output "match:src/sty/a.scss
match:src/sty/nested/b.scss"
}

@test "admin prettier fix: a directory reaches Prettier as its .js, .ts and .mjs files only" {
    local dir="${BATS_TEST_TMPDIR}/src/Administration/Resources/app/administration/src/app/component"
    mkdir -p "${dir}"
    touch "${dir}/a.js" "${dir}/b.json" "${dir}/c.scss" "${dir}/d.md" "${dir}/e.vue" "${dir}/f.ts" "${dir}/g.mjs"
    tool_prettier_fix '{"paths":["src/app/component/"]}' > /dev/null
    run js_execute_in_env native "$(grep '^npm exec --no -- prettier ' "${FAKE_CALL_LOG}")"
    assert_success
    assert_line '[src/app/component/**/*.{js,ts,mjs}]'
    run grep '^match:' <<< "${output}"
    assert_output "match:src/app/component/a.js
match:src/app/component/f.ts
match:src/app/component/g.mjs"
}

@test "admin prettier check: a literal file path passes through unchanged" {
    run tool_prettier_check '{"paths":["extension-tooling/index.mjs"]}'
    assert_success
    assert_line 'npm exec --no -- prettier --check "extension-tooling/index.mjs"'
}

# Under ddev on a worktree `ddev exec` re-parses the command in the container's
# bash and leaves a value without space, quote or "#" unquoted, so the bash
# there would expand a directory's glob before the tool sees it.
# A directory named like a file is still a directory: Stylelint and Prettier
# given it bare would read every file in it.
@test "admin stylelint check: a directory named like a .scss file reaches Stylelint as its .scss files" {
    mkdir -p "${BATS_TEST_TMPDIR}/src/Administration/Resources/app/administration/src/legacy.scss"
    run tool_stylelint_check '{"paths":["src/legacy.scss"]}'
    assert_success
    assert_line 'npm exec --no -- stylelint --cache -f string "src/legacy.scss/**/*.scss"'
}

@test "admin prettier check: a directory named like a .mjs file reaches Prettier as its .js, .ts and .mjs files" {
    mkdir -p "${BATS_TEST_TMPDIR}/src/Administration/Resources/app/administration/src/lib.mjs"
    run tool_prettier_check '{"paths":["src/lib.mjs"]}'
    assert_success
    assert_line 'npm exec --no -- prettier --check "src/lib.mjs/**/*.{js,ts,mjs}"'
}

@test "admin prettier check: refuses when the directory test itself fails" {
    FAKE_DIRECTORY_PROBE_ERROR='Error response from daemon: container shopware-web-1 is not running'
    run tool_prettier_check '{"paths":["src/app/main.ts"]}'
    assert_failure
    assert_output --partial "could not check which of them are directories; the probe exited with 1. Probe output: Error response from daemon"
}

# The ddev environment, with the call treated as one on a linked worktree.
_as_ddev_worktree_call() {
    LINT_ENV="ddev"
    _env_targets_worktree() { return 0; }
}

@test "admin stylelint fix: a directory path is refused under ddev on a worktree" {
    _as_ddev_worktree_call
    run tool_stylelint_fix '{"paths":["src/app/assets/"]}'
    assert_failure
    assert_output --partial "under ddev on a worktree these paths would reach Stylelint as glob patterns"
}

@test "admin prettier fix: a directory path is refused under ddev on a worktree" {
    _as_ddev_worktree_call
    run tool_prettier_fix '{"paths":["src/app/component/"]}'
    assert_failure
    assert_output --partial "under ddev on a worktree these paths would reach Prettier as glob patterns"
}

@test "admin stylelint fix: a glob path is refused under ddev on a worktree" {
    _as_ddev_worktree_call
    run tool_stylelint_fix '{"paths":["src/**/*.scss"]}'
    assert_failure
    assert_output --partial "these paths would reach Stylelint as glob patterns the container shell expands first: src/**/*.scss"
}

@test "admin prettier fix: a file path still runs under ddev on a worktree" {
    _as_ddev_worktree_call
    run tool_prettier_fix '{"paths":["src/app/main.ts"]}'
    assert_success
    assert_line 'npm exec --no -- prettier --write --cache "src/app/main.ts"'
}

# --- Admin Stylelint and Prettier: the built commands executed through each environment wrapper ---

_admin_command() {
    "tool_$1" "{\"paths\":[\"$2\"]}" > /dev/null
    grep "^npm exec --no -- ${1%%_*} " "${FAKE_CALL_LOG}"
}

_assert_admin_stylelint_check_runs_in_package_dir() {
    run js_execute_in_env "$1" "$(_admin_command stylelint_check "src/app/my dir/base.scss")"
    assert_success
    assert_output "cwd=${BATS_TEST_TMPDIR}/src/Administration/Resources/app/administration
[--cache]
[-f]
[string]
[src/app/my dir/base.scss]"
}

_assert_admin_prettier_check_runs_in_package_dir() {
    run js_execute_in_env "$1" "$(_admin_command prettier_check "src/app/my dir/main.ts")"
    assert_success
    assert_output "cwd=${BATS_TEST_TMPDIR}/src/Administration/Resources/app/administration
[--check]
[src/app/my dir/main.ts]"
}

# The package installs prettier, so the probe finds it and prints nothing.
_assert_admin_prettier_probe_finds_binary() {
    tool_prettier_check '{"paths":["src/app/main.ts"]}' > /dev/null
    run js_execute_in_env "$1" "$(grep '^npm exec --no -c "test -x node_modules/.bin/prettier ' "${FAKE_CALL_LOG}")"
    assert_success
    assert_output ""
}

@test "admin stylelint command: runs in the package dir with its paths intact under native" {
    _assert_admin_stylelint_check_runs_in_package_dir native
}

@test "admin stylelint command: runs in the package dir with its paths intact under docker" {
    _assert_admin_stylelint_check_runs_in_package_dir docker
}

@test "admin stylelint command: runs in the package dir with its paths intact under docker-compose" {
    _assert_admin_stylelint_check_runs_in_package_dir docker-compose
}

@test "admin stylelint command: runs in the package dir with its paths intact under vagrant" {
    _assert_admin_stylelint_check_runs_in_package_dir vagrant
}

@test "admin stylelint command: runs in the package dir with its paths intact under ddev" {
    _assert_admin_stylelint_check_runs_in_package_dir ddev
}

@test "admin stylelint command: runs in the package dir with its paths intact under ddev on a worktree" {
    _assert_admin_stylelint_check_runs_in_package_dir ddev-worktree
}

@test "admin prettier command: runs in the package dir with its paths intact under native" {
    _assert_admin_prettier_check_runs_in_package_dir native
}

@test "admin prettier command: runs in the package dir with its paths intact under docker" {
    _assert_admin_prettier_check_runs_in_package_dir docker
}

@test "admin prettier command: runs in the package dir with its paths intact under docker-compose" {
    _assert_admin_prettier_check_runs_in_package_dir docker-compose
}

@test "admin prettier command: runs in the package dir with its paths intact under vagrant" {
    _assert_admin_prettier_check_runs_in_package_dir vagrant
}

@test "admin prettier command: runs in the package dir with its paths intact under ddev" {
    _assert_admin_prettier_check_runs_in_package_dir ddev
}

@test "admin prettier command: runs in the package dir with its paths intact under ddev on a worktree" {
    _assert_admin_prettier_check_runs_in_package_dir ddev-worktree
}

@test "admin local-binary probe: finds the package's prettier under native" {
    _assert_admin_prettier_probe_finds_binary native
}

@test "admin local-binary probe: finds the package's prettier under docker" {
    _assert_admin_prettier_probe_finds_binary docker
}

@test "admin local-binary probe: finds the package's prettier under docker-compose" {
    _assert_admin_prettier_probe_finds_binary docker-compose
}

@test "admin local-binary probe: finds the package's prettier under vagrant" {
    _assert_admin_prettier_probe_finds_binary vagrant
}

@test "admin local-binary probe: finds the package's prettier under ddev" {
    _assert_admin_prettier_probe_finds_binary ddev
}

@test "admin local-binary probe: finds the package's prettier under ddev on a worktree" {
    _assert_admin_prettier_probe_finds_binary ddev-worktree
}

# --- Every tool with a paths parameter, against the trunk package.json ---

# A path-scoped route that names an npm script Shopware does not define refuses
# every call on a real checkout. The tool list comes from tools.json, so a tool
# that gains a paths parameter is covered without an edit here.
@test "admin tools: no path-scoped call names an npm script the trunk package.json lacks" {
    local -a tools=()
    local tool
    while IFS= read -r tool; do
        tools+=("${tool}")
    done < <(jq -r '.tools[] | select(.inputSchema.properties.paths) | .name' \
        "${PLUGIN_DIR}/mcp-server-js-admin/tools.json")

    local refused=""
    for tool in "${tools[@]}"; do
        if ! "tool_${tool}" '{"paths":["src/app/main.ts"]}' > "${BATS_TEST_TMPDIR}/out.txt" 2>&1 \
            || grep -q -e "is not defined in package.json" -e "Missing script" "${BATS_TEST_TMPDIR}/out.txt"; then
            refused="${refused} ${tool}: $(cat "${BATS_TEST_TMPDIR}/out.txt")"
        fi
    done

    assert [ "${#tools[@]}" -ge 6 ]
    assert_equal "${refused}" ""
}

# --- TypeScript ---

@test "admin tsc check: uses npm run lint:types" {
    run tool_tsc_check
    assert_success
    assert_output --partial "npm run lint:types"
}

@test "admin tsc check: refuses when lint:types is undefined and a scoped config is set" {
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X","tsc":{"config":"tsconfig.custom.json"}}}}
JSON
    FAKE_ABSENT_SCRIPTS="lint:types"
    run tool_tsc_check '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial "lint:types"
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
    assert_line --index 2 "npm run jest:base -- --json --outputFile=\"${ADMIN_JEST_REPORT_FILE}\""
}

@test "admin jest: default run appends no --ci" {
    run tool_jest_run '{}'
    assert_success
    refute_output --partial "--ci"
}

@test "admin jest: ci=true appends --ci and still asks for the JSON report" {
    run tool_jest_run '{"ci":true}'
    assert_success
    assert_line --index 2 "npm run jest:base -- --ci --json --outputFile=\"${ADMIN_JEST_REPORT_FILE}\""
}

@test "admin jest: testPathPatterns flag added when provided" {
    run tool_jest_run '{"testPathPatterns":"CartService"}'
    assert_success
    assert_line --index 2 --partial 'npm run jest:base -- --testPathPatterns="CartService" --json'
}

@test "admin jest: coverage flag added when coverage=true" {
    run tool_jest_run '{"coverage":true}'
    assert_success
    assert_output --partial "--coverage"
}

@test "admin jest: keeps a multi-word test name pattern in one argument" {
    run tool_jest_run '{"testNamePattern":"adds to cart"}'
    assert_success
    assert_line --index 2 --partial 'npm run jest:base -- --testNamePattern="adds to cart" --json'
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
    assert_line --index 3 "npm run unit -- --json --outputFile=\"${ADMIN_JEST_REPORT_FILE}\""
}

@test "admin jest: the jest:base fallback announces that --ci is forced" {
    FAKE_ABSENT_SCRIPTS="jest:base"
    run tool_jest_run '{}'
    assert_success
    assert_line --partial "Notice: the npm script \"jest:base\" is unavailable"
}

@test "admin jest: the jest:base fallback announces the suppressed summary" {
    FAKE_ABSENT_SCRIPTS="jest:base"
    run tool_jest_run '{}'
    assert_success
    assert_line --partial "jest-silent-reporter"
}

# --- Jest: the result comes from the JSON report, not the exit code ---

@test "admin jest: the counts summary precedes the command output" {
    run tool_jest_run '{}'
    assert_success
    assert_line --index 1 "Jest report: 13 tests total, 13 passed, 0 failed, 0 pending; 1 test suites total, 0 failed. Process exit code: 0. The status below is derived from this report."
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
    assert_line --partial "127 tests total, 123 passed, 4 failed"
}

@test "admin jest: a failed test suite fails the tool when no individual test failed" {
    FAKE_REPORT_OUTPUT="$(_jest_report 13 13 0 2 1)"
    FAKE_RUN_EXIT=0
    run tool_jest_run '{}'
    assert_failure
    assert_line --partial "2 test suites total, 1 failed"
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
    assert_line --index 2 --partial "every test passed, but the jest process still exited with code 7"
}

@test "admin jest: all tests passed with a non-zero process exit keeps the command output" {
    FAKE_RUN_EXIT=7
    run tool_jest_run '{}'
    assert_line --index 3 --partial "npm run jest:base"
}

@test "admin jest: a report that is not JSON propagates the process exit code" {
    FAKE_REPORT_OUTPUT="Cannot open file /tmp/nope.json"
    FAKE_RUN_EXIT=3
    run tool_jest_run '{}'
    assert_failure 3
    assert_line --partial "could not be read or parsed, so the status below is the process exit code (3)"
}

@test "admin jest: a JSON report without the count fields propagates the process exit code" {
    FAKE_REPORT_OUTPUT='{"someOtherField":true}'
    FAKE_RUN_EXIT=3
    run tool_jest_run '{}'
    assert_failure 3
    assert_line --partial "could not be read or parsed, so the status below is the process exit code (3)"
}

@test "admin jest: an unreadable report announces the exit-code fallback rather than a report-derived status" {
    FAKE_REPORT_OUTPUT=""
    run tool_jest_run '{}'
    assert_success
    assert_line --partial "could not be read or parsed, so the status below is the process exit code (0)"
    refute_output --partial "Jest report:"
}

@test "admin jest: the config banner ahead of the JSON is stripped rather than breaking the parse" {
    FAKE_REPORT_OUTPUT="Run Jest in local mode
$(_jest_report 13 13 0 1 0)"
    run tool_jest_run '{}'
    assert_success
    assert_line --partial "13 tests total, 13 passed, 0 failed"
}

# --- Vite build ---

@test "admin vite build: production mode by default" {
    run tool_vite_build '{}'
    assert_success
    assert_output --partial "npm run build -- --mode production"
}

@test "admin vite build: refuses when the build script is undefined" {
    FAKE_ABSENT_SCRIPTS="build"
    run tool_vite_build '{}'
    assert_failure
    assert_output --partial "build"
}
