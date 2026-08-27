#!/usr/bin/env bash
# frontend_build_admin and frontend_build_storefront tool implementations

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# Run a console command as part of a build chain. Aborts on failure.
# Arguments:
#   $1 - step name, used in the failure message
#   $2 - command to run in the resolved environment
# Outputs:
#   The command's output on stdout, preceded by a message naming the step and
#   its exit status when it fails
# Returns:
#   0 when the step succeeded, 1 otherwise
_run_console_step() {
    local step_name="$1" cmd="$2"
    log "INFO" "frontend build [${step_name}]: ${cmd}"
    local output rc=0
    output=$(exec_command "${cmd}") || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf '%s\n' "Frontend build failed at step '${step_name}' (exit ${rc}):"
        printf '%s\n' "${output}"
        return 1
    fi
    printf '%s\n' "${output}"
}

# Run the full Administration build chain.
# Globals:
#   Reads the environment resolve_lifecycle_env resolves.
# Arguments:
#   $1 - tool arguments as JSON: the environment arguments
#        resolve_lifecycle_env reads
# Outputs:
#   Each step's output on stdout, or the message naming the failed step
# Returns:
#   0 when every step succeeded, 1 on a failed step or an unresolvable
#   environment
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

# Run the full Storefront build chain.
# Globals:
#   Reads the environment resolve_lifecycle_env resolves.
# Arguments:
#   $1 - tool arguments as JSON: the environment arguments
#        resolve_lifecycle_env reads
# Outputs:
#   Each step's output on stdout, or the message naming the failed step
# Returns:
#   0 when every step succeeded, 1 on a failed step or an unresolvable
#   environment
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
