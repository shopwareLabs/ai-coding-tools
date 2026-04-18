#!/usr/bin/env bash
# frontend_build_admin and frontend_build_storefront tool implementations

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# _run_console_step <step_name> <command>
# Runs a console command as part of a build chain. Aborts on failure.
_run_console_step() {
    local step_name="$1" cmd="$2"
    log "INFO" "frontend build [${step_name}]: ${cmd}"
    local output rc=0
    output=$(exec_command "${cmd}") || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        echo "Frontend build failed at step '${step_name}' (exit ${rc}):"
        echo "${output}"
        return 1
    fi
    echo "${output}"
}

tool_frontend_build_admin() {
    local args="$1"

    if ! resolve_lifecycle_env "${args}"; then
        return 1
    fi

    _run_console_step "bundle:dump" "bin/console bundle:dump" || return 1
    _run_console_step "feature:dump" "bin/console feature:dump" || return 1
    _run_console_step "framework:schema:dump" "bin/console framework:schema:dump" || return 1
    _run_console_step "build:js:admin" "composer build:js:admin" || return 1
    _run_console_step "assets:install" "bin/console assets:install" || return 1
}

tool_frontend_build_storefront() {
    local args="$1"

    if ! resolve_lifecycle_env "${args}"; then
        return 1
    fi

    _run_console_step "bundle:dump" "bin/console bundle:dump" || return 1
    _run_console_step "feature:dump" "bin/console feature:dump" || return 1
    _run_console_step "build:js:storefront" "composer build:js:storefront" || return 1
    _run_console_step "theme:compile" "bin/console theme:compile" || return 1
    _run_console_step "assets:install" "bin/console assets:install" || return 1
}
