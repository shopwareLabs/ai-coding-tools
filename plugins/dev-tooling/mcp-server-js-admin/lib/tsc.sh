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
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    scope_assert_dependencies || return 1

    local scoped_config
    scope_tool_field_or_refuse scoped_config tsc config || return 1

    # A plugin package normally defines no "lint:types"; npm fails with "Missing
    # script" only after the run started, so the script is probed first.
    if [[ "${SCOPE_NAME}" != "shopware" ]]; then
        local body_code=0
        npm_script_body "lint:types" >/dev/null || body_code=$?
        if [[ "${body_code}" -eq 1 ]]; then
            printf '%s\n' "Refusing to run TypeScript check under scope \"${SCOPE_NAME}\": the package defines no \"lint:types\" npm script. Pass scope \"shopware\" to check the core Administration package."
            return 1
        fi
        if [[ "${body_code}" -ne 0 ]]; then
            printf '%s\n' "Could not read npm script \"lint:types\" from package.json under scope \"${SCOPE_NAME}\"; see the server log for the failed probe. Pass scope \"shopware\" to check the core Administration package."
            return 1
        fi
    fi

    local cmd="npm run lint:types"

    if [[ -n "${scoped_config}" ]]; then
        local quoted_config
        scope_config_arg_or_refuse quoted_config "TypeScript project configuration" "${scoped_config}" || return 1

        local body
        local gate_code=0
        body=$(npm_script_append_gate "lint:types") || gate_code=$?
        if [[ "${gate_code}" -ne 0 ]]; then
            printf '%s\n' "${body}"
            return 1
        fi
        cmd="${cmd} -- --project ${quoted_config}"
    fi

    log "INFO" "Running TypeScript check (admin): ${cmd}"

    exec_npm_command "${cmd}"
}
