#!/usr/bin/env bash
# Worktree dependency provisioning for the Administration JS MCP server.
#
# A linked worktree holds tracked files only, so the launch tree's
# node_modules is not in it and every npm-backed tool refuses until it exists.
# This tool installs it in the Administration package directory through the
# same environment wrapping the refusing tools use — under a container
# environment the install has to run inside the container at the mapped path,
# which a session on the host cannot do on its own.
#
# Jest additionally needs two generated artifacts after this install: the
# component import resolver map (unit_setup) and the gitignored
# test/_mocks_/entity-schema.json, which unit_setup does NOT regenerate — it
# comes from console_run on the php-tooling server
# (`framework:schema -s entity-schema <that path>`).
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
    worktree_prepare_execute "npm ci" exec_npm_command "admin js"
}
