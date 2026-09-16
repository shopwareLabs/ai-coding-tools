#!/usr/bin/env bash
# PHP Linting MCP Server
# Provides PHPStan, ECS, PHPUnit, Symfony Console and Rector tools via Model
# Context Protocol
#
# Tools:
#   - phpstan_analyze: Run PHPStan static analysis
#   - ecs_check: Check coding standards (dry-run)
#   - ecs_fix: Fix coding standard violations
#   - phpunit_run: Run PHPUnit tests
#   - phpunit_coverage_gaps: Report uncovered lines from a Clover report
#   - console_run: Run a bin/console command
#   - console_list: List available bin/console commands
#   - rector_check: Preview Rector transformations (dry-run)
#   - rector_fix: Apply Rector transformations
#   - set_project_root: Set or clear the sticky project root
#   - cwd: Report the project root, working directory and config in use
#
# Supports environments: native, docker, docker-compose, vagrant, ddev
#
# Configuration (in priority order):
#   1. MCP_PHP_TOOLING_CONFIG environment variable (absolute path)
#   2. Config file discovery (merged if multiple exist):
#      - .mcp-php-tooling.json (project root, base)
#      - .claude/.mcp-php-tooling.json (higher priority, overrides)

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

# Set config prefix for PHP tooling (used by shared/config.sh)
CONFIG_PREFIX="php-tooling"

export SCRIPT_DIR SHARED_DIR MCP_CONFIG_FILE MCP_TOOLS_LIST_FILE MCP_LOG_FILE PROJECT_ROOT CONFIG_PREFIX

source "${SHARED_DIR}/mcpserver_core.sh"
source "${SHARED_DIR}/config.sh"
if ! load_config "${PROJECT_ROOT}"; then
    exit 1
fi

source "${SHARED_DIR}/environment.sh"
source "${SHARED_DIR}/scope.sh"
if ! scope_validate; then
    exit 1
fi
source "${SHARED_DIR}/worktree.sh"
if ! worktree_state_init; then
    exit 1
fi

# One EXIT trap doing both jobs. A second `trap ... EXIT` would replace the one
# config.sh installs at source time, leaving the merged-config temp file behind.
trap 'worktree_state_cleanup; config_cleanup' EXIT

source "${SCRIPT_DIR}/lib/phpstan.sh"
source "${SCRIPT_DIR}/lib/ecs.sh"
source "${SCRIPT_DIR}/lib/phpunit.sh"
source "${SCRIPT_DIR}/lib/phpunit_coverage.sh"
source "${SCRIPT_DIR}/lib/console.sh"
source "${SCRIPT_DIR}/lib/rector.sh"
source "${SCRIPT_DIR}/lib/prepare.sh"

trap 'log "ERROR" "Unexpected error on line ${LINENO}"' ERR

detect_environment "${PROJECT_ROOT}"
_configure_extra_log_file "$(_get_config_value '.log_file' '')"

log "INFO" "======================================"
log "INFO" "PHP Linting MCP Server starting"
log "INFO" "Script dir: ${SCRIPT_DIR}"
log "INFO" "Project root: ${PROJECT_ROOT}"
log "INFO" "Config file: ${LINT_CONFIG_FILE}"
log "INFO" "Environment: ${LINT_ENV}"
log "INFO" "Working dir: ${LINT_WORKDIR}"
log "INFO" "Extra log: ${MCP_EXTRA_LOG_FILE:-<none>}"
log "INFO" "======================================"

source "${SHARED_DIR}/server_run.sh"
