#!/usr/bin/env bash
# Additional linting tools for Admin Tooling MCP Server
# Provides lint_all, lint_twig, and unit_setup MCP tools

# tool_lint_all - runs TypeScript, ESLint, Stylelint, and Prettier via npm run lint:all.
tool_lint_all() {
    local cmd="npm run lint:all"

    log "INFO" "Running all lint checks (admin): ${cmd}"

    exec_npm_command "${cmd}"
}

# tool_lint_twig - ESLint check for Admin Vue Twig templates (.html.twig files) via npm run lint:twig.
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
