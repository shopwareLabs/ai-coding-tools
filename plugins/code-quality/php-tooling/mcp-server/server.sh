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
#
# Configuration (in priority order):
#   1. MCP_PHP_TOOLING_CONFIG environment variable (absolute path)
#   2. Config file discovery (merged if multiple exist):
#      - .mcp-php-tooling.json (project root, base)
#      - .claude/.mcp-php-tooling.json (higher priority, overrides)

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

# Source core first (provides log function)
source "${SCRIPT_DIR}/mcpserver_core.sh"

# Source config module and load configuration
source "${SCRIPT_DIR}/lib/config.sh"
if ! load_config "${PROJECT_ROOT}"; then
    exit 1
fi

# Source remaining modules
source "${SCRIPT_DIR}/lib/environment.sh"
source "${SCRIPT_DIR}/lib/phpstan.sh"
source "${SCRIPT_DIR}/lib/ecs.sh"
source "${SCRIPT_DIR}/lib/phpunit.sh"
source "${SCRIPT_DIR}/lib/console.sh"

trap 'log "ERROR" "Unexpected error on line ${LINENO}"' ERR

detect_environment "${PROJECT_ROOT}"

log "INFO" "======================================"
log "INFO" "PHP Linting MCP Server starting"
log "INFO" "Script dir: ${SCRIPT_DIR}"
log "INFO" "Project root: ${PROJECT_ROOT}"
log "INFO" "Config file: ${LINT_CONFIG_FILE}"
log "INFO" "Environment: ${LINT_ENV}"
log "INFO" "Working dir: ${LINT_WORKDIR}"
log "INFO" "======================================"

run_mcp_server "$@"
