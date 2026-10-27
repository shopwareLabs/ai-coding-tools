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
source "${SCRIPT_DIR}/lib/js_binary.sh"

parse_hook_input
load_mcp_config "js-tooling"

# Check if command is in Storefront context
is_storefront_context() {
    # Path-based detection (case-insensitive). views/components is the
    # Storefront component tree, named relative to src/Storefront/Resources.
    if echo "$COMMAND" | grep -qiE 'Storefront|/app/storefront|views/components'; then
        return 0
    fi
    # Storefront-specific npm scripts.
    # `:` is absent from NAME_END, so a bare `lint:js` alternative never covers
    # lint:js:fix; the suffix group does. No Administration script name begins
    # with `lint:js`, so the group cannot claim an Admin command.
    if echo "$COMMAND" | grep -qE "${NPM_RUN}(lint:js(:[A-Za-z]+)*|production|development)${NAME_END}"; then
        return 0
    fi
    # Storefront component test scripts (Vitest)
    if echo "$COMMAND" | grep -qE "${NPM_RUN}unit:components(:watch|:coverage)?${NAME_END}"; then
        return 0
    fi
    # ludtwig only lints Storefront Twig templates. The tail is NAME_END plus
    # `:` (ludtwig:storefront), so `ludtwig;` reaches the block rows.
    if echo "$COMMAND" | grep -qE '(^|;|&&|\||[[:space:]])ludtwig([[:space:];&|<>):]|$)'; then
        return 0
    fi
    # Not Storefront context
    return 1
}

# Only process if in Storefront context
if ! is_storefront_context; then
    exit 0
fi

# Composer's script runner, with its global options and an optional `run` /
# `run-script` subcommand; COMPOSER_RUN comes from lib/js_binary.sh, shared with
# the PHP hook.
COMPOSER_SCRIPT="${COMMAND_POSITION}${COMPOSER_RUN}"

# ============================================================================
# ESLint - Use eslint_check or eslint_fix
# ============================================================================

# Storefront-specific ESLint (lint:js)
if runs_npm_script 'lint:js'; then
    block_tool "js-storefront-tooling" \
        "Use eslint_check for linting." "eslint_check"
fi

if runs_npm_script 'lint:js:fix'; then
    block_tool "js-storefront-tooling" \
        "Use eslint_fix to auto-fix ESLint violations." "eslint_fix"
fi

# The Storefront `lint` runs ESLint, then Stylelint; `lint-fix` runs both fixers.
if runs_npm_script 'lint'; then
    block_tool "js-storefront-tooling" \
        "npm run lint runs ESLint and Stylelint: use eslint_check for ESLint and stylelint_check for Stylelint." \
        "eslint_check" "stylelint_check"
fi

if runs_npm_script 'lint-fix'; then
    block_tool "js-storefront-tooling" \
        "npm run lint-fix runs the ESLint and Stylelint fixers: use eslint_fix for ESLint and stylelint_fix for Stylelint." \
        "eslint_fix" "stylelint_fix"
fi

if runs_binary eslint; then
    block_tool "js-storefront-tooling" \
        "Use eslint_check for linting or eslint_fix to auto-fix." "eslint_check"
fi

# ============================================================================
# Stylelint - Use stylelint_check or stylelint_fix
# ============================================================================

if runs_npm_script 'lint:scss'; then
    block_tool "js-storefront-tooling" \
        "Use stylelint_check for SCSS/CSS linting." "stylelint_check"
fi

if runs_npm_script 'lint:scss-fix'; then
    block_tool "js-storefront-tooling" \
        "Use stylelint_fix to auto-fix Stylelint violations." "stylelint_fix"
fi

if runs_binary stylelint; then
    block_tool "js-storefront-tooling" \
        "Use stylelint_check for SCSS/CSS linting or stylelint_fix to auto-fix." "stylelint_check"
fi

# ============================================================================
# Jest - Use jest_run
# ============================================================================

if runs_npm_script 'unit'; then
    block_tool "js-storefront-tooling" \
        "Use jest_run with testPathPatterns, testNamePattern, coverage options." "jest_run"
fi

if runs_binary jest; then
    block_tool "js-storefront-tooling" \
        "Use jest_run with testPathPatterns, testNamePattern, coverage options." "jest_run"
fi

# ============================================================================
# Vitest (views/components component suite) - Use vitest_run
# ============================================================================

if runs_npm_script 'unit:components(:watch|:coverage)?'; then
    block_tool "js-storefront-tooling" \
        "Use vitest_run with paths, testNamePattern, coverage options." "vitest_run"
fi

if runs_binary vitest; then
    block_tool "js-storefront-tooling" \
        "Use vitest_run with paths, testNamePattern, coverage options." "vitest_run"
fi

if echo "$COMMAND" | grep -qE "${COMPOSER_SCRIPT}storefront:components:unit${NAME_END}"; then
    block_tool "js-storefront-tooling" \
        "Use vitest_run with paths, testNamePattern, coverage options." "vitest_run"
fi

# ============================================================================
# ludtwig - Use ludtwig_check or ludtwig_fix
# ============================================================================

if echo "$COMMAND" | grep -qE "${COMPOSER_SCRIPT}ludtwig:storefront:fix${NAME_END}"; then
    block_tool "js-storefront-tooling" \
        "Use ludtwig_fix to auto-fix Twig template violations." "ludtwig_fix"
fi

if echo "$COMMAND" | grep -qE "${COMPOSER_SCRIPT}ludtwig:storefront${NAME_END}"; then
    block_tool "js-storefront-tooling" \
        "Use ludtwig_check for Twig template linting or ludtwig_fix to auto-fix." "ludtwig_check"
fi

# A plain-whitespace leading boundary (matching the context detector's) would
# turn any incidental mention of the word — e.g. a commit message — into a
# hard block. block_tool denies with exit 2, unlike the detector's own
# classify-only check, so the boundary here stays anchored to a command
# position: the token itself, or a known runner invoking it directly.
# The runner and the token are separated by zero or more option words and an
# optional `--`, because Composer *requires* `composer exec -- ludtwig` as soon
# as ludtwig takes its own options — the likeliest real invocation is the one
# with the separator, and `npx -y` / `pnpm dlx --` are the same shape.
if echo "$COMMAND" | grep -qE "${COMMAND_POSITION}ludtwig${NAME_END}|${COMMAND_POSITION}(composer\s+exec|npm\s+(exec|x)|npx|pnpm\s+exec|pnpm\s+dlx|bunx|yarn\s+exec|yarn\s+run)(\s+(--?[A-Za-z0-9][-A-Za-z0-9]*|--))*\s+ludtwig${NAME_END}"; then
    block_tool "js-storefront-tooling" \
        "Use ludtwig_check for Twig template linting or ludtwig_fix to auto-fix." "ludtwig_check"
fi

# ============================================================================
# Build - Use webpack_build (Storefront only)
# ============================================================================

if runs_npm_script 'production|development'; then
    block_tool "js-storefront-tooling" \
        "Use webpack_build with mode (development/production) option." "webpack_build"
fi

exit 0
