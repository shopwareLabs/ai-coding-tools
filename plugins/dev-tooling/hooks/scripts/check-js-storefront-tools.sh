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
    # Storefront-specific npm scripts. eslint:app, eslint:components and
    # stylelint:app are declared only by the Storefront package.json; without
    # them here the Admin hook's unknown-context fallback would claim them and
    # name the wrong server's tool.
    # `:` is absent from the trailing `(\s|$)` alternation, so a bare `lint:js`
    # alternative never covers the longer colon-suffixed names — lint:js:fix and
    # the lint:js:app / lint:js:components pairs need the explicit suffix group
    # or the whole family misses this detector. No Administration script name
    # begins with `lint:js`, so the group cannot claim an Admin command.
    if echo "$COMMAND" | grep -qE 'npm\s+run\s+(lint:js(:[A-Za-z]+)*|production|development|eslint:app|eslint:components|stylelint:app)(\s|$)'; then
        return 0
    fi
    # Storefront component test scripts (Vitest)
    if echo "$COMMAND" | grep -qE 'npm\s+run\s+unit:components(:watch|:coverage)?(\s|$)'; then
        return 0
    fi
    # ludtwig only lints Storefront Twig templates
    if echo "$COMMAND" | grep -qE '(^|;|&&|\||[[:space:]])ludtwig(\s|:|$)'; then
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

# Target-less base scripts the MCP tools route path-scoped runs at
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+eslint:app(\s|--|$)'; then
    block_tool "mcp__js-storefront-tooling__eslint_check" \
        "Use eslint_check with paths for linting, or eslint_fix with paths to auto-fix."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+eslint:components(\s|--|$)'; then
    block_tool "mcp__js-storefront-tooling__eslint_check" \
        "Use eslint_check with paths under views/components/ for linting, or eslint_fix to auto-fix."
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

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+stylelint:app(\s|--|$)'; then
    block_tool "mcp__js-storefront-tooling__stylelint_check" \
        "Use stylelint_check with paths for SCSS/CSS linting, or stylelint_fix with paths to auto-fix."
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
        "Use jest_run with testPathPatterns, testNamePattern, coverage options."
fi

# jest:base is declared by both packages, so it reaches this block only when
# the command names the Storefront tree; a bare invocation stays with the Admin
# hook's unknown-context fallback.
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+jest:base(\s|--|$)'; then
    block_tool "mcp__js-storefront-tooling__jest_run" \
        "Use jest_run with testPathPatterns, testNamePattern, coverage, ci options."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npx\s+jest(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__jest_run" \
        "Use jest_run with testPathPatterns, testNamePattern, coverage options."
fi

# ============================================================================
# Vitest (views/components component suite) - Use vitest_run
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+unit:components(:watch|:coverage)?(\s|--|$)'; then
    block_tool "mcp__js-storefront-tooling__vitest_run" \
        "Use vitest_run with paths, testNamePattern, coverage options."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npx\s+vitest(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__vitest_run" \
        "Use vitest_run with paths, testNamePattern, coverage options."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+storefront:components:unit(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__vitest_run" \
        "Use vitest_run with paths, testNamePattern, coverage options."
fi

# ============================================================================
# ludtwig - Use ludtwig_check or ludtwig_fix
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+ludtwig:storefront:fix(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__ludtwig_fix" \
        "Use ludtwig_fix to auto-fix Twig template violations."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+ludtwig:storefront(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__ludtwig_check" \
        "Use ludtwig_check for Twig template linting or ludtwig_fix to auto-fix."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*ludtwig(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__ludtwig_check" \
        "Use ludtwig_check for Twig template linting or ludtwig_fix to auto-fix."
fi

# ============================================================================
# Build - Use webpack_build (Storefront only)
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+(production|development)(\s|$)'; then
    block_tool "mcp__js-storefront-tooling__webpack_build" \
        "Use webpack_build with mode (development/production) option."
fi

exit 0
