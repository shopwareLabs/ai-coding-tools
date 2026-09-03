#!/usr/bin/env bash
# Symfony console command tool implementation for MCP server

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

# _refuse_linebreak_args <json args>
# A line break inside a string value bypasses the downstream shell-hostile-char
# guard: jq -r re-splits it into separate tokens before that guard runs, and
# command substitution silently strips a trailing one. Refuse here, before any
# value is extracted from the JSON.
# Stdout: the refusal message when a line break is found
# Returns: 1 when refused, 0 otherwise (malformed JSON is left to downstream handling)
_refuse_linebreak_args() {
    local args="$1"
    if echo "${args}" | jq -e 'any((.. | strings), (.. | objects | keys[]); contains("\n") or contains("\r"))' >/dev/null 2>&1; then
        printf '%s\n' "Refusing to run: arguments contain a line break, which cannot be embedded in a single command."
        return 1
    fi
    return 0
}

# _console_resolve_output_file <value>
# Normalize and vet the caller's "output_file" value. The length cap lives here
# because the vendored validator enforces "pattern" but not "maxLength".
# The value is used host-side only and never becomes part of the wrapped
# command, so it needs no shell quoting.
# Stdout: the resolved absolute path, or the refusal message
# Returns: 0 when the path is usable, 1 when refused
_console_resolve_output_file() {
    local value="$1"

    local bytes
    bytes=$(printf '%s' "${value}" | wc -c | tr -d ' ')
    if [[ "${bytes}" -gt 4096 ]]; then
        printf '%s\n' "Refusing to run: \"output_file\" is longer than 4096 bytes (${bytes})."
        return 1
    fi

    # A leading dash reads as an option to every tool that later touches the
    # path, so it is pinned to the current directory instead.
    case "${value}" in
        -*) value="./${value}" ;;
    esac

    local resolved="${value}"
    if [[ "${resolved}" != /* ]]; then
        resolved="${PWD}/${resolved}"
    fi

    if [[ -L "${resolved}" ]]; then
        printf '%s\n' "Refusing to run: \"output_file\" \"${resolved}\" exists as a symbolic link."
        return 1
    fi

    if [[ -e "${resolved}" && ! -f "${resolved}" ]]; then
        local kind="not a regular file"
        if [[ -d "${resolved}" ]]; then
            kind="a directory"
        fi
        printf '%s\n' "Refusing to run: \"output_file\" \"${resolved}\" exists as ${kind}."
        return 1
    fi

    printf '%s\n' "${resolved}"
}

# _console_run_to_file <command> <resolved target path>
# Run the wrapped command with stdout captured to the target file and stderr
# kept separate, so the file holds the raw output and the response holds only a
# summary of it. exec_command merges both streams with 2>&1, which is why this
# path builds on wrap_command directly instead.
# Stdout: the summary plus the filtered stderr, or the failure report
# Returns: the command's exit status
_console_run_to_file() {
    local cmd="$1"
    local target="$2"

    local parent
    parent=$(dirname -- "${target}")
    if ! mkdir -p -- "${parent}"; then
        printf '%s\n' "Refusing to run: could not create the parent directory of \"output_file\": ${parent}"
        return 1
    fi

    local wrapped
    wrapped=$(wrap_command "${cmd}") || {
        printf '%s\n' "${wrapped}"
        return 1
    }

    log "INFO" "Executing: ${wrapped}"

    local tmp
    if ! tmp=$(mktemp "${target}.XXXXXX"); then
        printf '%s\n' "Refusing to run: could not create a temporary file next to \"output_file\": ${target}"
        return 1
    fi

    local err_file
    if ! err_file=$(mktemp); then
        rm -f -- "${tmp}"
        printf '%s\n' "Refusing to run: could not create a temporary file for the command's stderr."
        return 1
    fi

    local exit_code=0
    # The child must not inherit the server's stdin: it is the client's
    # JSON-RPC protocol pipe, and a stdin-reading tool child would block on
    # it forever instead of seeing EOF.
    # The eval runs in a subshell so that an `exit` reached inside the wrapped
    # command ends that subshell rather than the server; exec_command gets the
    # same containment from the command substitution it assigns through.
    ( eval "${wrapped}" ) </dev/null >"${tmp}" 2>"${err_file}" || exit_code=$?

    local stderr_text
    stderr_text=$(_filter_env_noise < "${err_file}")
    rm -f -- "${err_file}"

    log "INFO" "Command exit code: ${exit_code}"

    if [[ "${exit_code}" -ne 0 ]]; then
        # A failed command's stdout is diagnostic rather than payload, so it
        # goes into the response and the target file stays as it was. The file
        # is streamed rather than read into a variable, because a command
        # substitution would drop its trailing blank lines.
        printf '%s\n' "Command failed with exit status ${exit_code}; \"${target}\" was not written."
        cat -- "${tmp}"
        # Command substitution drops a trailing newline, so a non-empty result
        # here means the captured stdout did not end in one and the stderr
        # below would otherwise run onto its last line.
        local last_byte
        last_byte=$(tail -c 1 < "${tmp}")
        rm -f -- "${tmp}"
        if [[ -n "${last_byte}" ]]; then
            printf '\n'
        fi
        if [[ -n "${stderr_text}" ]]; then
            printf '%s\n' "${stderr_text}"
        fi
        return "${exit_code}"
    fi

    local bytes
    bytes=$(wc -c < "${tmp}" | tr -d ' ')

    if ! mv -- "${tmp}" "${target}"; then
        rm -f -- "${tmp}"
        printf '%s\n' "Command succeeded but its output could not be moved onto \"${target}\"."
        return 1
    fi

    printf '%s\n' "Wrote stdout to ${target}"
    printf '%s\n' "Bytes written: ${bytes}"
    printf '%s\n' "Exit status: ${exit_code}"
    if [[ -n "${stderr_text}" ]]; then
        printf '%s\n' "${stderr_text}"
    fi

    return 0
}

# tool_console_run - MCP tool function
# Args: $1 = JSON arguments
# Returns: Console command output
tool_console_run() {
    local args="$1"

    _refuse_linebreak_args "${args}" || return 1

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    local default_env default_verbosity default_no_debug default_no_interaction
    default_env=$(_get_config_value ".console.env")
    default_verbosity=$(_get_config_value ".console.verbosity")
    default_no_debug=$(_get_config_value ".console.no_debug")
    default_no_interaction=$(_get_config_value ".console.no_interaction")

    local parsed
    if ! parsed=$(echo "${args}" | jq -c '{
        command: (.command // null),
        arguments: (.arguments // []),
        options: (.options // {}),
        env: (.env // null),
        verbosity: (.verbosity // null),
        no_debug: (.no_debug // null),
        no_interaction: (.no_interaction // null),
        output_file: (.output_file // null)
    }' 2>/dev/null); then
        printf '%s\n' "Refusing to run: could not parse arguments as JSON: ${args}"
        return 1
    fi

    local command arguments_json options_json env verbosity no_debug no_interaction output_file
    command=$(echo "${parsed}" | jq -r '.command // empty')
    arguments_json=$(echo "${parsed}" | jq -c '.arguments')
    options_json=$(echo "${parsed}" | jq -c '.options')
    env=$(echo "${parsed}" | jq -r '.env // empty')
    verbosity=$(echo "${parsed}" | jq -r '.verbosity // empty')
    no_debug=$(echo "${parsed}" | jq -r '.no_debug // empty')
    no_interaction=$(echo "${parsed}" | jq -r '.no_interaction // empty')
    output_file=$(echo "${parsed}" | jq -r '.output_file // empty')

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

    local guard
    if [[ ${#arg_array[@]} -gt 0 ]] && ! guard=$(assert_no_shell_hostile_chars "console argument" "${arg_array[@]}"); then
        printf '%s\n' "${guard}"
        return 1
    fi
    if [[ -n "${env}" ]] && ! guard=$(assert_no_shell_hostile_chars "console environment" "${env}"); then
        printf '%s\n' "${guard}"
        return 1
    fi

    local resolved_output_file=""
    if [[ -n "${output_file}" ]] && ! resolved_output_file=$(_console_resolve_output_file "${output_file}"); then
        printf '%s\n' "${resolved_output_file}"
        return 1
    fi

    log "INFO" "Console run: command='${command}' args='${arg_array[*]:-}' env='${env}' verbosity='${verbosity}' output_file='${resolved_output_file}'"

    local -a flags=()

    # The command name passed the character allowlist above, so it needs no
    # further guard; it is still quoted so the wrappers see one argument.
    flags+=("$(shell_quote_arg "${command}")")

    local a
    for a in "${arg_array[@]+"${arg_array[@]}"}"; do
        flags+=("$(shell_quote_arg "${a}")")
    done

    [[ -n "${env}" ]] && flags+=("--env=$(shell_quote_arg "${env}")")

    case "${verbosity}" in
        quiet)        flags+=("-q") ;;
        verbose)      flags+=("-v") ;;
        very-verbose) flags+=("-vv") ;;
        debug)        flags+=("-vvv") ;;
    esac

    [[ "${no_debug}" == "true" ]] && flags+=("--no-debug")
    [[ "${no_interaction}" == "true" ]] && flags+=("--no-interaction")

    if [[ "${options_json}" != "{}" ]]; then
        local key
        while IFS= read -r key; do
            # The option name is caller data that becomes part of the flag, so
            # it is guarded and quoted like a value; the leading "--" and the
            # "=" separator stay literal.
            if ! guard=$(assert_no_shell_hostile_chars "console option name" "${key}"); then
                printf '%s\n' "${guard}"
                return 1
            fi

            local value value_type quoted_key
            value=$(echo "${options_json}" | jq -r --arg k "${key}" '.[$k]')
            value_type=$(echo "${options_json}" | jq -r --arg k "${key}" '.[$k] | type')
            quoted_key=$(shell_quote_arg "${key}")

            case "${value_type}" in
                boolean)
                    # Boolean true = --flag, false = skip
                    [[ "${value}" == "true" ]] && flags+=("--${quoted_key}")
                    ;;
                string)
                    if ! guard=$(assert_no_shell_hostile_chars "console option value" "${value}"); then
                        printf '%s\n' "${guard}"
                        return 1
                    fi
                    flags+=("--${quoted_key}=$(shell_quote_arg "${value}")")
                    ;;
                array)
                    local arr_val
                    while IFS= read -r arr_val; do
                        if ! guard=$(assert_no_shell_hostile_chars "console option value" "${arr_val}"); then
                            printf '%s\n' "${guard}"
                            return 1
                        fi
                        flags+=("--${quoted_key}=$(shell_quote_arg "${arr_val}")")
                    done < <(echo "${options_json}" | jq -r --arg k "${key}" '.[$k][]' 2>/dev/null)
                    ;;
            esac
        done < <(echo "${options_json}" | jq -r 'keys[]' 2>/dev/null)
    fi

    local cmd="bin/console"
    [[ ${#flags[@]} -gt 0 ]] && cmd="${cmd} ${flags[*]}"

    if [[ -n "${resolved_output_file}" ]]; then
        local rc=0
        _console_run_to_file "${cmd}" "${resolved_output_file}" || rc=$?
        return "${rc}"
    fi

    exec_command "${cmd}"
}

# _format_console_list_llm - Format JSON output for LLM consumption
# Args: $1 = raw JSON output from bin/console list --format=json
# Returns: Concise grouped output optimized for LLM
_format_console_list_llm() {
    local raw_json="$1"

    # Extract command list grouped by namespace, filtering hidden commands
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

    _refuse_linebreak_args "${args}" || return 1

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    local parsed
    if ! parsed=$(echo "${args}" | jq -c '{
        namespace: (.namespace // null),
        format: (.format // "llm")
    }' 2>/dev/null); then
        printf '%s\n' "Refusing to run: could not parse arguments as JSON: ${args}"
        return 1
    fi

    local namespace format
    namespace=$(echo "${parsed}" | jq -r '.namespace // empty')
    format=$(echo "${parsed}" | jq -r '.format')

    # Validate namespace format (security: prevent injection)
    if [[ -n "${namespace}" && ! "${namespace}" =~ ^[a-zA-Z0-9:_-]+$ ]]; then
        echo "Error: Invalid namespace format. Only alphanumeric, colons, underscores, and hyphens allowed."
        return 1
    fi

    local guard
    if ! guard=$(assert_no_shell_hostile_chars "console list format" "${format}"); then
        printf '%s\n' "${guard}"
        return 1
    fi

    log "INFO" "Console list: namespace='${namespace}' format='${format}'"

    # The namespace passed the character allowlist above, so it needs no
    # further guard; it is still quoted so the wrappers see one argument.
    if [[ "${format}" != "llm" ]]; then
        local -a flags=("list")
        [[ -n "${namespace}" ]] && flags+=("$(shell_quote_arg "${namespace}")")
        flags+=("--format=$(shell_quote_arg "${format}")")
        exec_command "bin/console ${flags[*]}"
        return
    fi

    local -a flags=("list")
    [[ -n "${namespace}" ]] && flags+=("$(shell_quote_arg "${namespace}")")
    flags+=("--format=json")

    local raw_output
    raw_output=$(exec_command "bin/console ${flags[*]}")

    _format_console_list_llm "${raw_output}"
}
