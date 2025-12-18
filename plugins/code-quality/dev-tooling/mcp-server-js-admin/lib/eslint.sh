#!/usr/bin/env bash
# ESLint tool implementation for Admin Tooling MCP Server
# Provides eslint_check and eslint_fix MCP tools

# ESLint check (dry-run)
# Args: JSON with paths (optional), output_format (optional)
tool_eslint_check() {
    local args="$1"

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

    local cmd="npm run lint -- ${flags[*]} ${paths}"

    log "INFO" "Running ESLint check (admin): ${cmd}"

    exec_npm_command "${cmd}"
}

# ESLint fix (auto-fix violations)
# Args: JSON with paths (optional)
tool_eslint_fix() {
    local args="$1"

    local paths_json paths
    paths_json=$(echo "${args}" | jq -c '.paths // []')
    paths=$(parse_paths_json "${paths_json}" ".")

    local cmd="npm run lint:fix -- ${paths}"

    log "INFO" "Running ESLint fix (admin): ${cmd}"

    exec_npm_command "${cmd}"
}
