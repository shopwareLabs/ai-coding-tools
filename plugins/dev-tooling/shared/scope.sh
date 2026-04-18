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
#                                 reserved-name or missing-default violations
#   resolve_scope <arg>         - resolves scope from arg | default_scope | "shopware"
#                                 sets globals: SCOPE_NAME, SCOPE_CWD
#                                 returns 1 and prints error on undeclared scope
#   scope_get_tool_field <tool> <field>
#                               - echoes scope.<tool>.<field> or empty
#   scope_get_bootstrap <tool>  - echoes scope.<tool>.bootstrap[] one per line

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

SCOPE_NAME=""
SCOPE_CWD=""

# _scope_jq <filter>
# Internal helper: run jq against LINT_CONFIG_FILE. Empty output on error or null.
_scope_jq() {
    local filter="$1"
    [[ -f "${LINT_CONFIG_FILE:-}" ]] || { echo ""; return 0; }
    jq -r "${filter} // empty" "${LINT_CONFIG_FILE}" 2>/dev/null || echo ""
}

# scope_validate
# Validates scopes config. Called once at server startup.
# Fails hard with a clear message on:
#   - scopes.shopware present (reserved name)
#   - default_scope references a name that is neither declared nor "shopware"
scope_validate() {
    local reserved
    reserved=$(_scope_jq '.scopes.shopware | if . then "yes" else empty end')
    if [[ "${reserved}" == "yes" ]]; then
        printf '%s\n' 'Config error: scope name "shopware" is reserved and must not appear in scopes.' >&2
        log "ERROR" 'Config error: scope name "shopware" is reserved and must not appear in scopes.'
        return 1
    fi

    local default
    default=$(_scope_jq '.default_scope')
    if [[ -n "${default}" && "${default}" != "shopware" ]]; then
        local declared
        declared=$(_scope_jq ".scopes.\"${default}\" | if . then \"yes\" else empty end")
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
# Returns 1 and prints a clear error on undeclared non-shopware names.
resolve_scope() {
    local arg="${1:-}"

    if [[ -z "${arg}" ]]; then
        arg=$(_scope_jq '.default_scope')
        [[ -z "${arg}" ]] && arg="shopware"
    fi

    if [[ "${arg}" == "shopware" ]]; then
        SCOPE_NAME="shopware"
        SCOPE_CWD=""
        return 0
    fi

    local declared
    declared=$(_scope_jq ".scopes.\"${arg}\" | if . then \"yes\" else empty end")
    if [[ "${declared}" != "yes" ]]; then
        local names
        names=$(_scope_jq '.scopes | keys | join(", ")')
        [[ -z "${names}" ]] && names="(none)"
        printf '%s\n' "Scope \"${arg}\" is not declared in ${LINT_CONFIG_FILE}. Declared scopes: ${names}" >&2
        log "ERROR" "Scope \"${arg}\" is not declared in ${LINT_CONFIG_FILE}. Declared scopes: ${names}"
        return 1
    fi

    SCOPE_NAME="${arg}"
    # shellcheck disable=SC2034  # consumed by shared/environment.sh (wrap_command, scoped-path resolver) via dynamic scope
    SCOPE_CWD=$(_scope_jq ".scopes.\"${arg}\".cwd")
    return 0
}

# scope_get_tool_field <tool> <field>
# Returns the scope-declared value for scope.<tool>.<field>, or empty if
# scope is "shopware" or field absent.
scope_get_tool_field() {
    local tool="$1"
    local field="$2"
    [[ "${SCOPE_NAME}" == "shopware" || -z "${SCOPE_NAME}" ]] && { echo ""; return 0; }
    _scope_jq ".scopes.\"${SCOPE_NAME}\".\"${tool}\".\"${field}\""
}

# scope_get_bootstrap <tool>
# Echoes scope.<tool>.bootstrap[] one command per line, or empty.
scope_get_bootstrap() {
    local tool="$1"
    [[ "${SCOPE_NAME}" == "shopware" || -z "${SCOPE_NAME}" ]] && return 0
    [[ -f "${LINT_CONFIG_FILE:-}" ]] || return 0
    jq -r ".scopes.\"${SCOPE_NAME}\".\"${tool}\".bootstrap // [] | .[]" "${LINT_CONFIG_FILE}" 2>/dev/null || true
}
