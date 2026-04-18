#!/usr/bin/env bash
# database_install and database_reset tool implementations

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

_run_database_setup() {
    local args="$1"

    if ! resolve_lifecycle_env "${args}"; then
        return 1
    fi

    local cmd="bin/console system:install --drop-database --basic-setup --force --no-assign-theme"
    log "INFO" "database setup: ${cmd}"
    exec_command "${cmd}"
}

tool_database_install() {
    _run_database_setup "$1"
}

tool_database_reset() {
    _run_database_setup "$1"
}
