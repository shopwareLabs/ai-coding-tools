#!/usr/bin/env bash
# install_dependencies tool implementation

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# Install the PHP and JavaScript dependencies the arguments select, in order.
# Globals:
#   Reads the environment resolve_lifecycle_env resolves.
# Arguments:
#   $1 - tool arguments as JSON: composer, administration, storefront and
#        update booleans, plus the environment arguments
#        resolve_lifecycle_env reads
# Outputs:
#   The output of every step run on stdout, and when a step fails the message
#   naming it and its exit status; nothing when no flag selects a step
# Returns:
#   0 when every selected step succeeded, 1 on a failed step or an
#   unresolvable environment
tool_install_dependencies() {
    local args="$1"

    if ! resolve_lifecycle_env "${args}"; then
        return 1
    fi

    local composer administration storefront update
    composer=$(echo "${args}" | jq -r '.composer // false' 2>/dev/null)
    administration=$(echo "${args}" | jq -r '.administration // false' 2>/dev/null)
    storefront=$(echo "${args}" | jq -r '.storefront // false' 2>/dev/null)
    update=$(echo "${args}" | jq -r '.update // false' 2>/dev/null)

    local npm_subcommand
    if [[ "${update}" == "true" ]]; then
        npm_subcommand="install"
    else
        npm_subcommand="clean-install"
    fi

    local commands=()

    if [[ "${composer}" == "true" ]]; then
        if [[ "${update}" == "true" ]]; then
            commands+=("composer update --no-interaction")
        else
            commands+=("composer install --no-interaction")
        fi
    fi

    if [[ "${administration}" == "true" && "${storefront}" == "true" && "${update}" != "true" ]]; then
        commands+=("composer init:js")
    else
        if [[ "${administration}" == "true" ]]; then
            commands+=("composer npm:admin -- ${npm_subcommand} --no-audit --prefer-offline")
        fi
        if [[ "${storefront}" == "true" ]]; then
            commands+=("composer npm:storefront -- ${npm_subcommand} --no-audit --prefer-offline")
            commands+=("bin/install-extension-npm")
        fi
    fi

    local cmd output rc=0
    for cmd in "${commands[@]+"${commands[@]}"}"; do
        log "INFO" "install_dependencies: ${cmd}"
        output=$(exec_command "${cmd}") || rc=$?
        if [[ "${rc}" -ne 0 ]]; then
            printf '%s\n' "install_dependencies failed at step '${cmd}' (exit ${rc}):"
            printf '%s\n' "${output}"
            return 1
        fi
        printf '%s\n' "${output}"
    done
}
