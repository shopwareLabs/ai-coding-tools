#!/bin/bash
# Claude Code Hook: Dev Tooling MCP Enforcer (Administration JavaScript)
# =======================================================================
# Blocks Administration JS dev tool bash commands in favor of MCP tools.
#
# Exit codes:
#   0 - Command allowed
#   2 - Command blocked (message shown to Claude)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

parse_hook_input
load_mcp_config "js-tooling"

# Check if command is in Administration context
is_admin_context() {
    # Path-based detection (case-insensitive)
    if echo "$COMMAND" | grep -qiE 'Administration|/app/administration'; then
        return 0
    fi
    # Admin-specific npm scripts
    if echo "$COMMAND" | grep -qE 'npm\s+run\s+(lint:types|format|lint:twig|lint:all)(\s|$)'; then
        return 0
    fi
    # Not clearly Admin context - check if it's Storefront
    if echo "$COMMAND" | grep -qiE 'Storefront|/app/storefront'; then
        return 1
    fi
    if echo "$COMMAND" | grep -qE 'npm\s+run\s+(lint:js|production|development)(\s|$)'; then
        return 1
    fi
    # Unknown context - Admin hook handles generic commands
    return 0
}

# Only process if in Admin context
if ! is_admin_context; then
    exit 0
fi

# ============================================================================
# ESLint - Use eslint_check or eslint_fix
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint(\s|--|$)'; then
    block_tool "mcp__js-admin-tooling__eslint_check" \
        "Use eslint_check for linting or eslint_fix to auto-fix."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:fix(\s|$)'; then
    block_tool "mcp__js-admin-tooling__eslint_fix" \
        "Use eslint_fix to auto-fix ESLint violations."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npx\s+eslint(\s|$)'; then
    block_tool "mcp__js-admin-tooling__eslint_check" \
        "Use eslint_check for linting or eslint_fix to auto-fix."
fi

# ============================================================================
# Stylelint - Use stylelint_check or stylelint_fix
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:scss(\s|--|$)'; then
    block_tool "mcp__js-admin-tooling__stylelint_check" \
        "Use stylelint_check for SCSS/CSS linting."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:scss-fix(\s|$)'; then
    block_tool "mcp__js-admin-tooling__stylelint_fix" \
        "Use stylelint_fix to auto-fix Stylelint violations."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npx\s+stylelint(\s|$)'; then
    block_tool "mcp__js-admin-tooling__stylelint_check" \
        "Use stylelint_check for SCSS/CSS linting or stylelint_fix to auto-fix."
fi

# ============================================================================
# Prettier - Use prettier_check or prettier_fix (Admin only)
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+format(\s|$)'; then
    block_tool "mcp__js-admin-tooling__prettier_check" \
        "Use prettier_check to verify formatting."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+format:fix(\s|$)'; then
    block_tool "mcp__js-admin-tooling__prettier_fix" \
        "Use prettier_fix to auto-format files."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npx\s+prettier(\s|$)'; then
    block_tool "mcp__js-admin-tooling__prettier_check" \
        "Use prettier_check to verify formatting or prettier_fix to auto-format."
fi

# ============================================================================
# Jest - Use jest_run
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+unit(\s|--|$)'; then
    block_tool "mcp__js-admin-tooling__jest_run" \
        "Use jest_run with testPathPattern, testNamePattern, coverage options."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npx\s+jest(\s|$)'; then
    block_tool "mcp__js-admin-tooling__jest_run" \
        "Use jest_run with testPathPattern, testNamePattern, coverage options."
fi

# ============================================================================
# TypeScript - Use tsc_check (Admin only)
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:types(\s|$)'; then
    block_tool "mcp__js-admin-tooling__tsc_check" \
        "Use tsc_check for TypeScript type checking."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npx\s+tsc(\s|$)'; then
    block_tool "mcp__js-admin-tooling__tsc_check" \
        "Use tsc_check for TypeScript type checking."
fi

# ============================================================================
# Combined Lint - Use lint_all, lint_twig (Admin only)
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:all(\s|$)'; then
    block_tool "mcp__js-admin-tooling__lint_all" \
        "Use lint_all to run all lint checks (TypeScript, ESLint, Stylelint, Prettier)."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:twig(\s|$)'; then
    block_tool "mcp__js-admin-tooling__lint_twig" \
        "Use lint_twig for Twig template linting."
fi

# ============================================================================
# Build - Use vite_build (Admin only)
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+build(\s|--|$)'; then
    block_tool "mcp__js-admin-tooling__vite_build" \
        "Use vite_build with mode (development/production) option."
fi

exit 0
