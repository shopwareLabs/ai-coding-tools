#!/usr/bin/env bash
# ECS / PHP-CS-Fixer tool implementation for MCP server.
# When a scope declares style.tool = "php-cs-fixer", both tools switch
# binary to vendor/bin/php-cs-fixer. Tool names remain ecs_check/ecs_fix
# because the intent (check/fix style) is backend-agnostic.

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# _style_backend -> echoes "ecs" or "php-cs-fixer"
_style_backend() {
    local b
    b=$(scope_get_tool_field style tool)
    [[ -n "${b}" ]] && echo "${b}" || echo "ecs"
}

# _style_config_default -> echoes scope.style.config or .ecs.config
_style_config_default() {
    local c
    c=$(scope_get_tool_field style config)
    [[ -n "${c}" ]] && { echo "${c}"; return; }
    _get_config_value ".ecs.config"
}

# tool_ecs_check - MCP tool function (dry-run check)
tool_ecs_check() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    local default_config backend
    default_config=$(_style_config_default)
    backend=$(_style_backend)

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

    local -a path_array=()
    if [[ "${paths_json}" != "[]" ]]; then
        while IFS= read -r p; do
            [[ -n "${p}" ]] && path_array+=("${p}")
        done < <(echo "${paths_json}" | jq -r '.[]' 2>/dev/null)
    fi

    log "INFO" "Style check [backend=${backend}]: paths='${path_array[*]:-}' config='${config}'"

    local cmd
    local -a flags=()

    if [[ "${backend}" == "php-cs-fixer" ]]; then
        cmd="vendor/bin/php-cs-fixer fix --dry-run --diff"
        [[ -n "${config}" ]] && flags+=("--config=${config}")
        if [[ ${#path_array[@]} -gt 0 ]]; then
            for p in "${path_array[@]}"; do flags+=("'${p}'"); done
        fi
        [[ "${output_format}" == "json" ]] && flags+=("--format=json")
    else
        cmd="composer ecs"
        local -a ecs_args=()
        if [[ ${#path_array[@]} -gt 0 ]]; then
            for p in "${path_array[@]}"; do ecs_args+=("'${p}'"); done
        fi
        [[ -n "${config}" ]] && ecs_args+=("--config=${config}")
        [[ "${output_format}" == "json" ]] && ecs_args+=("--format=json")
        [[ ${#ecs_args[@]} -gt 0 ]] && cmd="${cmd} -- ${ecs_args[*]}"
        flags=()
    fi

    [[ ${#flags[@]} -gt 0 ]] && cmd="${cmd} ${flags[*]}"

    exec_command "${cmd}"
}

# tool_ecs_fix - MCP tool function (apply fixes)
tool_ecs_fix() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    local default_config backend
    default_config=$(_style_config_default)
    backend=$(_style_backend)

    local parsed
    parsed=$(echo "${args}" | jq -c '{
        paths: (.paths // []),
        config: (.config // null)
    }' 2>/dev/null || echo '{"paths":[],"config":null}')

    local paths_json config
    paths_json=$(echo "${parsed}" | jq -c '.paths')
    config=$(echo "${parsed}" | jq -r '.config // empty')

    [[ -z "${config}" ]] && config="${default_config}"

    local -a path_array=()
    if [[ "${paths_json}" != "[]" ]]; then
        while IFS= read -r p; do
            [[ -n "${p}" ]] && path_array+=("${p}")
        done < <(echo "${paths_json}" | jq -r '.[]' 2>/dev/null)
    fi

    log "INFO" "Style fix [backend=${backend}]: paths='${path_array[*]:-}' config='${config}'"

    local cmd
    if [[ "${backend}" == "php-cs-fixer" ]]; then
        cmd="vendor/bin/php-cs-fixer fix -v"
        [[ -n "${config}" ]] && cmd="${cmd} --config=${config}"
        if [[ ${#path_array[@]} -gt 0 ]]; then
            for p in "${path_array[@]}"; do cmd="${cmd} '${p}'"; done
        fi
    else
        cmd="composer ecs-fix"
        local -a ecs_args=()
        if [[ ${#path_array[@]} -gt 0 ]]; then
            for p in "${path_array[@]}"; do ecs_args+=("'${p}'"); done
        fi
        [[ -n "${config}" ]] && ecs_args+=("--config=${config}")
        [[ ${#ecs_args[@]} -gt 0 ]] && cmd="${cmd} -- ${ecs_args[*]}"
    fi

    exec_command "${cmd}"
}
