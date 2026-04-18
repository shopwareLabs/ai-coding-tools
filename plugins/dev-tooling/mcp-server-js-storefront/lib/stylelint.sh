#!/usr/bin/env bash
# Stylelint tool implementation for Storefront Tooling MCP Server
# Provides stylelint_check and stylelint_fix MCP tools

# Stylelint check (dry-run)
# Args: JSON with paths (optional), output_format (optional)
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
    paths=$(parse_paths_json "${paths_json}" "'**/*.scss'")

    local output_format
    output_format=$(echo "${args}" | jq -r '.output_format // "string"')

    local -a flags=()

    case "${output_format}" in
        json) flags+=("-f" "json") ;;
        compact) flags+=("-f" "compact") ;;
        string|*) flags+=("-f" "string") ;;
    esac

    [[ -n "${scoped_config}" ]] && flags+=("--config" "${scoped_config}")

    local cmd="npm run lint:scss -- ${flags[*]} ${paths}"

    log "INFO" "Running Stylelint check (storefront): ${cmd}"

    exec_npm_command "${cmd}"
}

# Stylelint fix (auto-fix violations)
# Args: JSON with paths (optional)
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
    paths=$(parse_paths_json "${paths_json}" "'**/*.scss'")

    local -a flags=()
    [[ -n "${scoped_config}" ]] && flags+=("--config" "${scoped_config}")

    local cmd="npm run lint:scss-fix -- ${flags[*]} ${paths}"

    log "INFO" "Running Stylelint fix (storefront): ${cmd}"

    exec_npm_command "${cmd}"
}
