#!/usr/bin/env bash
# plugin_create and plugin_setup tool implementations

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

tool_plugin_create() {
    local args="$1"

    if ! resolve_lifecycle_env "${args}"; then
        return 1
    fi

    local plugin_name plugin_namespace
    plugin_name=$(echo "${args}" | jq -r '.plugin_name // empty' 2>/dev/null)
    plugin_namespace=$(echo "${args}" | jq -r '.plugin_namespace // empty' 2>/dev/null)

    if [[ -z "${plugin_name}" ]]; then
        echo "Error: 'plugin_name' parameter is required"
        return 1
    fi
    if [[ -z "${plugin_namespace}" ]]; then
        echo "Error: 'plugin_namespace' parameter is required"
        return 1
    fi

    if [[ ! "${plugin_name}" =~ ^[A-Z][a-zA-Z0-9]+$ ]]; then
        echo "Error: plugin_name must be PascalCase (e.g., SwagExample)"
        return 1
    fi

    log "INFO" "plugin_create: name=${plugin_name} namespace=${plugin_namespace}"

    exec_command "bin/console plugin:create '${plugin_name}' '${plugin_namespace}'"
    exec_command "bin/console plugin:refresh"
    exec_command "bin/console plugin:install ${plugin_name} --activate"
}

tool_plugin_setup() {
    local args="$1"

    if ! resolve_lifecycle_env "${args}"; then
        return 1
    fi

    local plugin_name
    plugin_name=$(echo "${args}" | jq -r '.plugin_name // empty' 2>/dev/null)

    if [[ -z "${plugin_name}" ]]; then
        echo "Error: 'plugin_name' parameter is required"
        return 1
    fi

    log "INFO" "plugin_setup: name=${plugin_name}"

    exec_command "bin/console plugin:refresh"
    exec_command "bin/console plugin:install ${plugin_name} --activate"
}
