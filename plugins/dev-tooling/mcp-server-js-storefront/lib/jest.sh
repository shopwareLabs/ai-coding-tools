#!/usr/bin/env bash
# Jest tool implementation for Storefront Tooling MCP Server
# Provides jest_run MCP tool
# Note: watch mode is not supported - long-running processes hang MCP servers

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
#       coverage (optional), updateSnapshots (optional), scope (optional)
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

    local cmd="npm run unit"
    if [[ ${#flags[@]} -gt 0 ]]; then
        local body
        local gate_code=0
        body=$(npm_script_append_gate "unit") || gate_code=$?
        if [[ "${gate_code}" -ne 0 ]]; then
            printf '%s\n' "${body}"
            return 1
        fi
        cmd="${cmd} -- ${flags[*]}"
    fi

    [[ -n "${env_prefix}" ]] && cmd="${env_prefix} ${cmd}"

    log "INFO" "Running Jest tests (storefront): ${cmd}"

    exec_npm_command "${cmd}"
}
