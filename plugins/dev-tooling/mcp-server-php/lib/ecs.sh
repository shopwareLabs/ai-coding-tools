#!/usr/bin/env bash
# ECS / PHP-CS-Fixer tool implementation for MCP server.
# When a scope declares style.tool = "php-cs-fixer", both tools switch
# binary to vendor/bin/php-cs-fixer. Tool names remain ecs_check/ecs_fix
# because the intent (check/fix style) is backend-agnostic.

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# _refuse_linebreak_args <json args>
# A line break inside a string value bypasses the downstream shell-hostile-char
# guard: jq -r re-splits it into separate tokens before that guard runs, and
# command substitution silently strips a trailing one. Refuse here, before any
# value is extracted from the JSON.
# Stdout: the refusal message when a line break is found
# Returns: 1 when refused, 0 otherwise (malformed JSON is left to downstream handling)
_refuse_linebreak_args() {
    local args="$1"
    if echo "${args}" | jq -e 'any((.. | strings), (.. | objects | keys[]); contains("\n") or contains("\r"))' >/dev/null 2>&1; then
        printf '%s\n' "Refusing to run: arguments contain a line break, which cannot be embedded in a single command."
        return 1
    fi
    return 0
}

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

    _refuse_linebreak_args "${args}" || return 1

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
    if ! parsed=$(echo "${args}" | jq -c '{
        paths: (.paths // []),
        config: (.config // null),
        output_format: (.output_format // "text")
    }' 2>/dev/null); then
        printf '%s\n' "Refusing to run: could not parse arguments as JSON: ${args}"
        return 1
    fi

    local paths_json config output_format
    paths_json=$(echo "${parsed}" | jq -c '.paths')
    config=$(echo "${parsed}" | jq -r '.config // empty')
    output_format=$(echo "${parsed}" | jq -r '.output_format')

    [[ -z "${config}" ]] && config="${default_config}"

    # Paths are validated and quoted in one step: a malformed "paths" payload
    # must not fall through to the backend's own baked target set.
    local paths
    if ! paths=$(parse_paths_json "${paths_json}" ""); then
        printf '%s\n' "${paths}"
        return 1
    fi

    local guard
    if [[ -n "${config}" ]] && ! guard=$(assert_no_shell_hostile_chars "style configuration" "${config}"); then
        printf '%s\n' "${guard}"
        return 1
    fi

    log "INFO" "Style check [backend=${backend}]: paths='${paths}' config='${config}'"

    local cmd
    local -a flags=()

    if [[ "${backend}" == "php-cs-fixer" ]]; then
        cmd="vendor/bin/php-cs-fixer fix --dry-run --diff"
        [[ -n "${config}" ]] && flags+=("--config=$(shell_quote_arg "${config}")")
        [[ -n "${paths}" ]] && flags+=("${paths}")
        [[ "${output_format}" == "json" ]] && flags+=("--format=json")
    else
        cmd="composer ecs"
        local -a ecs_args=()
        [[ -n "${paths}" ]] && ecs_args+=("${paths}")
        [[ -n "${config}" ]] && ecs_args+=("--config=$(shell_quote_arg "${config}")")
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

    _refuse_linebreak_args "${args}" || return 1

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
    if ! parsed=$(echo "${args}" | jq -c '{
        paths: (.paths // []),
        config: (.config // null)
    }' 2>/dev/null); then
        printf '%s\n' "Refusing to run: could not parse arguments as JSON: ${args}"
        return 1
    fi

    local paths_json config
    paths_json=$(echo "${parsed}" | jq -c '.paths')
    config=$(echo "${parsed}" | jq -r '.config // empty')

    [[ -z "${config}" ]] && config="${default_config}"

    # Paths are validated and quoted in one step: a malformed "paths" payload
    # must not fall through to the backend's own baked target set.
    local paths
    if ! paths=$(parse_paths_json "${paths_json}" ""); then
        printf '%s\n' "${paths}"
        return 1
    fi

    local guard
    if [[ -n "${config}" ]] && ! guard=$(assert_no_shell_hostile_chars "style configuration" "${config}"); then
        printf '%s\n' "${guard}"
        return 1
    fi

    log "INFO" "Style fix [backend=${backend}]: paths='${paths}' config='${config}'"

    local cmd
    if [[ "${backend}" == "php-cs-fixer" ]]; then
        cmd="vendor/bin/php-cs-fixer fix -v"
        [[ -n "${config}" ]] && cmd="${cmd} --config=$(shell_quote_arg "${config}")"
        [[ -n "${paths}" ]] && cmd="${cmd} ${paths}"
    else
        cmd="composer ecs-fix"
        local -a ecs_args=()
        [[ -n "${paths}" ]] && ecs_args+=("${paths}")
        [[ -n "${config}" ]] && ecs_args+=("--config=$(shell_quote_arg "${config}")")
        [[ ${#ecs_args[@]} -gt 0 ]] && cmd="${cmd} -- ${ecs_args[*]}"
    fi

    exec_command "${cmd}"
}
