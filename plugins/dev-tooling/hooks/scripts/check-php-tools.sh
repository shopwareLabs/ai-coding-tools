#!/bin/bash
# Claude Code Hook: Dev Tooling MCP Enforcer (PHP)
# =================================================
# Blocks PHP dev tool bash commands in favor of MCP tools.
#
# Exit codes:
#   0 - Command allowed
#   2 - Command blocked (message shown to Claude)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/js_binary.sh"

parse_hook_input
load_mcp_config "php-tooling"

# COMMAND_POSITION, NAME_END and COMPOSER_RUN come from lib/js_binary.sh, shared
# with the JS hooks.
VENDOR_BIN="(php\s+)?\.?/?vendor/bin/"

# ============================================================================
# PHPStan - Use phpstan_analyze
# ============================================================================

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}(${VENDOR_BIN}phpstan|${COMPOSER_RUN}phpstan)${NAME_END}"; then
    block_tool "php-tooling" \
        "Use phpstan_analyze for static analysis with configurable level (0-9) and paths." "phpstan_analyze"
fi

# ============================================================================
# ECS / PHP-CS-Fixer - Use ecs_check or ecs_fix
# ============================================================================

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}(${VENDOR_BIN}(ecs|php-cs-fixer))${NAME_END}"; then
    block_tool "php-tooling" \
        "Use ecs_check for dry-run validation or ecs_fix to apply fixes." "ecs_check" "ecs_fix"
fi

# The Composer script names say which mode runs: `ecs` is the check, `ecs-fix`
# the fixer. `cs` / `cs-fix` are Shopware core's names for the same two.
if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}${COMPOSER_RUN}ecs${NAME_END}"; then
    block_tool "php-tooling" \
        "Use ecs_check for dry-run validation." "ecs_check"
fi

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}${COMPOSER_RUN}ecs-fix${NAME_END}"; then
    block_tool "php-tooling" \
        "Use ecs_fix to apply fixes." "ecs_fix"
fi

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}${COMPOSER_RUN}cs${NAME_END}"; then
    block_tool "php-tooling" \
        "Use ecs_check for dry-run validation." "ecs_check"
fi

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}${COMPOSER_RUN}cs-fix${NAME_END}"; then
    block_tool "php-tooling" \
        "Use ecs_fix to apply fixes." "ecs_fix"
fi

# ============================================================================
# PHPUnit - Use phpunit_run
# ============================================================================

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}(${VENDOR_BIN}phpunit|${COMPOSER_RUN}phpunit)${NAME_END}"; then
    block_tool "php-tooling" \
        "Use phpunit_run with testsuite, paths, filter, coverage, stop_on_failure options." "phpunit_run"
fi

# ============================================================================
# Symfony Console - Use console_run or console_list
# ============================================================================

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}(php\s+)?\.?/?bin/console${NAME_END}"; then
    block_tool "php-tooling" \
        "Use console_run to execute commands or console_list to list available commands." "console_run" "console_list"
fi

# ============================================================================
# Rector - Use rector_fix or rector_check
# ============================================================================

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}(${VENDOR_BIN}rector|${COMPOSER_RUN}rector)${NAME_END}"; then
    block_tool "php-tooling" \
        "Use rector_fix to apply refactorings or rector_check for dry-run preview." "rector_fix" "rector_check"
fi

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}${COMPOSER_RUN}rector-fix${NAME_END}"; then
    block_tool "php-tooling" \
        "Use rector_fix to apply refactorings." "rector_fix"
fi

exit 0
