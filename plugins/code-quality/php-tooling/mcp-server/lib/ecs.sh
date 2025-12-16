#!/usr/bin/env bash
# ECS (Easy Coding Standard / PHP-CS-Fixer) tool implementation for MCP server

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

# tool_ecs_check - MCP tool function (dry-run check)
# Args: $1 = JSON arguments
# Returns: Raw ECS output
tool_ecs_check() {
    local args="$1"

    local default_config
    default_config=$(_get_config_value ".ecs.config")

    local parsed
    parsed=$(echo "${args}" | jq -c '{
        paths: (.paths // []),
        config: (.config // null),
        output_format: (.output_format // "text")
    }' 2>/dev/null || echo '{"paths":[],"config":null,"output_format":"text"}')

    local paths_json config output_format
    paths_json=$(echo "${parsed}" | jq -c '.paths')
    config=$(echo "${parsed}" | jq -r '.config // empty')
    output_format=$(echo "${parsed}" | jq -r '.output_format')

    [[ -z "${config}" ]] && config="${default_config}"

    # Build paths array properly to handle paths with spaces
    local -a path_array=()
    if [[ "${paths_json}" != "[]" ]]; then
        while IFS= read -r p; do
            [[ -n "${p}" ]] && path_array+=("${p}")
        done < <(echo "${paths_json}" | jq -r '.[]' 2>/dev/null)
    fi

    log "INFO" "ECS check: paths='${path_array[*]:-}' format='${output_format}' config='${config}'"

    local -a flags=()
    [[ ${#path_array[@]} -gt 0 ]] && flags+=("${path_array[@]}")
    [[ -n "${config}" ]] && flags+=("--config=${config}")
    [[ "${output_format}" == "json" ]] && flags+=("--format=json")

    local cmd="composer ecs"
    [[ ${#flags[@]} -gt 0 ]] && cmd="${cmd} -- ${flags[*]}"

    exec_command "${cmd}"
}

# tool_ecs_fix - MCP tool function (apply fixes)
# Args: $1 = JSON arguments
# Returns: Raw ECS output
tool_ecs_fix() {
    local args="$1"

    local default_config
    default_config=$(_get_config_value ".ecs.config")

    local parsed
    parsed=$(echo "${args}" | jq -c '{
        paths: (.paths // []),
        config: (.config // null)
    }' 2>/dev/null || echo '{"paths":[],"config":null}')

    local paths_json config
    paths_json=$(echo "${parsed}" | jq -c '.paths')
    config=$(echo "${parsed}" | jq -r '.config // empty')

    [[ -z "${config}" ]] && config="${default_config}"

    # Build paths array properly to handle paths with spaces
    local -a path_array=()
    if [[ "${paths_json}" != "[]" ]]; then
        while IFS= read -r p; do
            [[ -n "${p}" ]] && path_array+=("${p}")
        done < <(echo "${paths_json}" | jq -r '.[]' 2>/dev/null)
    fi

    log "INFO" "ECS fix: paths='${path_array[*]:-}' config='${config}'"

    local -a flags=()
    [[ ${#path_array[@]} -gt 0 ]] && flags+=("${path_array[@]}")
    [[ -n "${config}" ]] && flags+=("--config=${config}")

    local cmd="composer ecs-fix"
    [[ ${#flags[@]} -gt 0 ]] && cmd="${cmd} -- ${flags[*]}"

    exec_command "${cmd}"
}
