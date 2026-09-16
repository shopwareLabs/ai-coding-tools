#!/usr/bin/env bash
# Worktree dependency provisioning for the Storefront JS MCP server.
#
# A linked worktree holds tracked files only, so the launch tree's
# node_modules is not in it and every npm-backed tool refuses until it exists.
# This tool installs it in the Storefront package directory through the same
# environment wrapping the refusing tools use — under a container environment
# the install has to run inside the container at the mapped path, which a
# session on the host cannot do on its own.
#
# ludtwig is the one tool on this server it does not provision for: ludtwig
# runs composer, so its vendor/ comes from worktree_prepare on the php-tooling
# server.
#
# The scope is resolved here, unlike the PHP copy: the npm install and the JS
# dependency gate both derive their directory through get_js_workdir, so under
# a scope they converge on the same package directory.

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# tool_worktree_prepare - MCP tool function
tool_worktree_prepare() {
    local args="${1:-}"

    worktree_enter "${args}" || return 1

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    # Deliberately no worktree_assert_dependencies: this tool installs what
    # that gate demands, so running the gate here would refuse every call the
    # tool exists for.
    worktree_prepare_execute "npm ci" exec_npm_command "storefront js"
}
