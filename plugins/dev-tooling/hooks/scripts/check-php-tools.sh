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

# ============================================================================
# PHPStan - Use phpstan_analyze
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?vendor/bin/phpstan(\s|$)'; then
    block_tool "php-tooling" \
        "Use phpstan_analyze for static analysis with configurable level (0-9) and paths." "phpstan_analyze"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+phpstan(\s|$)'; then
    block_tool "php-tooling" \
        "Use phpstan_analyze for static analysis with configurable level (0-9) and paths." "phpstan_analyze"
fi

# ============================================================================
# ECS / PHP-CS-Fixer - Use ecs_check or ecs_fix
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?vendor/bin/(ecs|php-cs-fixer)(\s|$)'; then
    block_tool "php-tooling" \
        "Use ecs_check for dry-run validation or ecs_fix to apply fixes." "ecs_check" "ecs_fix"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+ecs(-fix)?(\s|$)'; then
    block_tool "php-tooling" \
        "Use ecs_check for dry-run validation or ecs_fix to apply fixes." "ecs_check" "ecs_fix"
fi

# ============================================================================
# PHPUnit - Use phpunit_run
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?vendor/bin/phpunit(\s|$)'; then
    block_tool "php-tooling" \
        "Use phpunit_run with testsuite, paths, filter, coverage, stop_on_failure options." "phpunit_run"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+phpunit(\s|$)'; then
    block_tool "php-tooling" \
        "Use phpunit_run with testsuite, paths, filter, coverage, stop_on_failure options." "phpunit_run"
fi

# ============================================================================
# Symfony Console - Use console_run or console_list
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?bin/console(\s|$)'; then
    block_tool "php-tooling" \
        "Use console_run to execute commands or console_list to list available commands." "console_run" "console_list"
fi

# ============================================================================
# Rector - Use rector_fix or rector_check
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?vendor/bin/rector(\s|$)'; then
    block_tool "php-tooling" \
        "Use rector_fix to apply refactorings or rector_check for dry-run preview." "rector_fix" "rector_check"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+rector(\s|$)'; then
    block_tool "php-tooling" \
        "Use rector_fix to apply refactorings or rector_check for dry-run preview." "rector_fix" "rector_check"
fi

exit 0
