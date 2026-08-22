#!/usr/bin/env bash
# Jest tool implementation for Admin Tooling MCP Server
# Provides jest_run MCP tool
# Note: watch mode is not supported - long-running processes hang MCP servers
#
# Runs route at the target-less npm script "jest:base". The aggregate "unit"
# script is `npm run jest:base -- --ci`, and jest.config.ts derives
# `isCi` from an exact `--ci` match in process.argv: it then sets
# `collectCoverage: isCi` and swaps the reporters for jest-silent-reporter plus
# jest-junit. Routing at "unit" therefore forces coverage on every run and
# suppresses the per-test and summary output the caller asked for, and
# appending `--ci=false` does not undo it because the literal `--ci` is still
# in argv. The `ci` argument puts that mode back under the caller's control.

ADMIN_JEST_BASE_SCRIPT="jest:base"
ADMIN_JEST_AGGREGATE_SCRIPT="unit"

# _jest_scope_env_prefix - emits "A=b B=c " prefix from scope.jest.env map.
# Empty string when no scope or no env map. Guarded so sourcing the admin and
# storefront jest.sh in the same shell does not collide.
if ! declare -F _jest_scope_env_prefix >/dev/null; then
    _jest_scope_env_prefix() {
        [[ "${SCOPE_NAME:-shopware}" == "shopware" ]] && return 0
        [[ -f "${LINT_CONFIG_FILE:-}" ]] || return 0
        jq -r "(.scopes.\"${SCOPE_NAME}\".jest.env // {}) | to_entries | map(\"\(.key)=\(.value)\") | join(\" \")" "${LINT_CONFIG_FILE}" 2>/dev/null || true
    }
fi

# _jest_install_if_missing - runs npm ci when node_modules is absent and
# scope.jest.install_if_missing is true. Aborts on install failure.
if ! declare -F _jest_install_if_missing >/dev/null; then
    _jest_install_if_missing() {
        [[ "${SCOPE_NAME:-shopware}" == "shopware" ]] && return 0
        local flag
        flag=$(jq -r ".scopes.\"${SCOPE_NAME}\".jest.install_if_missing // false" "${LINT_CONFIG_FILE}" 2>/dev/null || echo "false")
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
    body=$(npm_script_append_gate "${ADMIN_JEST_BASE_SCRIPT}") || gate_code=$?

    local script="${ADMIN_JEST_BASE_SCRIPT}"

    if [[ "${gate_code}" -ne 0 ]]; then
        # Degraded route, announced rather than silent. No path widening is at
        # stake here — "unit" runs the same suite — so falling back is better
        # than refusing, but the caller has to know which arguments the
        # fallback overrides.
        script="${ADMIN_JEST_AGGREGATE_SCRIPT}"
        printf '%s\n' "Notice: the npm script \"${ADMIN_JEST_BASE_SCRIPT}\" is unavailable, so this run falls back to \"${ADMIN_JEST_AGGREGATE_SCRIPT}\", whose body hardcodes --ci. Consequences: the \"ci\" argument is ignored and CI mode is forced; coverage is collected regardless of the \"coverage\" argument, because jest.config.ts sets collectCoverage from that same --ci; and the reporters are swapped to jest-silent-reporter plus jest-junit, so the per-test lines and the summary are suppressed. Reason: ${body}"
    elif [[ "${ci}" == "true" ]]; then
        # Only the base script needs this appended; the aggregate already
        # carries --ci in its body.
        flags+=("--ci")
    fi

    local cmd="npm run ${script}"
    if [[ ${#flags[@]} -gt 0 ]]; then
        # The base script already passed the gate above; only the fallback
        # still needs one before anything is appended to it.
        if [[ "${script}" == "${ADMIN_JEST_AGGREGATE_SCRIPT}" ]]; then
            local aggregate_body
            local aggregate_gate=0
            aggregate_body=$(npm_script_append_gate "${script}") || aggregate_gate=$?
            if [[ "${aggregate_gate}" -ne 0 ]]; then
                printf '%s\n' "${aggregate_body}"
                return 1
            fi
        fi
        cmd="${cmd} -- ${flags[*]}"
    fi

    [[ -n "${env_prefix}" ]] && cmd="${env_prefix} ${cmd}"

    log "INFO" "Running Jest tests (admin, ${script}): ${cmd}"

    exec_npm_command "${cmd}"
}
