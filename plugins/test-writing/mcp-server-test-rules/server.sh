#!/usr/bin/env bash
# Test Rules MCP Server
# Serves 46 test writing rules with list/filter/get/resolve tools

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "${SCRIPT_DIR}/../shared" && pwd)"
RULES_DIR="$(cd "${SCRIPT_DIR}/../rules" && pwd)"

MCP_CONFIG_FILE="${SCRIPT_DIR}/config.json"
MCP_TOOLS_LIST_FILE="${SCRIPT_DIR}/tools.json"
MCP_LOG_FILE="${SCRIPT_DIR}/server.log"

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

export SCRIPT_DIR SHARED_DIR RULES_DIR MCP_CONFIG_FILE MCP_TOOLS_LIST_FILE MCP_LOG_FILE PROJECT_ROOT

source "${SHARED_DIR}/mcpserver_core.sh"

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/list.sh"
source "${SCRIPT_DIR}/lib/get.sh"
trap 'log "ERROR" "Unexpected error on line ${LINENO}"' ERR

# Build rule index at startup (one-time cost)
_build_rule_index "${RULES_DIR}"

log "INFO" "======================================"
log "INFO" "Test Rules MCP Server starting"
log "INFO" "Script dir: ${SCRIPT_DIR}"
log "INFO" "Rules dir: ${RULES_DIR}"
log "INFO" "Rules indexed: ${#RULE_IDS[@]}"
log "INFO" "======================================"

run_mcp_server "$@"
