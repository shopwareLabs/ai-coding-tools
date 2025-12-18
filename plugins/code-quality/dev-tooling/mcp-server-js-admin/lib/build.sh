#!/usr/bin/env bash
# Build tool implementation for Admin Tooling MCP Server
# Provides vite_build MCP tool

# Vite build (Administration)
# Args: JSON with mode (optional: "development" or "production")
tool_vite_build() {
    local args="$1"

    local mode
    mode=$(echo "${args}" | jq -r '.mode // "production"')

    local -a flags=()

    case "${mode}" in
        development) flags+=("--mode" "development") ;;
        production|*) flags+=("--mode" "production") ;;
    esac

    local cmd="npm run build"
    if [[ ${#flags[@]} -gt 0 ]]; then
        cmd="${cmd} -- ${flags[*]}"
    fi

    log "INFO" "Running Vite build (admin): ${cmd}"

    exec_npm_command "${cmd}"
}
