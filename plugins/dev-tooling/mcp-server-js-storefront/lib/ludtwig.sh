#!/usr/bin/env bash
# ludtwig tool implementation for Storefront Tooling MCP Server
# Provides ludtwig_check and ludtwig_fix MCP tools
#
# Both run from the project root through the composer scripts, not from the JS
# package directory. The composer script body is
# `cd ./src/Storefront/Resources/views; ludtwig .`, which contains `;` and can
# therefore not take appended arguments, so neither tool offers path scoping.

# Run ludtwig from the project root, unscoped.
# Args: $1 = composer script name
_ludtwig_run() {
    local composer_script="$1"

    # Pin the project root: SCOPE_CWD persists across tool calls in one server
    # process, and ludtwig always runs against the core Storefront views tree.
    if ! resolve_scope "shopware"; then
        echo "Scope resolution error"
        return 1
    fi

    local cmd="composer ${composer_script}"

    log "INFO" "Running ludtwig (storefront): ${cmd}"

    exec_command "${cmd}"
}

# ludtwig check (dry-run)
tool_ludtwig_check() {
    _ludtwig_run "ludtwig:storefront"
}

# ludtwig fix (auto-fix violations)
tool_ludtwig_fix() {
    _ludtwig_run "ludtwig:storefront:fix"
}
