#!/usr/bin/env bash
# TypeScript tool implementation for Admin Tooling MCP Server
# Provides tsc_check MCP tool
# Uses npm script: lint:types (runs tsc with project config)

# TypeScript type checking
# Uses npm run lint:types which runs tsc with project tsconfig
tool_tsc_check() {
    local args="${1:-}"

    worktree_enter "${args}" || return 1

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    # default_scope is ignored: a plugin package defines none of the core scripts.
    if ! resolve_scope "${scope_arg:-shopware}"; then
        echo "Scope resolution error"
        return 1
    fi

    worktree_assert_dependencies || return 1

    local scoped_config
    scope_tool_field_or_refuse scoped_config tsc config || return 1

    local cmd="npm run lint:types"

    if [[ -n "${scoped_config}" ]]; then
        local guard
        if ! guard=$(assert_no_shell_hostile_chars "TypeScript project configuration" "${scoped_config}"); then
            printf '%s\n' "${guard}"
            return 1
        fi

        local body
        local gate_code=0
        body=$(npm_script_append_gate "lint:types") || gate_code=$?
        if [[ "${gate_code}" -ne 0 ]]; then
            printf '%s\n' "${body}"
            return 1
        fi
        cmd="${cmd} -- --project $(shell_quote_arg "${scoped_config}")"
    fi

    log "INFO" "Running TypeScript check (admin): ${cmd}"

    exec_npm_command "${cmd}"
}
