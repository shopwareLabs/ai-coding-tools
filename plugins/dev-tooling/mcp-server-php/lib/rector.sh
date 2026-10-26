#!/usr/bin/env bash
# Rector refactoring tool implementation for MCP server

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

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

# Parse shared Rector arguments from JSON
# Args: $1 = JSON arguments
# Sets: output_format, config, only, only_suffix, clear_cache, paths_json, paths
# Stdout: the refusal message when a value cannot be embedded in a command
# Returns: 0 on success, 1 when "paths" is malformed or a value is refused
_parse_rector_args() {
    local args="$1"

    local default_config
    default_config=$(_get_config_value ".rector.config")

    local scoped_config
    if ! scoped_config=$(scope_get_tool_field rector config 2>&1); then
        printf '%s\n' "${scoped_config}"
        return 1
    fi

    local parsed
    if ! parsed=$(echo "${args}" | jq -c '{
        paths: (.paths // []),
        output_format: (.output_format // "json"),
        config: (.config // null),
        only: (.only // null),
        only_suffix: (.only_suffix // null),
        clear_cache: (.clear_cache // false)
    }' 2>/dev/null); then
        printf '%s\n' "Refusing to run: could not parse arguments as JSON: ${args}"
        return 1
    fi

    paths_json=$(echo "${parsed}" | jq -c '.paths')
    output_format=$(echo "${parsed}" | jq -r '.output_format')
    config=$(echo "${parsed}" | jq -r '.config // empty')
    only=$(echo "${parsed}" | jq -r '.only // empty')
    only_suffix=$(echo "${parsed}" | jq -r '.only_suffix // empty')
    clear_cache=$(echo "${parsed}" | jq -r '.clear_cache')

    [[ -z "${config}" ]] && config="${scoped_config}"
    [[ -z "${config}" ]] && config="${default_config}"

    # Paths are validated and quoted in one step: a malformed "paths" payload
    # must not fall through to the Rector config's own baked target set.
    if ! paths=$(parse_paths_json "${paths_json}" ""); then
        printf '%s\n' "${paths}"
        return 1
    fi

    worktree_assert_paths_within_root "${paths_json}" || return 1

    local guard
    if ! guard=$(assert_no_shell_hostile_chars "Rector output format" "${output_format}"); then
        printf '%s\n' "${guard}"
        return 1
    fi
    if [[ -n "${config}" ]] && ! guard=$(assert_no_shell_hostile_chars "Rector configuration" "${config}"); then
        printf '%s\n' "${guard}"
        return 1
    fi
    if [[ -n "${only}" ]] && ! guard=$(assert_no_shell_hostile_chars "Rector rule" "${only}"); then
        printf '%s\n' "${guard}"
        return 1
    fi
    if [[ -n "${only_suffix}" ]] && ! guard=$(assert_no_shell_hostile_chars "Rector suffix" "${only_suffix}"); then
        printf '%s\n' "${guard}"
        return 1
    fi

    return 0
}

# _rector_fix_script
# Shopware core's "rector" script is a dry run; "rector-fix" is the one that writes files.
# Globals: reads WORKTREE_EFFECTIVE_ROOT, SCOPE_CWD
# Stdout: the script name, or a refusal message
# Returns: 1 when only a dry-run "rector" script exists
_rector_fix_script() {
    local composer_file="${WORKTREE_EFFECTIVE_ROOT}"
    [[ -n "${SCOPE_CWD:-}" ]] && composer_file+="/${SCOPE_CWD}"
    composer_file+="/composer.json"

    # An unreadable composer.json falls back to "rector"; composer reports the file itself.
    local script
    script=$(jq -r '
        .scripts as $scripts
        | if ($scripts | type) != "object" then "rector"
          elif $scripts | has("rector-fix") then "rector-fix"
          elif ([$scripts.rector] | flatten | map(tostring) | join(" ") | contains("--dry-run")) then "dry-run"
          else "rector" end
    ' "${composer_file}" 2>/dev/null) || script=""

    if [[ "${script}" == "dry-run" ]]; then
        printf '%s\n' "Refusing to run rector_fix: in ${composer_file} its \"rector\" script runs with --dry-run and there is no \"rector-fix\" script, so composer rector would report success and apply nothing."
        return 1
    fi

    printf '%s\n' "${script:-rector}"
}

# tool_rector_fix - MCP tool function (apply refactorings)
# Args: $1 = JSON arguments
# Returns: Rector output (JSON or console)
tool_rector_fix() {
    local args="$1"

    worktree_enter "${args}" || return 1

    _refuse_linebreak_args "${args}" || return 1

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    worktree_assert_dependencies || return 1

    local paths_json paths output_format config only only_suffix clear_cache

    _parse_rector_args "${args}" || return 1

    local fix_script
    if ! fix_script=$(_rector_fix_script); then
        printf '%s\n' "${fix_script}"
        return 1
    fi

    # After every argument guard: the bootstrap runs project commands, so a
    # refused call must not have run them.
    if ! _run_scope_bootstrap rector; then
        return 1
    fi

    log "INFO" "Rector fix: paths='${paths_json}' format='${output_format}' config='${config}' only='${only}' only_suffix='${only_suffix}' clear_cache='${clear_cache}'"

    local -a flags=("--no-progress-bar" "--output-format=$(shell_quote_arg "${output_format}")")
    [[ -n "${config}" ]] && flags+=("--config=$(shell_quote_arg "${config}")")
    [[ -n "${only}" ]] && flags+=("--only=$(shell_quote_arg "${only}")")
    [[ -n "${only_suffix}" ]] && flags+=("--only-suffix=$(shell_quote_arg "${only_suffix}")")
    [[ "${clear_cache}" == "true" ]] && flags+=("--clear-cache")
    [[ -n "${paths}" ]] && flags+=("${paths}")

    local cmd="composer ${fix_script}"
    [[ ${#flags[@]} -gt 0 ]] && cmd="${cmd} -- ${flags[*]}"

    exec_command "${cmd}"
}

# tool_rector_check - MCP tool function (dry-run preview)
# Args: $1 = JSON arguments
# Returns: Rector output (JSON or console)
tool_rector_check() {
    local args="$1"

    worktree_enter "${args}" || return 1

    _refuse_linebreak_args "${args}" || return 1

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    worktree_assert_dependencies || return 1

    local paths_json paths output_format config only only_suffix clear_cache

    _parse_rector_args "${args}" || return 1

    # After every argument guard: the bootstrap runs project commands, so a
    # refused call must not have run them.
    if ! _run_scope_bootstrap rector; then
        return 1
    fi

    log "INFO" "Rector check: paths='${paths_json}' format='${output_format}' config='${config}' only='${only}' only_suffix='${only_suffix}' clear_cache='${clear_cache}'"

    local -a flags=("--no-progress-bar" "--output-format=$(shell_quote_arg "${output_format}")")
    [[ -n "${config}" ]] && flags+=("--config=$(shell_quote_arg "${config}")")
    [[ -n "${only}" ]] && flags+=("--only=$(shell_quote_arg "${only}")")
    [[ -n "${only_suffix}" ]] && flags+=("--only-suffix=$(shell_quote_arg "${only_suffix}")")
    [[ "${clear_cache}" == "true" ]] && flags+=("--clear-cache")
    [[ -n "${paths}" ]] && flags+=("${paths}")

    local cmd="composer rector"
    cmd="${cmd} -- --dry-run ${flags[*]}"

    exec_command "${cmd}"
}
