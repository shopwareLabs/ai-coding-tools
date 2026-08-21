#!/usr/bin/env bash
# Stylelint tool implementation for Storefront Tooling MCP Server
# Provides stylelint_check and stylelint_fix MCP tools
#
# No paths supplied appends no path target, so the targets baked into the npm
# script stay authoritative. Flags the caller's arguments ask for are appended
# either way. Every append is gated on the script body being able to receive it.

# Stylelint check (dry-run)
# Args: JSON with paths (optional), output_format (optional), scope (optional)
tool_stylelint_check() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
    local scoped_config
    scoped_config=$(scope_get_tool_field stylelint config)

    local paths_json paths
    paths_json=$(echo "${args}" | jq -c '.paths // []')
    if ! paths=$(parse_paths_json "${paths_json}" ""); then
        printf '%s\n' "${paths}"
        return 1
    fi

    local output_format
    output_format=$(echo "${args}" | jq -r '.output_format // "string"')

    # The reporter flag is always appended, so this tool never runs bare.
    local -a appended=()

    case "${output_format}" in
        json) appended+=("-f" "json") ;;
        compact) appended+=("-f" "compact") ;;
        string|*) appended+=("-f" "string") ;;
    esac

    [[ -n "${scoped_config}" ]] && appended+=("--config" "${scoped_config}")
    [[ -n "${paths}" ]] && appended+=("${paths}")

    local body
    local gate_code=0
    body=$(npm_script_append_gate "lint:scss") || gate_code=$?
    if [[ "${gate_code}" -ne 0 ]]; then
        printf '%s\n' "${body}"
        return 1
    fi

    local cmd="npm run lint:scss -- ${appended[*]}"

    log "INFO" "Running Stylelint check (storefront): ${cmd}"

    exec_npm_command "${cmd}"
}

# Stylelint fix (auto-fix violations)
# Args: JSON with paths (optional), scope (optional)
tool_stylelint_fix() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
    local scoped_config
    scoped_config=$(scope_get_tool_field stylelint config)

    local paths_json paths
    paths_json=$(echo "${args}" | jq -c '.paths // []')
    if ! paths=$(parse_paths_json "${paths_json}" ""); then
        printf '%s\n' "${paths}"
        return 1
    fi

    local -a appended=()
    [[ -n "${scoped_config}" ]] && appended+=("--config" "${scoped_config}")
    [[ -n "${paths}" ]] && appended+=("${paths}")

    if [[ ${#appended[@]} -eq 0 ]]; then
        local bare_cmd="npm run lint:scss-fix"
        log "INFO" "Running Stylelint fix (storefront): ${bare_cmd}"
        exec_npm_command "${bare_cmd}"
        return
    fi

    local body
    local gate_code=0
    body=$(npm_script_append_gate "lint:scss-fix") || gate_code=$?
    if [[ "${gate_code}" -ne 0 ]]; then
        printf '%s\n' "${body}"
        return 1
    fi

    local cmd="npm run lint:scss-fix -- ${appended[*]}"

    log "INFO" "Running Stylelint fix (storefront): ${cmd}"

    exec_npm_command "${cmd}"
}
