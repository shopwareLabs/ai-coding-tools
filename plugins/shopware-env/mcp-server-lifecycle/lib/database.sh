#!/usr/bin/env bash
# database_install and database_reset tool implementations

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# Drop and recreate the database with the basic setup applied.
# Globals:
#   Reads the environment resolve_lifecycle_env resolves.
# Arguments:
#   $1 - tool arguments as JSON: the environment arguments
#        resolve_lifecycle_env reads
# Outputs:
#   The command's output on stdout
# Returns:
#   0 when the setup succeeded, 1 on a failed command or an unresolvable
#   environment
_run_database_setup() {
    local args="$1"

    if ! resolve_lifecycle_env "${args}"; then
        return 1
    fi

    local cmd="bin/console system:install --drop-database --basic-setup --force --no-assign-theme"
    log "INFO" "database setup: ${cmd}"
    exec_command "${cmd}"
}

# Set up the database for the first time.
# Arguments:
#   $1 - tool arguments as JSON
# Outputs:
#   The command's output on stdout
# Returns:
#   0 when the setup succeeded, 1 otherwise
tool_database_install() {
    _run_database_setup "$1"
}

# Wipe an existing database and rebuild it to a clean state.
# Arguments:
#   $1 - tool arguments as JSON
# Outputs:
#   The command's output on stdout
# Returns:
#   0 when the reset succeeded, 1 otherwise
tool_database_reset() {
    _run_database_setup "$1"
}
