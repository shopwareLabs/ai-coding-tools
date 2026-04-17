#!/usr/bin/env bash
# Jest tool implementation for Admin Tooling MCP Server
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

    local test_name_pattern
    test_name_pattern=$(echo "${args}" | jq -r '.testNamePattern // empty')

    local coverage
    coverage=$(echo "${args}" | jq -r '.coverage // false')

    local update_snapshots
    update_snapshots=$(echo "${args}" | jq -r '.updateSnapshots // false')

    local -a flags=()

    [[ -n "${test_path_pattern}" ]] && flags+=("--testPathPatterns='${test_path_pattern}'")
    [[ -n "${test_name_pattern}" ]] && flags+=("--testNamePattern='${test_name_pattern}'")
    [[ "${coverage}" == "true" ]] && flags+=("--coverage")
    [[ "${update_snapshots}" == "true" ]] && flags+=("--updateSnapshot")

    local cmd="npm run unit"
    if [[ ${#flags[@]} -gt 0 ]]; then
        cmd="${cmd} -- ${flags[*]}"
    fi

    [[ -n "${env_prefix}" ]] && cmd="${env_prefix} ${cmd}"

    log "INFO" "Running Jest tests (admin): ${cmd}"

    exec_npm_command "${cmd}"
}
