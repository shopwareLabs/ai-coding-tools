#!/usr/bin/env bash
# TypeScript tool implementation for Admin Tooling MCP Server
# Provides tsc_check MCP tool
# Uses npm script: lint:types (runs tsc with project config)

# TypeScript type checking
# Uses npm run lint:types which runs tsc with project tsconfig
tool_tsc_check() {
    local cmd="npm run lint:types"

    log "INFO" "Running TypeScript check (admin): ${cmd}"

    exec_npm_command "${cmd}"
}
