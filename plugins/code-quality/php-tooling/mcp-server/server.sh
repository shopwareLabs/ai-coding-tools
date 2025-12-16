#!/usr/bin/env bash
# PHP Linting MCP Server
# Provides PHPStan, ECS, and PHPUnit tools via Model Context Protocol
#
# Tools:
#   - phpstan_analyze: Run PHPStan static analysis
#   - ecs_check: Check coding standards (dry-run)
#   - ecs_fix: Fix coding standard violations
#   - phpunit_run: Run PHPUnit tests
#
# Supports environments: native, docker, vagrant, ddev
# Configure via .lintrc.local.json in project root

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MCP_CONFIG_FILE="${SCRIPT_DIR}/config.json"
MCP_TOOLS_LIST_FILE="${SCRIPT_DIR}/tools.json"
MCP_LOG_FILE="${SCRIPT_DIR}/server.log"

# Project root detection
# When Claude Code starts the MCP server, PWD is typically the project root
# This can be overridden via PROJECT_ROOT environment variable
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

export SCRIPT_DIR MCP_CONFIG_FILE MCP_TOOLS_LIST_FILE MCP_LOG_FILE PROJECT_ROOT

source "${SCRIPT_DIR}/mcpserver_core.sh"
source "${SCRIPT_DIR}/lib/environment.sh"
source "${SCRIPT_DIR}/lib/phpstan.sh"
source "${SCRIPT_DIR}/lib/ecs.sh"
source "${SCRIPT_DIR}/lib/phpunit.sh"

trap 'log "ERROR" "Unexpected error on line ${LINENO}"' ERR

detect_environment "${PROJECT_ROOT}"

log "INFO" "======================================"
log "INFO" "PHP Linting MCP Server starting"
log "INFO" "Script dir: ${SCRIPT_DIR}"
log "INFO" "Project root: ${PROJECT_ROOT}"
log "INFO" "Environment: ${LINT_ENV}"
log "INFO" "Working dir: ${LINT_WORKDIR}"
log "INFO" "======================================"

run_mcp_server "$@"
