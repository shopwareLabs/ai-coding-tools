#!/usr/bin/env bash
# ESLint tool implementation for Storefront Tooling MCP Server
# Provides eslint_check and eslint_fix MCP tools

# ESLint check (dry-run)
# Args: JSON with paths (optional), output_format (optional)
tool_eslint_check() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
    local scoped_config
    scoped_config=$(scope_get_tool_field eslint config)

    local paths_json paths
    paths_json=$(echo "${args}" | jq -c '.paths // []')
    paths=$(parse_paths_json "${paths_json}" ".")

    local output_format
    output_format=$(echo "${args}" | jq -r '.output_format // "stylish"')

    local -a flags=()

    case "${output_format}" in
        json) flags+=("-f" "json") ;;
        compact) flags+=("-f" "compact") ;;
        stylish|*) flags+=("-f" "stylish") ;;
    esac

    [[ -n "${scoped_config}" ]] && flags+=("--config" "${scoped_config}")

    local cmd="npm run lint:js -- ${flags[*]} ${paths}"

    log "INFO" "Running ESLint check (storefront): ${cmd}"

    exec_npm_command "${cmd}"
}

# ESLint fix (auto-fix violations)
# Args: JSON with paths (optional)
tool_eslint_fix() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
    local scoped_config
    scoped_config=$(scope_get_tool_field eslint config)

    local paths_json paths
    paths_json=$(echo "${args}" | jq -c '.paths // []')
    paths=$(parse_paths_json "${paths_json}" ".")

    local -a flags=()
    [[ -n "${scoped_config}" ]] && flags+=("--config" "${scoped_config}")

    local cmd="npm run lint:js:fix -- ${flags[*]} ${paths}"

    log "INFO" "Running ESLint fix (storefront): ${cmd}"

    exec_npm_command "${cmd}"
}
