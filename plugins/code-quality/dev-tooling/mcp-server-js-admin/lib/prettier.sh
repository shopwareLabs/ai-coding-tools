#!/usr/bin/env bash
# Prettier tool implementation for Admin Tooling MCP Server
# Provides prettier_check and prettier_fix MCP tools
# Uses npm scripts: format (check) and format:fix (fix)

# Prettier check (dry-run)
# Uses npm run format which runs prettier --check with project config
tool_prettier_check() {
    local cmd="npm run format"

    log "INFO" "Running Prettier check (admin): ${cmd}"

    exec_npm_command "${cmd}"
}

# Prettier fix (auto-format files)
# Uses npm run format:fix which runs prettier --write with project config
tool_prettier_fix() {
    local cmd="npm run format:fix"

    log "INFO" "Running Prettier fix (admin): ${cmd}"

    exec_npm_command "${cmd}"
}
