#!/usr/bin/env bash
# Prettier tool implementation for Admin Tooling MCP Server
# Provides prettier_check and prettier_fix MCP tools
# Uses npm scripts: format (check) and format:fix (fix)

# Prettier check (dry-run)
# Uses npm run format which runs prettier --check with project config
tool_prettier_check() {
    local args="${1:-}"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
    local scoped_config
    scoped_config=$(scope_get_tool_field prettier config)

    local cmd="npm run format"
    [[ -n "${scoped_config}" ]] && cmd="${cmd} -- --config ${scoped_config}"

    log "INFO" "Running Prettier check (admin): ${cmd}"

    exec_npm_command "${cmd}"
}

# Prettier fix (auto-format files)
# Uses npm run format:fix which runs prettier --write with project config
tool_prettier_fix() {
    local args="${1:-}"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
    local scoped_config
    scoped_config=$(scope_get_tool_field prettier config)

    local cmd="npm run format:fix"
    [[ -n "${scoped_config}" ]] && cmd="${cmd} -- --config ${scoped_config}"

    log "INFO" "Running Prettier fix (admin): ${cmd}"

    exec_npm_command "${cmd}"
}
