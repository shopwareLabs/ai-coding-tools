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

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    # Deliberately no worktree_assert_dependencies: this tool installs what
    # that gate demands, so running the gate here would refuse every call the
    # tool exists for.
    local cmd="composer install --no-interaction"

    log "INFO" "Preparing dependencies (php): ${cmd}"

    # An install prints hundreds of per-package lines nobody acts on when it
    # succeeds, so a success returns a summary and a failure returns everything.
    local output rc=0
    output=$(exec_command "${cmd}" 2>&1) || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf '%s\n' "${output}"
        return "${rc}"
    fi

    local total
    total=$(printf '%s\n' "${output}" | wc -l | tr -d ' ')
    printf '%s\n' "composer install completed. ${total} lines of installer output suppressed; last 3:"
    printf '%s\n' "${output}" | tail -n 3
}
