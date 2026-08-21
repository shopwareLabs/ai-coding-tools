#!/usr/bin/env bash
# Prettier tool implementation for Admin Tooling MCP Server
# Provides prettier_check and prettier_fix MCP tools
# Uses npm scripts: format (check) and format:fix (fix)
#
# The scoped --config override is the only appended argument, and it is gated
# on the script body being able to receive it.

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

    if [[ -n "${scoped_config}" ]]; then
        local body
        local gate_code=0
        body=$(npm_script_append_gate "format") || gate_code=$?
        if [[ "${gate_code}" -ne 0 ]]; then
            printf '%s\n' "${body}"
            return 1
        fi
        cmd="${cmd} -- --config ${scoped_config}"
    fi

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

    if [[ -n "${scoped_config}" ]]; then
        local body
        local gate_code=0
        body=$(npm_script_append_gate "format:fix") || gate_code=$?
        if [[ "${gate_code}" -ne 0 ]]; then
            printf '%s\n' "${body}"
            return 1
        fi
        cmd="${cmd} -- --config ${scoped_config}"
    fi

    log "INFO" "Running Prettier fix (admin): ${cmd}"

    exec_npm_command "${cmd}"
}
