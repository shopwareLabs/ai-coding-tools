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
# PHPStan - Use mcp__php-tooling__phpstan_analyze
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?vendor/bin/phpstan(\s|$)'; then
    block_tool "mcp__php-tooling__phpstan_analyze" \
        "Use phpstan_analyze for static analysis with configurable level (0-9) and paths."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+phpstan(\s|$)'; then
    block_tool "mcp__php-tooling__phpstan_analyze" \
        "Use phpstan_analyze for static analysis with configurable level (0-9) and paths."
fi

# ============================================================================
# ECS / PHP-CS-Fixer - Use mcp__php-tooling__ecs_check or ecs_fix
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?vendor/bin/(ecs|php-cs-fixer)(\s|$)'; then
    block_tool "mcp__php-tooling__ecs_check or ecs_fix" \
        "Use ecs_check for dry-run validation or ecs_fix to apply fixes."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+ecs(-fix)?(\s|$)'; then
    block_tool "mcp__php-tooling__ecs_check or ecs_fix" \
        "Use ecs_check for dry-run validation or ecs_fix to apply fixes."
fi

# ============================================================================
# PHPUnit - Use mcp__php-tooling__phpunit_run
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?vendor/bin/phpunit(\s|$)'; then
    block_tool "mcp__php-tooling__phpunit_run" \
        "Use phpunit_run with testsuite, paths, filter, coverage, stop_on_failure options."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+phpunit(\s|$)'; then
    block_tool "mcp__php-tooling__phpunit_run" \
        "Use phpunit_run with testsuite, paths, filter, coverage, stop_on_failure options."
fi

# ============================================================================
# Symfony Console - Use mcp__php-tooling__console_run or console_list
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?bin/console(\s|$)'; then
    block_tool "mcp__php-tooling__console_run or console_list" \
        "Use console_run to execute commands or console_list to list available commands."
fi

exit 0
