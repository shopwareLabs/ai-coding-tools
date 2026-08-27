#!/usr/bin/env bash
# plugin_create and plugin_setup tool implementations

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# Run console commands in order, stopping at the first one that fails so a
# later step never runs against the state a failed step left behind.
# Arguments:
#   $@ - the commands to run, in order
# Outputs:
#   Each command's output on stdout, and when one fails the message naming it
#   and its exit status followed by that command's output
# Returns:
#   0 when every command succeeded, 1 at the first failure
_run_plugin_steps() {
    local cmd output rc=0

    for cmd in "$@"; do
        output=$(exec_command "${cmd}") || rc=$?
        if [[ "${rc}" -ne 0 ]]; then
            printf '%s\n' "Plugin command failed at step '${cmd}' (exit ${rc}):"
            printf '%s\n' "${output}"
            return 1
        fi
        printf '%s\n' "${output}"
    done
}

# Scaffold a plugin skeleton, refresh the plugin list, then install and
# activate the result.
# Globals:
#   Reads the environment resolve_lifecycle_env resolves.
# Arguments:
#   $1 - tool arguments as JSON: plugin_name, plugin_namespace, and the
#        environment arguments resolve_lifecycle_env reads
# Outputs:
#   Each step's output on stdout, or the message naming why the call was
#   refused or which step failed
# Returns:
#   0 when all three steps succeeded, 1 on a refused argument or a failed step
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

    local guard
    if ! guard=$(assert_no_shell_hostile_chars "plugin_namespace" "${plugin_namespace}"); then
        printf '%s\n' "${guard}"
        return 1
    fi

    log "INFO" "plugin_create: name=${plugin_name} namespace=${plugin_namespace}"

    _run_plugin_steps \
        "bin/console plugin:create $(shell_quote_arg "${plugin_name}") $(shell_quote_arg "${plugin_namespace}")" \
        "bin/console plugin:refresh" \
        "bin/console plugin:install $(shell_quote_arg "${plugin_name}") --activate"
}

# Register an existing plugin from custom/plugins/ and activate it.
# Globals:
#   Reads the environment resolve_lifecycle_env resolves.
# Arguments:
#   $1 - tool arguments as JSON: plugin_name, and the environment arguments
#        resolve_lifecycle_env reads
# Outputs:
#   Each step's output on stdout, or the message naming why the call was
#   refused or which step failed
# Returns:
#   0 when both steps succeeded, 1 on a refused argument or a failed step
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

    if [[ ! "${plugin_name}" =~ ^[A-Z][a-zA-Z0-9]+$ ]]; then
        echo "Error: plugin_name must be PascalCase (e.g., SwagExample)"
        return 1
    fi

    log "INFO" "plugin_setup: name=${plugin_name}"

    _run_plugin_steps \
        "bin/console plugin:refresh" \
        "bin/console plugin:install $(shell_quote_arg "${plugin_name}") --activate"
}
