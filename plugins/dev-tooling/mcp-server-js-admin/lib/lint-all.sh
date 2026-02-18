#!/usr/bin/env bash
# Additional linting tools for Admin Tooling MCP Server
# Provides lint_all, lint_twig, and unit_setup MCP tools

# Run ALL lint checks (TypeScript, ESLint, Stylelint, Prettier)
# Uses npm run lint:all which runs all checks in sequence
tool_lint_all() {
    local cmd="npm run lint:all"

    log "INFO" "Running all lint checks (admin): ${cmd}"

    exec_npm_command "${cmd}"
}

# ESLint check for Twig templates (.html.twig files)
# Validates Admin Vue component templates
tool_lint_twig() {
    local cmd="npm run lint:twig"

    log "INFO" "Running Twig template linting (admin): ${cmd}"

    exec_npm_command "${cmd}"
}

# Regenerate component import resolver map for Jest
# Run this when tests fail with import/module resolution errors
tool_unit_setup() {
    local cmd="npm run unit-setup"

    log "INFO" "Running unit test setup (admin): ${cmd}"

    exec_npm_command "${cmd}"
}
