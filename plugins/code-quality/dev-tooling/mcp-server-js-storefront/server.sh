#!/usr/bin/env bash
# Storefront JavaScript Tooling MCP Server
# Provides ESLint, Stylelint, Jest, and Webpack build tools
# for Shopware 6 Storefront (vanilla JS/Webpack)
#
# Note: Prettier and TypeScript tools are NOT available for Storefront
# as the Shopware 6 Storefront package.json does not include these scripts.
#
# Tools:
#   - eslint_check: Run ESLint linting (dry-run)
#   - eslint_fix: Auto-fix ESLint violations
#   - stylelint_check: Run Stylelint on SCSS (dry-run)
#   - stylelint_fix: Auto-fix Stylelint violations
#   - jest_run: Run Jest tests
#   - webpack_build: Build with Webpack
#
# Supports environments: native, docker, vagrant, ddev
#
# Configuration (in priority order):
#   1. MCP_JS_TOOLING_CONFIG environment variable (absolute path)
#   2. Config file discovery (merged if multiple exist):
#      - .mcp-js-tooling.json (project root, base)
#      - .claude/.mcp-js-tooling.json (higher priority, overrides)

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "${SCRIPT_DIR}/../shared" && pwd)"

MCP_CONFIG_FILE="${SCRIPT_DIR}/config.json"
MCP_TOOLS_LIST_FILE="${SCRIPT_DIR}/tools.json"
MCP_LOG_FILE="${SCRIPT_DIR}/server.log"

# Project root detection
# When Claude Code starts the MCP server, PWD is typically the project root
# This can be overridden via PROJECT_ROOT environment variable
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

# Set config prefix for JS tooling (shared by admin and storefront servers)
CONFIG_PREFIX="js-tooling"

# Set JS context for workdir determination (storefront uses Storefront path)
JS_CONTEXT="storefront"

export SCRIPT_DIR SHARED_DIR MCP_CONFIG_FILE MCP_TOOLS_LIST_FILE MCP_LOG_FILE PROJECT_ROOT CONFIG_PREFIX JS_CONTEXT

# Source core first (provides log function)
source "${SHARED_DIR}/mcpserver_core.sh"

# Source config module and load configuration
source "${SHARED_DIR}/config.sh"
if ! load_config "${PROJECT_ROOT}"; then
    exit 1
fi

# Source remaining modules
source "${SHARED_DIR}/environment.sh"
source "${SCRIPT_DIR}/lib/eslint.sh"
source "${SCRIPT_DIR}/lib/stylelint.sh"
source "${SCRIPT_DIR}/lib/jest.sh"
source "${SCRIPT_DIR}/lib/build.sh"

trap 'log "ERROR" "Unexpected error on line ${LINENO}"' ERR

detect_environment "${PROJECT_ROOT}"

log "INFO" "======================================"
log "INFO" "Storefront Tooling MCP Server starting"
log "INFO" "Script dir: ${SCRIPT_DIR}"
log "INFO" "Project root: ${PROJECT_ROOT}"
log "INFO" "Config file: ${LINT_CONFIG_FILE}"
log "INFO" "Environment: ${LINT_ENV}"
log "INFO" "Working dir: ${LINT_WORKDIR}"
log "INFO" "======================================"

run_mcp_server "$@"
