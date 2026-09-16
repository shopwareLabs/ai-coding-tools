#!/usr/bin/env bash
# Worktree dependency provisioning for the PHP MCP server.
#
# A linked worktree holds tracked files only, so the launch tree's vendor/ is
# not in it and every composer-backed tool refuses until it exists. This tool
# installs it through the same environment wrapping the refusing tools use —
# under a container environment the install has to run inside the container at
# the mapped path, which a session on the host cannot do on its own. A vendor/
# symlinked from the launch tree is not an alternative: composer's generated
# autoloaders derive their base directory from `__DIR__`, which resolves
# through the symlink, so the worktree would silently autoload the launch
# tree's classes.

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# tool_worktree_prepare - MCP tool function
tool_worktree_prepare() {
    local args="${1:-}"

    worktree_enter "${args}" || return 1

    # Deliberately no scope resolution and no worktree_assert_dependencies:
    # this tool installs what that gate demands, at the directory the gate
    # checks — the effective root. A resolved scope would send the install
    # into the scope's cwd while the gate keeps measuring the root, so the
    # refusal's named remedy could never clear the refusal.
    worktree_prepare_execute "composer install --no-interaction" exec_command "php"
}
