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
source "${SCRIPT_DIR}/lib/js_binary.sh"

parse_hook_input
load_mcp_config "js-tooling"

# Check if command is in Administration context
is_admin_context() {
    # Path-based detection (case-insensitive)
    if echo "$COMMAND" | grep -qiE 'Administration|/app/administration'; then
        return 0
    fi
    # Admin-specific npm scripts
    if echo "$COMMAND" | grep -qE "${NPM_RUN}(lint:types|format|lint:twig|lint:all)${NAME_END}"; then
        return 0
    fi
    # Not clearly Admin context - check if it's Storefront
    if echo "$COMMAND" | grep -qiE 'Storefront|/app/storefront'; then
        return 1
    fi
    if echo "$COMMAND" | grep -qE "${NPM_RUN}(lint:js|production|development)${NAME_END}"; then
        return 1
    fi
    # Unknown context - Admin hook handles generic commands.
    return 0
}

# Only process if in Admin context
if ! is_admin_context; then
    exit 0
fi

# ============================================================================
# ESLint - Use eslint_check or eslint_fix
# ============================================================================

if runs_npm_script 'lint'; then
    block_tool "js-admin-tooling" \
        "Use eslint_check for linting or eslint_fix to auto-fix." "eslint_check"
fi

if runs_npm_script 'lint:fix'; then
    block_tool "js-admin-tooling" \
        "Use eslint_fix to auto-fix ESLint violations." "eslint_fix"
fi

if runs_npm_script 'lint-fix'; then
    block_tool "js-admin-tooling" \
        "Use eslint_fix to auto-fix ESLint violations." "eslint_fix"
fi

if runs_npm_script 'lint:debugging'; then
    block_tool "js-admin-tooling" \
        "Use eslint_check with paths for linting, or eslint_fix with paths to auto-fix." "eslint_check"
fi

if runs_binary eslint; then
    block_tool "js-admin-tooling" \
        "Use eslint_check for linting or eslint_fix to auto-fix." "eslint_check"
fi

# ============================================================================
# Stylelint - Use stylelint_check or stylelint_fix
# ============================================================================

if runs_npm_script 'lint:scss'; then
    block_tool "js-admin-tooling" \
        "Use stylelint_check for SCSS/CSS linting." "stylelint_check"
fi

if runs_npm_script 'lint:scss-fix'; then
    block_tool "js-admin-tooling" \
        "Use stylelint_fix to auto-fix Stylelint violations." "stylelint_fix"
fi

if runs_binary stylelint; then
    block_tool "js-admin-tooling" \
        "Use stylelint_check for SCSS/CSS linting or stylelint_fix to auto-fix." "stylelint_check"
fi

# ============================================================================
# Prettier - Use prettier_check or prettier_fix (Admin only)
# ============================================================================

if runs_npm_script 'format'; then
    block_tool "js-admin-tooling" \
        "Use prettier_check to verify formatting." "prettier_check"
fi

if runs_npm_script 'format:fix'; then
    block_tool "js-admin-tooling" \
        "Use prettier_fix to auto-format files." "prettier_fix"
fi

if runs_binary prettier; then
    block_tool "js-admin-tooling" \
        "Use prettier_check to verify formatting or prettier_fix to auto-format." "prettier_check"
fi

# ============================================================================
# Jest - Use jest_run
# ============================================================================

if runs_npm_script 'unit'; then
    block_tool "js-admin-tooling" \
        "Use jest_run with testPathPatterns, testNamePattern, coverage options." "jest_run"
fi

if runs_binary jest; then
    block_tool "js-admin-tooling" \
        "Use jest_run with testPathPatterns, testNamePattern, coverage options." "jest_run"
fi

# ============================================================================
# TypeScript - Use tsc_check (Admin only)
# ============================================================================

if runs_npm_script 'lint:types'; then
    block_tool "js-admin-tooling" \
        "Use tsc_check for TypeScript type checking." "tsc_check"
fi

if runs_binary tsc; then
    block_tool "js-admin-tooling" \
        "Use tsc_check for TypeScript type checking." "tsc_check"
fi

# ============================================================================
# Combined Lint - Use lint_all, lint_twig (Admin only)
# ============================================================================

if runs_npm_script 'lint:all'; then
    block_tool "js-admin-tooling" \
        "Use lint_all to run all lint checks (TypeScript, ESLint, Stylelint, Prettier)." "lint_all"
fi

if runs_npm_script 'lint:twig'; then
    block_tool "js-admin-tooling" \
        "Use lint_twig for Twig template linting." "lint_twig"
fi

# ============================================================================
# Build - Use vite_build (Admin only)
# ============================================================================

if runs_npm_script 'build'; then
    block_tool "js-admin-tooling" \
        "Use vite_build with mode (development/production) option." "vite_build"
fi

exit 0
