#!/bin/bash
# Claude Code Hook: Dev Tooling MCP Enforcer (Storefront JavaScript)
# ===================================================================
# Blocks Storefront JS dev tool bash commands in favor of MCP tools.
#
# Exit codes:
#   0 - Command allowed
#   2 - Command blocked (message shown to Claude)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

parse_hook_input
load_mcp_config "js-tooling"

# Check if command is in Storefront context
is_storefront_context() {
    # Path-based detection (case-insensitive)
    if echo "$COMMAND" | grep -qiE 'Storefront|/app/storefront'; then
        return 0
    fi
    # Storefront-specific npm scripts
    if echo "$COMMAND" | grep -qE 'npm\s+run\s+(lint:js|production|development)(\s|$)'; then
        return 0
    fi
    # Not Storefront context
    return 1
}

# Only process if in Storefront context
if ! is_storefront_context; then
    exit 0
fi

# ============================================================================
# ESLint - Use eslint_check or eslint_fix
# ============================================================================

# Storefront-specific ESLint (lint:js)
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:js(\s|--|$)'; then
    block_tool "mcp__js-storefront-tooling__eslint_check" \
        "Use eslint_check for linting."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:js:fix(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__eslint_fix" \
        "Use eslint_fix to auto-fix ESLint violations."
fi

# Generic lint in Storefront context
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint(\s|--|$)'; then
    block_tool "mcp__js-storefront-tooling__eslint_check" \
        "Use eslint_check for linting or eslint_fix to auto-fix."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:fix(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__eslint_fix" \
        "Use eslint_fix to auto-fix ESLint violations."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npx\s+eslint(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__eslint_check" \
        "Use eslint_check for linting or eslint_fix to auto-fix."
fi

# ============================================================================
# Stylelint - Use stylelint_check or stylelint_fix
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:scss(\s|--|$)'; then
    block_tool "mcp__js-storefront-tooling__stylelint_check" \
        "Use stylelint_check for SCSS/CSS linting."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:scss-fix(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__stylelint_fix" \
        "Use stylelint_fix to auto-fix Stylelint violations."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npx\s+stylelint(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__stylelint_check" \
        "Use stylelint_check for SCSS/CSS linting or stylelint_fix to auto-fix."
fi

# ============================================================================
# Jest - Use jest_run
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+unit(\s|--|$)'; then
    block_tool "mcp__js-storefront-tooling__jest_run" \
        "Use jest_run with testPathPattern, testNamePattern, coverage options."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npx\s+jest(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__jest_run" \
        "Use jest_run with testPathPattern, testNamePattern, coverage options."
fi

# ============================================================================
# Build - Use webpack_build (Storefront only)
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+(production|development)(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__webpack_build" \
        "Use webpack_build with mode (development/production) option."
fi

exit 0
