#!/usr/bin/env bash
# Build tool implementation for Storefront Tooling MCP Server
# Provides webpack_build MCP tool
# Note: "hot" mode (watch) is not supported - long-running processes hang MCP servers

# Webpack build (Storefront)
# Args: JSON with mode (optional: "development" or "production")
tool_webpack_build() {
    local args="$1"

    worktree_enter "${args}" || return 1

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    # default_scope is ignored: a plugin package defines none of the core scripts.
    if ! resolve_scope "${scope_arg:-shopware}"; then
        echo "Scope resolution error"
        return 1
    fi

    worktree_assert_dependencies || return 1

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
