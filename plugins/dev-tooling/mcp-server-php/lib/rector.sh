#!/usr/bin/env bash
# Rector refactoring tool implementation for MCP server

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

# _run_scope_bootstrap <tool>
# Runs scope.<tool>.bootstrap[] via exec_command in sequence. Any non-zero
# exit aborts with an MCP-facing error message on stdout. Defined here as a
# local duplicate of the helper in phpstan.sh so rector.sh works when loaded
# standalone (e.g. unit tests that source only this file).
if ! declare -F _run_scope_bootstrap >/dev/null 2>&1; then
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
fi

# Parse shared Rector arguments from JSON
# Args: $1 = JSON arguments
# Sets: output_format, config, only, only_suffix, clear_cache, paths_json
_parse_rector_args() {
    local args="$1"

    local default_config
    default_config=$(_get_config_value ".rector.config")

    local scoped_config
    scoped_config=$(scope_get_tool_field rector config)

    local parsed
    parsed=$(echo "${args}" | jq -c '{
        paths: (.paths // []),
        output_format: (.output_format // "json"),
        config: (.config // null),
        only: (.only // null),
        only_suffix: (.only_suffix // null),
        clear_cache: (.clear_cache // false)
    }' 2>/dev/null || echo '{"paths":[],"output_format":"json","config":null,"only":null,"only_suffix":null,"clear_cache":false}')

    paths_json=$(echo "${parsed}" | jq -c '.paths')
    output_format=$(echo "${parsed}" | jq -r '.output_format')
    config=$(echo "${parsed}" | jq -r '.config // empty')
    only=$(echo "${parsed}" | jq -r '.only // empty')
    only_suffix=$(echo "${parsed}" | jq -r '.only_suffix // empty')
    clear_cache=$(echo "${parsed}" | jq -r '.clear_cache')

    [[ -z "${config}" ]] && config="${scoped_config}"
    [[ -z "${config}" ]] && config="${default_config}"
}

# tool_rector_fix - MCP tool function (apply refactorings)
# Args: $1 = JSON arguments
# Returns: Rector output (JSON or console)
tool_rector_fix() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
    if ! _run_scope_bootstrap rector; then
        return 1
    fi

    local paths_json output_format config only only_suffix clear_cache

    _parse_rector_args "${args}"

    log "INFO" "Rector fix: paths='${paths_json}' format='${output_format}' config='${config}' only='${only}' only_suffix='${only_suffix}' clear_cache='${clear_cache}'"

    local -a flags=("--no-progress-bar" "--output-format=${output_format}")
    [[ -n "${config}" ]] && flags+=("--config=${config}")
    [[ -n "${only}" ]] && flags+=("--only=${only}")
    [[ -n "${only_suffix}" ]] && flags+=("--only-suffix=${only_suffix}")
    [[ "${clear_cache}" == "true" ]] && flags+=("--clear-cache")
    if [[ "${paths_json}" != "[]" ]]; then
        local p
        while IFS= read -r p; do
            [[ -n "${p}" ]] && flags+=("'${p}'")
        done < <(echo "${paths_json}" | jq -r '.[]' 2>/dev/null)
    fi

    local cmd="composer rector"
    [[ ${#flags[@]} -gt 0 ]] && cmd="${cmd} -- ${flags[*]}"

    exec_command "${cmd}"
}

# tool_rector_check - MCP tool function (dry-run preview)
# Args: $1 = JSON arguments
# Returns: Rector output (JSON or console)
tool_rector_check() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
    if ! _run_scope_bootstrap rector; then
        return 1
    fi

    local paths_json output_format config only only_suffix clear_cache

    _parse_rector_args "${args}"

    log "INFO" "Rector check: paths='${paths_json}' format='${output_format}' config='${config}' only='${only}' only_suffix='${only_suffix}' clear_cache='${clear_cache}'"

    local -a flags=("--no-progress-bar" "--output-format=${output_format}")
    [[ -n "${config}" ]] && flags+=("--config=${config}")
    [[ -n "${only}" ]] && flags+=("--only=${only}")
    [[ -n "${only_suffix}" ]] && flags+=("--only-suffix=${only_suffix}")
    [[ "${clear_cache}" == "true" ]] && flags+=("--clear-cache")
    if [[ "${paths_json}" != "[]" ]]; then
        local p
        while IFS= read -r p; do
            [[ -n "${p}" ]] && flags+=("'${p}'")
        done < <(echo "${paths_json}" | jq -r '.[]' 2>/dev/null)
    fi

    local cmd="composer rector"
    cmd="${cmd} -- --dry-run ${flags[*]}"

    exec_command "${cmd}"
}
