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

parse_hook_input
load_mcp_config "php-tooling"

# Start of command or after `;`, `&&`, `||`, `|`, past `NAME=value` prefixes; no `(`, so quoted text stays text.
COMMAND_POSITION='(^|;|&&|\|)\s*([A-Za-z_][A-Za-z0-9_]*=\S*\s+)*'
# No `-` or `:`, so `phpstan` never matches `phpstan-baseline`.
NAME_END='([[:space:];&|<>)]|$)'
VENDOR_BIN="(php\s+)?\.?/?vendor/bin/"
# Global options before the script name, `-d` / `--working-dir` with its value.
COMPOSER_SCRIPT="composer\s+((-d|--working-dir)(=|\s+)?\S+\s+|-\S+\s+)*(run(-script)?\s+)?"

# ============================================================================
# PHPStan - Use phpstan_analyze
# ============================================================================

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}(${VENDOR_BIN}phpstan|${COMPOSER_SCRIPT}phpstan)${NAME_END}"; then
    block_tool "php-tooling" \
        "Use phpstan_analyze for static analysis with configurable level (0-9) and paths." "phpstan_analyze"
fi

# ============================================================================
# ECS / PHP-CS-Fixer - Use ecs_check or ecs_fix
# ============================================================================

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}(${VENDOR_BIN}(ecs|php-cs-fixer)|${COMPOSER_SCRIPT}ecs(-fix)?)${NAME_END}"; then
    block_tool "php-tooling" \
        "Use ecs_check for dry-run validation or ecs_fix to apply fixes." "ecs_check" "ecs_fix"
fi

# Shopware core's `cs` / `cs-fix` replace the deprecated `ecs` alias.
if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}${COMPOSER_SCRIPT}cs${NAME_END}"; then
    block_tool "php-tooling" \
        "Use ecs_check for dry-run validation." "ecs_check"
fi

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}${COMPOSER_SCRIPT}cs-fix${NAME_END}"; then
    block_tool "php-tooling" \
        "Use ecs_fix to apply fixes." "ecs_fix"
fi

# ============================================================================
# PHPUnit - Use phpunit_run
# ============================================================================

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}(${VENDOR_BIN}phpunit|${COMPOSER_SCRIPT}phpunit)${NAME_END}"; then
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

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}(${VENDOR_BIN}rector|${COMPOSER_SCRIPT}rector)${NAME_END}"; then
    block_tool "php-tooling" \
        "Use rector_fix to apply refactorings or rector_check for dry-run preview." "rector_fix" "rector_check"
fi

if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}${COMPOSER_SCRIPT}rector-fix${NAME_END}"; then
    block_tool "php-tooling" \
        "Use rector_fix to apply refactorings." "rector_fix"
fi

exit 0
