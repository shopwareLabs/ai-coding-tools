#!/usr/bin/env bash
# Build tool implementation for Storefront Tooling MCP Server
# Provides webpack_build MCP tool
# Note: "hot" mode (watch) is not supported - long-running processes hang MCP servers

# Webpack build (Storefront)
# Args: JSON with mode (optional: "development" or "production")
tool_webpack_build() {
    local args="$1"

    worktree_enter "${args}" || return 1

    resolve_core_scope "${args}" || return 1

    scope_assert_dependencies || return 1

    local mode
    mode=$(echo "${args}" | jq -r '.mode // "production"')

    # Map mode to npm script name
    local script_name
    case "${mode}" in
        development) script_name="development" ;;
        production|*) script_name="production" ;;
    esac

    local cmd="npm run ${script_name}"

    log "INFO" "Running Webpack build (storefront): ${cmd}"

    exec_npm_command "${cmd}"
}
