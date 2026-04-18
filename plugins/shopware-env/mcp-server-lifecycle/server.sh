#!/usr/bin/env bash
# Shopware Lifecycle MCP Server
# Provides environment lifecycle tools via Model Context Protocol
#
# Tools:
#   - install_dependencies: Install/update composer and npm dependencies
#   - database_install: First-time database setup
#   - database_reset: Wipe and rebuild database
#   - testdb_prepare: Prepare test database
#   - frontend_build_admin: Full admin build chain
#   - frontend_build_storefront: Full storefront build chain
#   - plugin_create: Scaffold and activate new plugin
#   - plugin_setup: Register and activate existing plugin
#
# Supports environments: native, docker, docker-compose, vagrant, ddev
#
# Configuration: reads .mcp-php-tooling.json (shared with dev-tooling).
# Config file values override model-passed arguments.

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "${SCRIPT_DIR}/../shared" && pwd)"

MCP_CONFIG_FILE="${SCRIPT_DIR}/config.json"
MCP_TOOLS_LIST_FILE="${SCRIPT_DIR}/tools.json"
MCP_LOG_FILE="${SCRIPT_DIR}/server.log"

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

# Reuse dev-tooling's config prefix so we read the same .mcp-php-tooling.json
CONFIG_PREFIX="php-tooling"

export SCRIPT_DIR SHARED_DIR MCP_CONFIG_FILE MCP_TOOLS_LIST_FILE MCP_LOG_FILE PROJECT_ROOT CONFIG_PREFIX

source "${SHARED_DIR}/mcpserver_core.sh"
source "${SHARED_DIR}/config.sh"

# Config is optional for this server — tools accept env args as fallback
LIFECYCLE_HAS_CONFIG="false"
if load_config "${PROJECT_ROOT}" 2>/dev/null; then
    LIFECYCLE_HAS_CONFIG="true"
fi
export LIFECYCLE_HAS_CONFIG

source "${SHARED_DIR}/environment.sh"
source "${SCRIPT_DIR}/lib/resolve_env.sh"
source "${SCRIPT_DIR}/lib/dependencies.sh"
source "${SCRIPT_DIR}/lib/database.sh"
source "${SCRIPT_DIR}/lib/testdb.sh"
source "${SCRIPT_DIR}/lib/frontend.sh"
source "${SCRIPT_DIR}/lib/plugin.sh"

trap 'log "ERROR" "Unexpected error on line ${LINENO}"' ERR

if [[ "${LIFECYCLE_HAS_CONFIG}" == "true" ]]; then
    detect_environment "${PROJECT_ROOT}"
    _configure_extra_log_file "$(_get_config_value '.log_file' '')"
fi

log "INFO" "======================================"
log "INFO" "Shopware Lifecycle MCP Server starting"
log "INFO" "Script dir: ${SCRIPT_DIR}"
log "INFO" "Project root: ${PROJECT_ROOT}"
log "INFO" "Config available: ${LIFECYCLE_HAS_CONFIG}"
if [[ "${LIFECYCLE_HAS_CONFIG}" == "true" ]]; then
    log "INFO" "Config file: ${LINT_CONFIG_FILE}"
    log "INFO" "Environment: ${LINT_ENV}"
fi
log "INFO" "======================================"

run_mcp_server "$@"
