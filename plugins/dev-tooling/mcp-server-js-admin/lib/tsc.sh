#!/usr/bin/env bash
# TypeScript tool implementation for Admin Tooling MCP Server
# Provides tsc_check MCP tool
# Uses npm script: lint:types (runs tsc with project config)

# TypeScript type checking
# Uses npm run lint:types which runs tsc with project tsconfig
tool_tsc_check() {
    local args="${1:-}"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
    local scoped_config
    scoped_config=$(scope_get_tool_field tsc config)

    local cmd="npm run lint:types"

    if [[ -n "${scoped_config}" ]]; then
        local body
        local gate_code=0
        body=$(npm_script_append_gate "lint:types") || gate_code=$?
        if [[ "${gate_code}" -ne 0 ]]; then
            printf '%s\n' "${body}"
            return 1
        fi
        cmd="${cmd} -- --project ${scoped_config}"
    fi

    log "INFO" "Running TypeScript check (admin): ${cmd}"

    exec_npm_command "${cmd}"
}
