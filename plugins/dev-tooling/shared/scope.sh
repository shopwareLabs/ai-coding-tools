#!/usr/bin/env bash
# Scope resolution module for dev-tooling MCP servers.
# Reads `scopes` and `default_scope` from LINT_CONFIG_FILE and resolves the
# active scope for a tool call. Exposes per-tool getters that consult the
# resolved scope's config.
#
# Requires: LINT_CONFIG_FILE must be set and exported before sourcing.
# Requires: log() function (from mcpserver_core.sh).
#
# Public:
#   scope_validate              - called once at server start; fails hard on
#                                 reserved-name or missing-default violations,
#                                 and on a configuration jq cannot evaluate
#   resolve_scope <arg>         - resolves scope from arg | default_scope | "shopware"
#                                 sets globals: SCOPE_NAME, SCOPE_CWD
#                                 returns 1 and prints error on an undeclared scope,
#                                 a config file that does not exist or is
#                                 unreadable, and a config that is not a JSON object
#   scope_get_tool_field <tool> <field>
#                               - echoes scope.<tool>.<field> or empty; returns 1
#                                 and prints error when jq cannot evaluate the field
#   scope_get_bootstrap <tool>  - echoes scope.<tool>.bootstrap[] one per line;
#                                 returns 1 and prints error when the value is not
#                                 an array, or an element is not a non-empty string

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

SCOPE_NAME=""
SCOPE_CWD=""

# _scope_jq <filter> [jq-option...]
# Internal helper: run jq against LINT_CONFIG_FILE. Empty output for a null or
# absent value. Returns 1 and prints a refusal naming the file and jq's error
# when jq cannot evaluate the filter: a scope value of the wrong type (a string
# where an object is indexed) must not read as absent and run unscoped.
# Every value that is not a compile-time constant enters through a trailing
# `--arg <name> <value>` and is referenced as $<name> inside the filter. It must
# never be interpolated into the filter text: a value carrying a double quote
# closes the filter's string literal and the rest of it is parsed as jq program.
_scope_jq() {
    local filter="$1"
    shift
    [[ -f "${LINT_CONFIG_FILE:-}" ]] || { echo ""; return 0; }
    local output rc=0
    output=$(jq -r ${@+"$@"} "${filter} // empty" "${LINT_CONFIG_FILE}" 2>&1) || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf '%s\n' "Config error: jq could not evaluate ${filter} against ${LINT_CONFIG_FILE}: ${output}" >&2
        return 1
    fi
    printf '%s\n' "${output}"
}

# _scope_assert_config_object
# _scope_jq reads a config edited mid-session into non-JSON as "no scopes", which would run unscoped.
# Returns: 1 and prints a refusal naming the file when it is missing or is not a JSON object
_scope_assert_config_object() {
    local file="${LINT_CONFIG_FILE:-}"
    if [[ ! -f "${file}" ]]; then
        printf '%s\n' "Config error: ${file:-<unset>} does not exist, so no scope can be read from it." >&2
        log "ERROR" "Config error: ${file:-<unset>} does not exist, so no scope can be read from it."
        return 1
    fi
    if jq -e 'type == "object"' "${file}" >/dev/null 2>&1; then
        return 0
    fi
    printf '%s\n' "Config error: ${file} does not parse as a JSON object, so no scope can be read from it." >&2
    log "ERROR" "Config error: ${file} does not parse as a JSON object, so no scope can be read from it."
    return 1
}

# scope_validate
# Validates scopes config. Called once at server startup.
# Fails hard with a clear message on:
#   - a configuration jq cannot evaluate
#   - scopes.shopware present (reserved name)
#   - default_scope references a name that is neither declared nor "shopware"
scope_validate() {
    local reserved
    if ! reserved=$(_scope_jq '.scopes.shopware | if . then "yes" else empty end'); then
        return 1
    fi
    if [[ "${reserved}" == "yes" ]]; then
        printf '%s\n' 'Config error: scope name "shopware" is reserved and must not appear in scopes.' >&2
        log "ERROR" 'Config error: scope name "shopware" is reserved and must not appear in scopes.'
        return 1
    fi

    local default
    if ! default=$(_scope_jq '.default_scope'); then
        return 1
    fi
    if [[ -n "${default}" && "${default}" != "shopware" ]]; then
        local declared
        # shellcheck disable=SC2016  # $name is a jq variable bound by the --arg below, not a shell expansion
        if ! declared=$(_scope_jq '.scopes[$name] | if . then "yes" else empty end' --arg name "${default}"); then
            return 1
        fi
        if [[ "${declared}" != "yes" ]]; then
            printf '%s\n' "Config error: default_scope \"${default}\" is not declared in scopes." >&2
            log "ERROR" "Config error: default_scope \"${default}\" is not declared in scopes."
            return 1
        fi
    fi

    return 0
}

# resolve_scope <arg>
# Resolution order: arg | default_scope | "shopware"
# Sets: SCOPE_NAME, SCOPE_CWD (empty when scope is "shopware")
# Returns 1 and prints a clear error on undeclared non-shopware names, on a
# configuration file that is missing or unreadable, and on a configuration
# file that is not a JSON object or that jq cannot evaluate.
resolve_scope() {
    local arg="${1:-}"

    _scope_assert_config_object || return 1

    if [[ -z "${arg}" ]]; then
        if ! arg=$(_scope_jq '.default_scope'); then
            return 1
        fi
        [[ -z "${arg}" ]] && arg="shopware"
    fi

    if [[ "${arg}" == "shopware" ]]; then
        SCOPE_NAME="shopware"
        SCOPE_CWD=""
        return 0
    fi

    local declared
    # shellcheck disable=SC2016  # $name is a jq variable bound by the --arg below, not a shell expansion
    if ! declared=$(_scope_jq '.scopes[$name] | if . then "yes" else empty end' --arg name "${arg}"); then
        return 1
    fi
    if [[ "${declared}" != "yes" ]]; then
        local names
        if ! names=$(_scope_jq '.scopes | keys | join(", ")'); then
            return 1
        fi
        [[ -z "${names}" ]] && names="(none)"
        printf '%s\n' "Scope \"${arg}\" is not declared in ${LINT_CONFIG_FILE}. Declared scopes: ${names}" >&2
        log "ERROR" "Scope \"${arg}\" is not declared in ${LINT_CONFIG_FILE}. Declared scopes: ${names}"
        return 1
    fi

    SCOPE_NAME="${arg}"
    # shellcheck disable=SC2034,SC2016  # SCOPE_CWD is consumed by shared/environment.sh (wrap_command, scoped-path resolver) via dynamic scope; $name is a jq variable bound by the --arg, not a shell expansion
    if ! SCOPE_CWD=$(_scope_jq '.scopes[$name].cwd' --arg name "${arg}"); then
        return 1
    fi
    return 0
}

# scope_get_tool_field <tool> <field>
# Returns the scope-declared value for scope.<tool>.<field>, or empty if
# scope is "shopware" or field absent. Returns 1 when jq cannot evaluate the
# field, e.g. when scope.<tool> is a string rather than an object.
scope_get_tool_field() {
    local tool="$1"
    local field="$2"
    [[ "${SCOPE_NAME}" == "shopware" || -z "${SCOPE_NAME}" ]] && { echo ""; return 0; }
    # shellcheck disable=SC2016  # $name/$tool/$field are jq variables bound by the --arg options below, not shell expansions
    _scope_jq '.scopes[$name][$tool][$field]' \
        --arg name "${SCOPE_NAME}" --arg tool "${tool}" --arg field "${field}"
}

# scope_get_bootstrap <tool>
# Echoes scope.<tool>.bootstrap[] one command per line, or empty when none is declared.
# Returns 1 with a refusal on stderr when the value is not an array, or when an
# element is not a non-empty string: a string would silently run nothing, and a
# null element would run as the literal command "null".
scope_get_bootstrap() {
    local tool="$1"
    [[ "${SCOPE_NAME}" == "shopware" || -z "${SCOPE_NAME}" ]] && return 0
    [[ -f "${LINT_CONFIG_FILE:-}" ]] || return 0
    local commands
    # shellcheck disable=SC2016  # $name/$tool are jq variables bound by the --arg options, not shell expansions
    if ! commands=$(jq -r --arg name "${SCOPE_NAME}" --arg tool "${tool}" \
        '.scopes[$name][$tool].bootstrap | if . == null then empty elif type == "array" then .[] | if type == "string" and . != "" then . else error("an element is not a non-empty string (" + (if . == "" then "empty string" else type end) + ")") end else error("it is a " + type) end' \
        "${LINT_CONFIG_FILE}" 2>&1); then
        printf '%s\n' "Config error: scopes.${SCOPE_NAME}.${tool}.bootstrap in ${LINT_CONFIG_FILE} must be an array of commands, each a non-empty string (${commands})." >&2
        return 1
    fi
    if [[ -n "${commands}" ]]; then
        printf '%s\n' "${commands}"
    fi
}

# _run_scope_bootstrap <tool>
# Runs scope.<tool>.bootstrap[] via exec_command in sequence. Any non-zero exit
# aborts with an MCP-facing error message on stdout. A bootstrap value that is
# not an array of non-empty strings is refused the same way. The list is
# captured before the loop because a `< <(...)` source drops the producer's
# exit status.
_run_scope_bootstrap() {
    local tool="$1"
    local commands
    if ! commands=$(scope_get_bootstrap "${tool}" 2>&1); then
        echo "Scope bootstrap refused for tool '${tool}':"
        echo "${commands}"
        return 1
    fi
    local cmd
    while IFS= read -r cmd; do
        [[ -z "${cmd}" ]] && continue
        log "INFO" "Scope bootstrap [${tool}]: ${cmd}"
        local output rc=0
        output=$(exec_command "${cmd}") || rc=$?
        if [[ "${rc}" -ne 0 ]]; then
            echo "Scope bootstrap failed for tool '${tool}' (exit ${rc}):"
            echo "${output}"
            return 1
        fi
    done <<<"${commands}"
    return 0
}
