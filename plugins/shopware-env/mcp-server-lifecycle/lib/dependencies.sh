#!/usr/bin/env bash
# install_dependencies tool implementation

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

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

    local output=""

    if [[ "${composer}" == "true" ]]; then
        local composer_cmd
        if [[ "${update}" == "true" ]]; then
            composer_cmd="composer update --no-interaction"
        else
            composer_cmd="composer install --no-interaction"
        fi
        log "INFO" "install_dependencies: ${composer_cmd}"
        output+=$(exec_command "${composer_cmd}")
        output+=$'\n'
    fi

    if [[ "${administration}" == "true" && "${storefront}" == "true" && "${update}" != "true" ]]; then
        log "INFO" "install_dependencies: composer init:js"
        output+=$(exec_command "composer init:js")
        output+=$'\n'
    else
        if [[ "${administration}" == "true" ]]; then
            log "INFO" "install_dependencies: composer npm:admin -- ${npm_subcommand} --no-audit --prefer-offline"
            output+=$(exec_command "composer npm:admin -- ${npm_subcommand} --no-audit --prefer-offline")
            output+=$'\n'
        fi
        if [[ "${storefront}" == "true" ]]; then
            log "INFO" "install_dependencies: composer npm:storefront -- ${npm_subcommand} --no-audit --prefer-offline"
            output+=$(exec_command "composer npm:storefront -- ${npm_subcommand} --no-audit --prefer-offline")
            output+=$'\n'
            log "INFO" "install_dependencies: bin/install-extension-npm"
            output+=$(exec_command "bin/install-extension-npm")
            output+=$'\n'
        fi
    fi

    printf '%s' "${output}"
}
