#!/usr/bin/env bash
# Symfony console command tool implementation for MCP server

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

# tool_console_run - MCP tool function
# Args: $1 = JSON arguments
# Returns: Console command output
tool_console_run() {
    local args="$1"

    local default_env default_verbosity default_no_debug default_no_interaction
    default_env=$(_get_config_value ".console.env")
    default_verbosity=$(_get_config_value ".console.verbosity")
    default_no_debug=$(_get_config_value ".console.no_debug")
    default_no_interaction=$(_get_config_value ".console.no_interaction")

    local parsed
    parsed=$(echo "${args}" | jq -c '{
        command: (.command // null),
        arguments: (.arguments // []),
        options: (.options // {}),
        env: (.env // null),
        verbosity: (.verbosity // null),
        no_debug: (.no_debug // null),
        no_interaction: (.no_interaction // null)
    }' 2>/dev/null || echo '{"command":null,"arguments":[],"options":{},"env":null,"verbosity":null,"no_debug":null,"no_interaction":null}')

    local command arguments_json options_json env verbosity no_debug no_interaction
    command=$(echo "${parsed}" | jq -r '.command // empty')
    arguments_json=$(echo "${parsed}" | jq -c '.arguments')
    options_json=$(echo "${parsed}" | jq -c '.options')
    env=$(echo "${parsed}" | jq -r '.env // empty')
    verbosity=$(echo "${parsed}" | jq -r '.verbosity // empty')
    no_debug=$(echo "${parsed}" | jq -r '.no_debug // empty')
    no_interaction=$(echo "${parsed}" | jq -r '.no_interaction // empty')

    if [[ -z "${command}" ]]; then
        echo "Error: 'command' parameter is required"
        return 1
    fi

    # Validate command name format (security: prevent injection)
    if [[ ! "${command}" =~ ^[a-zA-Z0-9:_-]+$ ]]; then
        echo "Error: Invalid command name format. Only alphanumeric, colons, underscores, and hyphens allowed."
        return 1
    fi

    [[ -z "${env}" ]] && env="${default_env}"
    [[ -z "${verbosity}" ]] && verbosity="${default_verbosity}"
    [[ -z "${no_debug}" && -n "${default_no_debug}" ]] && no_debug="${default_no_debug}"
    [[ -z "${no_interaction}" && -n "${default_no_interaction}" ]] && no_interaction="${default_no_interaction}"

    local -a arg_array=()
    if [[ "${arguments_json}" != "[]" ]]; then
        while IFS= read -r a; do
            [[ -n "${a}" ]] && arg_array+=("${a}")
        done < <(echo "${arguments_json}" | jq -r '.[]' 2>/dev/null)
    fi

    log "INFO" "Console run: command='${command}' args='${arg_array[*]:-}' env='${env}' verbosity='${verbosity}'"

    local -a flags=()

    flags+=("${command}")

    [[ ${#arg_array[@]} -gt 0 ]] && flags+=("${arg_array[@]}")

    [[ -n "${env}" ]] && flags+=("--env=${env}")

    case "${verbosity}" in
        quiet)        flags+=("-q") ;;
        verbose)      flags+=("-v") ;;
        very-verbose) flags+=("-vv") ;;
        debug)        flags+=("-vvv") ;;
        # normal = no flag
    esac

    [[ "${no_debug}" == "true" ]] && flags+=("--no-debug")
    [[ "${no_interaction}" == "true" ]] && flags+=("--no-interaction")

    if [[ "${options_json}" != "{}" ]]; then
        while IFS= read -r key; do
            local value value_type
            value=$(echo "${options_json}" | jq -r --arg k "${key}" '.[$k]')
            value_type=$(echo "${options_json}" | jq -r --arg k "${key}" '.[$k] | type')

            case "${value_type}" in
                boolean)
                    # Boolean true = --flag, false = skip
                    [[ "${value}" == "true" ]] && flags+=("--${key}")
                    ;;
                string)
                    # String value = --key=value
                    flags+=("--${key}=${value}")
                    ;;
                array)
                    # Array = multiple --key=value entries
                    while IFS= read -r arr_val; do
                        flags+=("--${key}=${arr_val}")
                    done < <(echo "${options_json}" | jq -r --arg k "${key}" '.[$k][]' 2>/dev/null)
                    ;;
            esac
        done < <(echo "${options_json}" | jq -r 'keys[]' 2>/dev/null)
    fi

    local cmd="bin/console"
    [[ ${#flags[@]} -gt 0 ]] && cmd="${cmd} ${flags[*]}"

    exec_command "${cmd}"
}

# _format_console_list_llm - Format JSON output for LLM consumption
# Args: $1 = raw JSON output from bin/console list --format=json
# Returns: Concise grouped output optimized for LLM
_format_console_list_llm() {
    local raw_json="$1"

    # Extract simplified command list grouped by namespace
    # Filter out hidden commands, group by namespace prefix, format as readable list
    echo "${raw_json}" | jq -r '
        .commands
        | map(select(.hidden != true))
        | group_by(.name | split(":")[0])
        | map({
            namespace: (.[0].name | split(":")[0]),
            commands: map({name: .name, description: .description})
        })
        | .[]
        | "[\(.namespace)]\n" + (.commands | map("  \(.name): \(.description)") | join("\n"))
    ' 2>/dev/null
}

# tool_console_list - MCP tool function
# Args: $1 = JSON arguments
# Returns: List of available console commands
tool_console_list() {
    local args="$1"

    local parsed
    parsed=$(echo "${args}" | jq -c '{
        namespace: (.namespace // null),
        format: (.format // "llm")  # llm is the default format
    }' 2>/dev/null || echo '{"namespace":null,"format":"llm"}')

    local namespace format
    namespace=$(echo "${parsed}" | jq -r '.namespace // empty')
    format=$(echo "${parsed}" | jq -r '.format')

    # Validate namespace format (security: prevent injection)
    if [[ -n "${namespace}" && ! "${namespace}" =~ ^[a-zA-Z0-9:_-]+$ ]]; then
        echo "Error: Invalid namespace format. Only alphanumeric, colons, underscores, and hyphens allowed."
        return 1
    fi

    log "INFO" "Console list: namespace='${namespace}' format='${format}'"

    # Non-LLM formats - pass through to Symfony
    if [[ "${format}" != "llm" ]]; then
        local -a flags=("list")
        [[ -n "${namespace}" ]] && flags+=("${namespace}")
        flags+=("--format=${format}")
        exec_command "bin/console ${flags[*]}"
        return
    fi

    # LLM format - fetch JSON and post-process
    local -a flags=("list")
    [[ -n "${namespace}" ]] && flags+=("${namespace}")
    flags+=("--format=json")

    local raw_output
    raw_output=$(exec_command "bin/console ${flags[*]}")

    _format_console_list_llm "${raw_output}"
}
