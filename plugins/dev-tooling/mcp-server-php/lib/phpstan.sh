#!/usr/bin/env bash
# PHPStan tool implementation for MCP server

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# _run_scope_bootstrap <tool>
# Runs scope.<tool>.bootstrap[] via exec_command in sequence. Any non-zero
# exit aborts with an MCP-facing error message on stdout.
_run_scope_bootstrap() {
    local tool="$1"
    local cmd
    while IFS= read -r cmd; do
        [[ -z "${cmd}" ]] && continue
        log "INFO" "Scope bootstrap [${tool}]: ${cmd}"
        local output rc=0
        output=$(exec_command "${cmd}") || rc=$?
        if [[ "${rc}" -ne 0 ]]; then
            echo "Scope bootstrap failed for tool '${tool}' (exit ${rc}):"
            echo "${output}"
            return 1
        fi
    done < <(scope_get_bootstrap "${tool}")
    return 0
}

# tool_phpstan_analyze - MCP tool function
# Args: $1 = JSON arguments
# Returns: Raw PHPStan output (JSON or text based on error_format)
tool_phpstan_analyze() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    if ! _run_scope_bootstrap phpstan; then
        return 1
    fi

    local default_config default_memory
    default_config=$(scope_get_tool_field phpstan config)
    [[ -z "${default_config}" ]] && default_config=$(_get_config_value ".phpstan.config")
    default_memory=$(_get_config_value ".phpstan.memory_limit")

    local parsed
    parsed=$(echo "${args}" | jq -c '{
        paths: (.paths // []),
        level: (.level // null),
        error_format: (.error_format // "json"),
        config: (.config // null),
        memory_limit: (.memory_limit // null)
    }' 2>/dev/null || echo '{"paths":[],"level":null,"error_format":"json","config":null,"memory_limit":null}')

    local paths_json level error_format config memory_limit
    paths_json=$(echo "${parsed}" | jq -c '.paths')
    level=$(echo "${parsed}" | jq -r '.level // empty')
    error_format=$(echo "${parsed}" | jq -r '.error_format')
    config=$(echo "${parsed}" | jq -r '.config // empty')
    memory_limit=$(echo "${parsed}" | jq -r '.memory_limit // empty')

    [[ -z "${config}" ]] && config="${default_config}"
    [[ -z "${memory_limit}" ]] && memory_limit="${default_memory}"

    local -a path_array=()
    if [[ "${paths_json}" != "[]" ]]; then
        while IFS= read -r p; do
            [[ -n "${p}" ]] && path_array+=("${p}")
        done < <(echo "${paths_json}" | jq -r '.[]' 2>/dev/null)
    fi

    log "INFO" "PHPStan analyze: scope='${SCOPE_NAME}' paths='${path_array[*]:-}' level='${level}' format='${error_format}' config='${config}' memory='${memory_limit}'"

    local -a flags=()
    if [[ ${#path_array[@]} -gt 0 ]]; then
        for p in "${path_array[@]}"; do flags+=("'${p}'"); done
    fi
    [[ -n "${config}" ]] && flags+=("--configuration=${config}")
    [[ -n "${memory_limit}" ]] && flags+=("--memory-limit=${memory_limit}")
    [[ -n "${level}" ]] && flags+=("--level=${level}")
    [[ "${error_format}" == "json" ]] && flags+=("--error-format=json")
    [[ "${error_format}" == "table" ]] && flags+=("--error-format=table")

    local cmd="composer phpstan"
    [[ ${#flags[@]} -gt 0 ]] && cmd="${cmd} -- ${flags[*]}"

    exec_command "${cmd}"
}
