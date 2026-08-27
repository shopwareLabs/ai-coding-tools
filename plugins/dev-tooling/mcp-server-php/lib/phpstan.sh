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

    if echo "${args}" | jq -e 'any((.. | strings), (.. | objects | keys[]); contains("\n") or contains("\r"))' >/dev/null 2>&1; then
        printf '%s\n' "Refusing to run: arguments contain a line break, which cannot be embedded in a single command."
        return 1
    fi

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
    if ! parsed=$(echo "${args}" | jq -c '{
        paths: (.paths // []),
        level: (.level // null),
        error_format: (.error_format // "json"),
        config: (.config // null),
        memory_limit: (.memory_limit // null)
    }' 2>/dev/null); then
        printf '%s\n' "Refusing to run: could not parse arguments as JSON: ${args}"
        return 1
    fi

    local paths_json level error_format config memory_limit
    paths_json=$(echo "${parsed}" | jq -c '.paths')
    level=$(echo "${parsed}" | jq -r '.level // empty')
    error_format=$(echo "${parsed}" | jq -r '.error_format')
    config=$(echo "${parsed}" | jq -r '.config // empty')
    memory_limit=$(echo "${parsed}" | jq -r '.memory_limit // empty')

    [[ -z "${config}" ]] && config="${default_config}"
    [[ -z "${memory_limit}" ]] && memory_limit="${default_memory}"

    # Paths are validated and quoted in one step: a malformed "paths" payload
    # must not fall through to the config's own baked target set.
    local paths
    if ! paths=$(parse_paths_json "${paths_json}" ""); then
        printf '%s\n' "${paths}"
        return 1
    fi

    local guard
    if [[ -n "${config}" ]] && ! guard=$(assert_no_shell_hostile_chars "PHPStan configuration" "${config}"); then
        printf '%s\n' "${guard}"
        return 1
    fi
    if [[ -n "${memory_limit}" ]] && ! guard=$(assert_no_shell_hostile_chars "memory limit" "${memory_limit}"); then
        printf '%s\n' "${guard}"
        return 1
    fi
    if [[ -n "${level}" ]] && ! guard=$(assert_no_shell_hostile_chars "level" "${level}"); then
        printf '%s\n' "${guard}"
        return 1
    fi

    log "INFO" "PHPStan analyze: scope='${SCOPE_NAME}' paths='${paths}' level='${level}' format='${error_format}' config='${config}' memory='${memory_limit}'"

    local -a flags=()
    [[ -n "${paths}" ]] && flags+=("${paths}")
    [[ -n "${config}" ]] && flags+=("--configuration=$(shell_quote_arg "${config}")")
    [[ -n "${memory_limit}" ]] && flags+=("--memory-limit=$(shell_quote_arg "${memory_limit}")")
    [[ -n "${level}" ]] && flags+=("--level=$(shell_quote_arg "${level}")")
    case "${error_format}" in
        json) flags+=("--error-format=json") ;;
        table) flags+=("--error-format=table") ;;
        raw) flags+=("--error-format=raw") ;;
    esac

    local cmd="composer phpstan"
    [[ ${#flags[@]} -gt 0 ]] && cmd="${cmd} -- ${flags[*]}"

    exec_command "${cmd}"
}
