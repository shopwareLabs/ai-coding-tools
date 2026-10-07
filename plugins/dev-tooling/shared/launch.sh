#!/usr/bin/env bash
# Launch mode of a dev-tooling MCP server: bound to the project root it was
# started in, or unbound because the host started it in this plugin's own
# directory. Claude Code starts a server in the session's project directory.
# Codex starts every plugin MCP server in the plugin directory with no project
# named anywhere, so a server whose launch root is this plugin starts unbound:
# initialize and tools/list work, and every tool refuses until set_project_root
# binds a project (worktree.sh).
#
# Owned by dev-tooling. Not templated — do not add it to the mapping in
# .claude/rules/template-sync.md.
#
# Requires: PROJECT_ROOT and MCP_CONFIG_FILE set by server.sh; log() from
#           mcpserver_core.sh. Sourced after config.sh and before load_config.
#
# Public:
#   launch_is_bound                    - true unless the server started unbound
#   launch_path_in_plugin_root <path>  - true when a canonical path is the
#                                        plugin root or inside it
#
# Globals set at source time:
#   LAUNCH_MODE         - "bound" or "unbound"
#   LAUNCH_PLUGIN_ROOT  - this plugin's root, canonical
#   LAUNCH_SERVER_NAME  - the server's name from its config.json; unbound only
#   PROJECT_ROOT, LINT_CONFIG_FILE - exported empty when unbound

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

LAUNCH_PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
LAUNCH_SERVER_NAME=""
LAUNCH_MODE="bound"

# launch_path_in_plugin_root <canonical path>
# Args: $1 = a path already resolved with `pwd -P`
# Returns: 0 when it is the plugin root or sits under it, 1 otherwise
launch_path_in_plugin_root() {
    local path="$1"
    [[ "${path}" == "${LAUNCH_PLUGIN_ROOT}" || "${path}" == "${LAUNCH_PLUGIN_ROOT}/"* ]]
}

# launch_is_bound
# Returns: 0 when the server started bound to a project root, 1 when unbound
launch_is_bound() {
    [[ "${LAUNCH_MODE}" == "bound" ]]
}

# A root that does not resolve stays bound, so startup refuses it exactly as
# before. MCP_<PREFIX>_CONFIG is deliberately not consulted: it names a
# configuration file, not a project, and honoring it here would make the
# plugin directory the root every tool runs in. The bind honors it instead.
_launch_canonical_root=""
_launch_canonical_root=$(cd "${PROJECT_ROOT}" >/dev/null 2>&1 && pwd -P) || _launch_canonical_root=""
if [[ -n "${_launch_canonical_root}" ]] && launch_path_in_plugin_root "${_launch_canonical_root}"; then
    LAUNCH_MODE="unbound"

    # The name the refusal tells the caller to call set_project_root on.
    LAUNCH_SERVER_NAME=$(jq -r '.serverInfo.name // empty' "${MCP_CONFIG_FILE}" 2>/dev/null) || LAUNCH_SERVER_NAME=""
    if [[ -z "${LAUNCH_SERVER_NAME}" ]]; then
        log "ERROR" "Cannot read .serverInfo.name from ${MCP_CONFIG_FILE}"
        exit 1
    fi

    PROJECT_ROOT=""
    LINT_CONFIG_FILE=""
    export PROJECT_ROOT LINT_CONFIG_FILE

    log "INFO" "${LAUNCH_SERVER_NAME} starting without a project root: launched in its plugin directory ${LAUNCH_PLUGIN_ROOT}. Every tool refuses until set_project_root binds one."
fi
unset _launch_canonical_root
