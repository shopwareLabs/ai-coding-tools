#!/usr/bin/env bash
# GitHub CLI MCP Server
# Wraps the gh CLI for GitHub operations: PRs, issues, CI runs, jobs, commits, search

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "${SCRIPT_DIR}/../shared" && pwd)"

MCP_CONFIG_FILE="${SCRIPT_DIR}/config.json"
MCP_TOOLS_LIST_FILE="${SCRIPT_DIR}/tools.json"
MCP_LOG_FILE="${SCRIPT_DIR}/server.log"

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

export SCRIPT_DIR SHARED_DIR MCP_CONFIG_FILE MCP_TOOLS_LIST_FILE MCP_LOG_FILE PROJECT_ROOT

source "${SHARED_DIR}/mcpserver_core.sh"

# Optional configuration - gh-tooling does not require a config file.
# Config provides defaults (e.g. default repo) but is not mandatory.
GH_TOOLING_CONFIG_FILE=""
GH_DEFAULT_REPO=""

_load_gh_config() {
    local project_root="$1"
    local config_name=".mcp-gh-tooling.json"

    if [[ -n "${MCP_GH_TOOLING_CONFIG:-}" ]]; then
        if [[ -f "${MCP_GH_TOOLING_CONFIG}" ]]; then
            GH_TOOLING_CONFIG_FILE="${MCP_GH_TOOLING_CONFIG}"
            log "INFO" "Config from MCP_GH_TOOLING_CONFIG: ${GH_TOOLING_CONFIG_FILE}"
        else
            log "WARN" "MCP_GH_TOOLING_CONFIG set but file not found: ${MCP_GH_TOOLING_CONFIG}"
        fi
        return 0
    fi

    # Check standard config locations (last found wins)
    local -a locations=(
        "${project_root}/${config_name}"
        "${project_root}/.aiassistant/${config_name}"
        "${project_root}/.amazonq/${config_name}"
        "${project_root}/.cline/${config_name}"
        "${project_root}/.cursor/${config_name}"
        "${project_root}/.kiro/${config_name}"
        "${project_root}/.windsurf/${config_name}"
        "${project_root}/.zed/${config_name}"
        "${project_root}/.claude/${config_name}"
    )

    for loc in "${locations[@]}"; do
        if [[ -f "${loc}" ]]; then
            GH_TOOLING_CONFIG_FILE="${loc}"
            log "INFO" "Found config: ${loc}"
        fi
    done

    if [[ -z "${GH_TOOLING_CONFIG_FILE}" ]]; then
        log "INFO" "No .mcp-gh-tooling.json found - using defaults (no default repo)"
    fi
}

_read_gh_config() {
    if [[ -z "${GH_TOOLING_CONFIG_FILE}" ]] || [[ ! -f "${GH_TOOLING_CONFIG_FILE}" ]]; then
        return 0
    fi
    GH_DEFAULT_REPO=$(jq -r '.repo // empty' "${GH_TOOLING_CONFIG_FILE}" 2>/dev/null || echo "")
    log "INFO" "Default repo from config: ${GH_DEFAULT_REPO:-<none>}"

    local log_file_val
    log_file_val=$(jq -r '.log_file // empty' "${GH_TOOLING_CONFIG_FILE}" 2>/dev/null || echo "")
    _configure_extra_log_file "$log_file_val"
}

export GH_DEFAULT_REPO GH_TOOLING_CONFIG_FILE

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/pr.sh"
source "${SCRIPT_DIR}/lib/issue.sh"
source "${SCRIPT_DIR}/lib/run.sh"
source "${SCRIPT_DIR}/lib/job.sh"
source "${SCRIPT_DIR}/lib/commit.sh"
source "${SCRIPT_DIR}/lib/search.sh"
source "${SCRIPT_DIR}/lib/api.sh"
source "${SCRIPT_DIR}/lib/repo.sh"

trap 'log "ERROR" "Unexpected error on line ${LINENO}"' ERR

_load_gh_config "${PROJECT_ROOT}"
_read_gh_config

log "INFO" "======================================"
log "INFO" "GitHub CLI MCP Server starting"
log "INFO" "Script dir: ${SCRIPT_DIR}"
log "INFO" "Project root: ${PROJECT_ROOT}"
log "INFO" "Default repo: ${GH_DEFAULT_REPO:-<none>}"
log "INFO" "Extra log: ${MCP_EXTRA_LOG_FILE:-<none>}"
log "INFO" "======================================"

run_mcp_server "$@"