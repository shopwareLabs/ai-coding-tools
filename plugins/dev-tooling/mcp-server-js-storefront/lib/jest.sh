#!/usr/bin/env bash
# Jest tool implementation for Storefront Tooling MCP Server
# Provides jest_run MCP tool
# Note: watch mode is not supported - long-running processes hang MCP servers
#
# Runs route at the target-less npm script "jest:base". The aggregate "unit"
# script is `npm run jest:base -- --ci`, and appending `--ci=false` does not
# undo that because the literal `--ci` is still in argv.
# What CI mode changes here is snapshot writing. jest-config resolves the
# snapshot mode as `ci && !updateSnapshot ? 'none' : updateSnapshot ? 'all'
# : 'new'`, so `--ci` alone downgrades the default 'new' (write missing
# snapshots) to 'none' (write nothing). An explicit `--updateSnapshot` resolves
# to 'all' whether or not `--ci` is present — it wins, it is not cancelled out.
# Routing every run at "unit" would therefore silently stop new snapshots being
# written on runs that did not ask for CI mode. The `ci` argument puts that mode
# back under the caller's control.
# Coverage is a separate matter here: the Storefront jest.config.js sets
# `collectCoverage: true` unconditionally, so the "coverage" argument only ever
# adds an already-set flag. That is a config-level fact this routing does not
# change.
#
# The tool's result comes from Jest's own JSON report, not from the process
# exit code. The exit code answers "did the jest process end cleanly", which is
# not the question the caller asked: a post-run writer that fails turns a
# correct suite into a reported failure, and a run that matched no test at all
# reports `"success": true` in the report while executing nothing. Every run
# therefore asks for `--json --outputFile=<path>`, and the counts in that report
# decide pass, fail, or "no test ran". `--outputFile` rather than bare `--json`
# because the report would otherwise share stdout with the human-readable
# output, and it carries per-test detail for the whole suite.
#
# The report path is fixed for the life of the server process, so a report is
# only this run's report if the file was gone before Jest started. The delete
# therefore happens before the run, not after the read: a run that ends without
# writing a report — a crash before the report writer, a results processor that
# throws — would otherwise have the previous run's report read as its result,
# and an all-green report left by an earlier run would turn a failing run into
# a reported pass. Nothing deletes the report after it is read; the next run's
# pre-run delete does that, so one report file per server process may sit in
# /tmp between runs. That is deliberate and costs a round-trip less than a
# post-run delete would.

STOREFRONT_JEST_BASE_SCRIPT="jest:base"
STOREFRONT_JEST_AGGREGATE_SCRIPT="unit"

# Per-server, per-process report path. Requests into one stdio MCP server are
# handled sequentially, so a single server never has two runs in flight; the
# PID keeps two server processes sharing one /tmp apart, and the context name
# keeps the admin and storefront servers apart.
STOREFRONT_JEST_REPORT_FILE="/tmp/mcp-js-storefront-jest-report-$$.json"

# _jest_scope_env_prefix - emits "A=b B=c " prefix from scope.jest.env map.
# Empty string when no scope or no env map. Guarded so sourcing the admin and
# storefront jest.sh in the same shell does not collide.
if ! declare -F _jest_scope_env_prefix >/dev/null; then
    _jest_scope_env_prefix() {
        [[ "${SCOPE_NAME:-shopware}" == "shopware" ]] && return 0
        [[ -f "${LINT_CONFIG_FILE:-}" ]] || return 0
        jq -r --arg name "${SCOPE_NAME}" \
            '(.scopes[$name].jest.env // {}) | to_entries | map("\(.key)=\(.value)") | join(" ")' \
            "${LINT_CONFIG_FILE}" 2>/dev/null || true
    }
fi

# _jest_install_if_missing - runs npm ci when node_modules is absent and
# scope.jest.install_if_missing is true. Aborts on install failure.
if ! declare -F _jest_install_if_missing >/dev/null; then
    _jest_install_if_missing() {
        [[ "${SCOPE_NAME:-shopware}" == "shopware" ]] && return 0
        local flag
        flag=$(jq -r --arg name "${SCOPE_NAME}" '.scopes[$name].jest.install_if_missing // false' "${LINT_CONFIG_FILE}" 2>/dev/null || echo "false")
        [[ "${flag}" != "true" ]] && return 0

        local node_modules_path="${LINT_WORKDIR}/${SCOPE_CWD}/${SCOPE_JS_SUBDIR}/node_modules"
        [[ -d "${node_modules_path}" ]] && return 0

        log "INFO" "Jest install_if_missing: running npm ci in ${node_modules_path%/node_modules}"
        exec_npm_command "npm ci" || {
            echo "npm ci failed; jest aborted"
            return 1
        }
    }
fi

# Delete a report left behind by an earlier run, in the environment the next
# run will write it in.
# Issued as its own wrapped command and never chained onto another one: the ddev
# wrapper puts only the leading command inside the container
# (`ddev exec <first>; <rest>`), so a compound `cat …; rm …` deletes nothing —
# the `rm` runs on the host while the file lives in the container. A single
# command wraps correctly in every environment.
# Args: $1 = report path
# Stdout: the wrapper output when the delete failed, nothing otherwise
# Returns: 0 when the path is known to be gone, 1 otherwise
_storefront_jest_clear_report() {
    local path="$1"

    local quoted
    quoted=$(shell_quote_arg "${path}")

    local output
    local exit_code=0
    output=$(exec_npm_command "rm -f -- ${quoted}") || exit_code=$?

    if [[ "${exit_code}" -ne 0 ]]; then
        printf '%s\n' "${output}"
        return 1
    fi

    return 0
}

# Read the JSON report back from the environment the run happened in, as its own
# wrapped command. Nothing is chained onto it — see _storefront_jest_clear_report
# for why, and for what deletes the file.
# The Jest config prints a console.info banner ahead of everything, so anything
# before the first "{" is dropped.
# Args: $1 = report path
# Stdout: the report, banner stripped
# Returns: 0 when something report-shaped was read, 1 otherwise
_storefront_jest_read_report() {
    local path="$1"

    local quoted
    quoted=$(shell_quote_arg "${path}")

    local raw
    local exit_code=0
    raw=$(exec_npm_command "cat -- ${quoted} 2>/dev/null") || exit_code=$?

    if [[ "${exit_code}" -ne 0 ]]; then
        return 1
    fi

    if [[ "${raw}" != *"{"* ]]; then
        return 1
    fi

    printf '%s\n' "{${raw#*\{}"
}

# Extract the counts the result is derived from.
# A report that is not valid JSON, or that carries none of the count fields, is
# refused rather than defaulted: a zero count invented here is indistinguishable
# from a run that really executed nothing.
# Args: $1 = report JSON
# Stdout: TSV "total passed failed pending suites_total suites_failed"
# Returns: 0 when every required count was present, 1 otherwise
_storefront_jest_report_counts() {
    local report="$1"

    if ! printf '%s' "${report}" | jq empty 2>/dev/null; then
        return 1
    fi

    printf '%s' "${report}" | jq -e -r '
        select((.numTotalTests | type) == "number")
        | select((.numFailedTests | type) == "number")
        | select((.numFailedTestSuites | type) == "number")
        | [ .numTotalTests,
            (.numPassedTests // 0),
            .numFailedTests,
            (.numPendingTests // 0),
            (.numTotalTestSuites // 0),
            .numFailedTestSuites ]
        | @tsv
    ' 2>/dev/null
}

# Turn one run into the tool's result: a counts summary ahead of the command
# output, then pass or fail decided by the report.
# Args: $1 = process exit code, $2 = testPathPatterns, $3 = testNamePattern,
#       $4 = command output
# Returns: 0 when the report says every test passed and at least one ran
_storefront_jest_report_result() {
    local run_exit="$1"
    local path_pattern="$2"
    local name_pattern="$3"
    local output="$4"

    local report=""
    local counts=""
    if report=$(_storefront_jest_read_report "${STOREFRONT_JEST_REPORT_FILE}"); then
        counts=$(_storefront_jest_report_counts "${report}") || counts=""
    fi

    if [[ -z "${counts}" ]]; then
        printf '%s\n' "Notice: Jest's JSON report (${STOREFRONT_JEST_REPORT_FILE}) could not be read or parsed, so the status below is the process exit code (${run_exit}) and not a result derived from the report. Read it as less authoritative: an exit code cannot tell a suite that failed apart from a step that failed after the suite passed, and it cannot tell a run that executed no test apart from one that passed."
        printf '%s\n' "${output}"
        return "${run_exit}"
    fi

    local total passed failed pending suites_total suites_failed
    IFS=$'\t' read -r total passed failed pending suites_total suites_failed <<< "${counts}"

    printf '%s\n' "Jest report: ${total} tests total, ${passed} passed, ${failed} failed, ${pending} pending; ${suites_total} test suites total, ${suites_failed} failed. Process exit code: ${run_exit}. The status below is derived from this report."

    if [[ "${failed}" -gt 0 || "${suites_failed}" -gt 0 ]]; then
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${total}" -eq 0 ]]; then
        printf '%s\n' "No test matched, so the run executed nothing. testPathPatterns: ${path_pattern:-(none)}. testNamePattern: ${name_pattern:-(none)}. This is reported as a failure: a run that executed no test proves nothing about the code, and Jest reports \"success\" for it."
        printf '%s\n' "${output}"
        return 1
    fi

    if [[ "${run_exit}" -ne 0 ]]; then
        printf '%s\n' "WARNING: every test passed, but the jest process still exited with code ${run_exit}. The failure happened around the run, not in it — a reporter, a global teardown, or a post-run writer. The full command output is kept below so the cause stays visible. The tests themselves are green."
    fi

    printf '%s\n' "${output}"
}

# Jest test runner
# Args: JSON with testPathPatterns (optional), testNamePattern (optional),
#       coverage (optional), updateSnapshots (optional), ci (optional),
#       scope (optional)
tool_jest_run() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    SCOPE_JS_SUBDIR=""
    if [[ "${SCOPE_NAME}" != "shopware" ]]; then
        SCOPE_JS_SUBDIR=$(scope_get_tool_field jest cwd)
    fi

    _jest_install_if_missing || return 1

    local env_prefix
    env_prefix=$(_jest_scope_env_prefix)

    local test_path_pattern
    test_path_pattern=$(echo "${args}" | jq -r '.testPathPatterns // empty')

    # Jest's rootDir is the app/storefront package and its testMatch only covers
    # **/test/**/*.test.js. Storefront component tests live under
    # views/components/ and are collected by Vitest alone, so a Jest run scoped
    # to them would report green without executing a single test.
    if [[ "${test_path_pattern}" == *"views/components"* || "${test_path_pattern}" == *"components/"* ]]; then
        printf '%s\n' "Storefront component tests under views/components/ do not run under Jest: the Jest project's rootDir is the app/storefront package and its testMatch only collects **/test/**/*.test.js. Use vitest_run for them."
        return 1
    fi

    local test_name_pattern
    test_name_pattern=$(echo "${args}" | jq -r '.testNamePattern // empty')

    local coverage
    coverage=$(echo "${args}" | jq -r '.coverage // false')

    local update_snapshots
    update_snapshots=$(echo "${args}" | jq -r '.updateSnapshots // false')

    local ci
    ci=$(echo "${args}" | jq -r '.ci // false')

    local guard
    if [[ -n "${test_path_pattern}" ]] && ! guard=$(assert_no_shell_hostile_chars "test path pattern" "${test_path_pattern}"); then
        printf '%s\n' "${guard}"
        return 1
    fi
    if [[ -n "${test_name_pattern}" ]] && ! guard=$(assert_no_shell_hostile_chars "test name pattern" "${test_name_pattern}"); then
        printf '%s\n' "${guard}"
        return 1
    fi

    local -a flags=()

    [[ -n "${test_path_pattern}" ]] && flags+=("--testPathPatterns=$(shell_quote_arg "${test_path_pattern}")")
    [[ -n "${test_name_pattern}" ]] && flags+=("--testNamePattern=$(shell_quote_arg "${test_name_pattern}")")
    [[ "${coverage}" == "true" ]] && flags+=("--coverage")
    [[ "${update_snapshots}" == "true" ]] && flags+=("--updateSnapshot")

    local body
    local gate_code=0
    body=$(npm_script_append_gate "${STOREFRONT_JEST_BASE_SCRIPT}") || gate_code=$?

    local script="${STOREFRONT_JEST_BASE_SCRIPT}"

    if [[ "${gate_code}" -ne 0 ]]; then
        # Degraded route, announced rather than silent. No path widening is at
        # stake here — "unit" runs the same suite — so falling back is better
        # than refusing, but the caller has to know which arguments the
        # fallback overrides.
        script="${STOREFRONT_JEST_AGGREGATE_SCRIPT}"
        printf '%s\n' "Notice: the npm script \"${STOREFRONT_JEST_BASE_SCRIPT}\" is unavailable, so this run falls back to \"${STOREFRONT_JEST_AGGREGATE_SCRIPT}\", whose body hardcodes --ci. Consequences: the \"ci\" argument is ignored and CI mode is forced, so a run that did not pass \"updateSnapshots\" writes no new snapshots where it otherwise would have. \"updateSnapshots\" itself still takes effect — an explicit --updateSnapshot resolves the snapshot mode to 'all' regardless of --ci. Coverage is unaffected either way — jest.config.js sets collectCoverage: true unconditionally, so it is collected regardless of the \"coverage\" argument. Reason: ${body}"
    elif [[ "${ci}" == "true" ]]; then
        # Only the base script needs this appended; the aggregate already
        # carries --ci in its body.
        flags+=("--ci")
    fi

    # Every route asks for the report, the fallback and the CI route included:
    # those are the routes where the silent reporter suppresses Jest's own
    # "Tests:" line, so the report is the only place the counts exist.
    flags+=("--json" "--outputFile=$(shell_quote_arg "${STOREFRONT_JEST_REPORT_FILE}")")

    local cmd="npm run ${script}"

    # The base script already passed the gate above; only the fallback still
    # needs one before anything is appended to it.
    if [[ "${script}" == "${STOREFRONT_JEST_AGGREGATE_SCRIPT}" ]]; then
        local aggregate_body
        local aggregate_gate=0
        aggregate_body=$(npm_script_append_gate "${script}") || aggregate_gate=$?
        if [[ "${aggregate_gate}" -ne 0 ]]; then
            printf '%s\n' "${aggregate_body}"
            return 1
        fi
    fi
    cmd="${cmd} -- ${flags[*]}"

    [[ -n "${env_prefix}" ]] && cmd="${env_prefix} ${cmd}"

    # Freshness is established here, before Jest starts. Refusing when the
    # delete fails is the point: the alternative is running with a report that
    # may still be on disk, and a stale all-green report read back as this run's
    # result reports a failing suite as a pass.
    local clear_error
    if ! clear_error=$(_storefront_jest_clear_report "${STOREFRONT_JEST_REPORT_FILE}"); then
        printf '%s\n' "Refusing to run: the JSON report path (${STOREFRONT_JEST_REPORT_FILE}) could not be cleared before the run, so a report present afterwards could not be told apart from one an earlier run left there. Running anyway risks reporting a failing suite as a pass. Delete that file where the commands run, then retry. Reason: ${clear_error}"
        return 1
    fi

    log "INFO" "Running Jest tests (storefront, ${script}): ${cmd}"

    local output
    local run_exit=0
    output=$(exec_npm_command "${cmd}") || run_exit=$?

    _storefront_jest_report_result "${run_exit}" "${test_path_pattern}" "${test_name_pattern}" "${output}"
}
