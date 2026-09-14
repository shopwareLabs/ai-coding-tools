#!/usr/bin/env bash
# ludtwig tool implementation for Storefront Tooling MCP Server
# Provides ludtwig_check and ludtwig_fix MCP tools
#
# Both run from the project root through the composer scripts, not from the JS
# package directory. The composer script body is
# `cd ./src/Storefront/Resources/views; ludtwig .`, which contains `;` and can
# therefore not take appended arguments, so neither tool offers path scoping.

# Run ludtwig from the project root, unscoped.
# Both tools declare no parameter beyond "project_root" and reach their scope
# through this helper, so this is the single place their "project_root" can be
# resolved. Its stdout is the tool's stdout, which is what lets the banner be
# printed here.
# Args: $1 = composer script name, $2 = the tool call's arguments JSON
_ludtwig_run() {
    local composer_script="$1"
    local args="${2:-}"

    worktree_enter "${args}" || return 1

    # Pinned to the reserved scope rather than resolved from the call: a
    # default_scope in the configuration would otherwise move the run into a
    # plugin directory, and the composer script enters the core Storefront views
    # tree relative to wherever composer is invoked.
    if ! resolve_scope "shopware"; then
        echo "Scope resolution error"
        return 1
    fi

    # This server sets JS_CONTEXT, but both tools run composer, so the
    # dependency that has to be installed is the PHP one.
    worktree_assert_dependencies php || return 1

    local cmd="composer ${composer_script}"

    log "INFO" "Running ludtwig (storefront): ${cmd}"

    exec_command "${cmd}"
}

# ludtwig check (dry-run)
# Args: $1 = JSON arguments, carrying project_root only
tool_ludtwig_check() {
    _ludtwig_run "ludtwig:storefront" "${1:-}"
}

# ludtwig fix (auto-fix violations)
# Args: $1 = JSON arguments, carrying project_root only
tool_ludtwig_fix() {
    _ludtwig_run "ludtwig:storefront:fix" "${1:-}"
}
