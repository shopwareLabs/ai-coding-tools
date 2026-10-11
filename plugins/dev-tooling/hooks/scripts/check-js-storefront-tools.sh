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
    # stylelint:app are Storefront names; without them here the Admin hook's
    # unknown-context fallback would claim them and name the wrong server's
    # tool.
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

# A direct run of a tool binary (a linter, jest, tsc or vitest) at a command
# position: `npx`, `npm exec` or `npm x` invoking it, or its node_modules/.bin path. The
# runner and the binary are separated by zero or more of the listed flags that
# take no value, and an optional `--` (`npx --no-install eslint`,
# `npm exec --no -- prettier`). A flag that takes a value
# (`--package eslint some-tool`) is not listed: its value would read as the
# binary and block a command that does not run it. A version suffix
# (`npx eslint@9`) is allowed after the binary. A bare `eslint` is not matched:
# the word sits at a command position inside any quoted text that follows `;`,
# `&&` or `|`, so a commit message would turn into a hard block. `npm x` is
# matched wherever `npm exec` is.
BINARY_INVOCATION='(^|;|&&|\|)\s*((npm\s+(exec|x)|npx)(\s+(-y|--yes|--no|--no-install|-q|--quiet|--silent|--))*\s+|\S*node_modules/\.bin/)'

# The -c / --call form of the same runners takes a command string; the binary
# is matched at a command position inside it: its start, or after `;`, `&&` or
# `|` within the string, past leading blanks and variable assignments
# (`npm exec --no -c "cd ../.. && eslint views/components"`, the form the MCP
# tools run). Before -c, the flags above and --package, -p, --workspace, -w with
# their value are allowed: with -c the string, not the package, names what runs.
# A closing quote may follow the binary.
CALL_INVOCATION="(^|;|&&|\|)\s*(npm\s+(exec|x)|npx)(\s+(-y|--yes|--no|--no-install|-q|--quiet|--silent|(--package|--workspace|-p|-w)(=|\s+)[^[:space:]\"';&|]+))*\s+(-c|--call)(\s+|=)[\"']?\s*([^\"';&|]*(;|&&|\|)\s*)*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]\"';&|]*\s+)*"

# Args: $1 = binary name
# Returns: 0 when the command runs the binary in one of the forms above
runs_binary() {
    echo "$COMMAND" | grep -qE "${BINARY_INVOCATION}$1(@\S+)?(\s|\$)" \
        || echo "$COMMAND" | grep -qE "${CALL_INVOCATION}$1(@\S+)?(\s|\$|[\"'])"
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
    block_tool "js-storefront-tooling" \
        "Use eslint_check for linting." "eslint_check"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:js:fix(\s|$)'; then
    block_tool "js-storefront-tooling" \
        "Use eslint_fix to auto-fix ESLint violations." "eslint_fix"
fi

# lint:js and lint:js:fix each chain the two per-tree scripts below, which are
# reachable on their own too.
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:js:app(\s|--|$)'; then
    block_tool "js-storefront-tooling" \
        "Use eslint_check with paths for linting, or eslint_fix with paths to auto-fix." "eslint_check"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:js:components(\s|--|$)'; then
    block_tool "js-storefront-tooling" \
        "Use eslint_check with paths under views/components/ for linting, or eslint_fix to auto-fix." "eslint_check"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:js:app:fix(\s|$)'; then
    block_tool "js-storefront-tooling" \
        "Use eslint_fix with paths to auto-fix ESLint violations." "eslint_fix"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:js:components:fix(\s|$)'; then
    block_tool "js-storefront-tooling" \
        "Use eslint_fix with paths under views/components/ to auto-fix ESLint violations." "eslint_fix"
fi

# Generic lint in Storefront context
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint(\s|--|$)'; then
    block_tool "js-storefront-tooling" \
        "Use eslint_check for linting or eslint_fix to auto-fix." "eslint_check"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:fix(\s|$)'; then
    block_tool "js-storefront-tooling" \
        "Use eslint_fix to auto-fix ESLint violations." "eslint_fix"
fi

# Target-less base scripts. Shopware's Storefront package.json does not define
# them and the MCP tools no longer call them; the redirects stay for a project
# that does.
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+eslint:app(\s|--|$)'; then
    block_tool "js-storefront-tooling" \
        "Use eslint_check with paths for linting, or eslint_fix with paths to auto-fix." "eslint_check"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+eslint:components(\s|--|$)'; then
    block_tool "js-storefront-tooling" \
        "Use eslint_check with paths under views/components/ for linting, or eslint_fix to auto-fix." "eslint_check"
fi

if runs_binary eslint; then
    block_tool "js-storefront-tooling" \
        "Use eslint_check for linting or eslint_fix to auto-fix." "eslint_check"
fi

# ============================================================================
# Stylelint - Use stylelint_check or stylelint_fix
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:scss(\s|--|$)'; then
    block_tool "js-storefront-tooling" \
        "Use stylelint_check for SCSS/CSS linting." "stylelint_check"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+lint:scss-fix(\s|$)'; then
    block_tool "js-storefront-tooling" \
        "Use stylelint_fix to auto-fix Stylelint violations." "stylelint_fix"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+stylelint:app(\s|--|$)'; then
    block_tool "js-storefront-tooling" \
        "Use stylelint_check with paths for SCSS/CSS linting, or stylelint_fix with paths to auto-fix." "stylelint_check"
fi

if runs_binary stylelint; then
    block_tool "js-storefront-tooling" \
        "Use stylelint_check for SCSS/CSS linting or stylelint_fix to auto-fix." "stylelint_check"
fi

# ============================================================================
# Jest - Use jest_run
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+unit(\s|--|$)'; then
    block_tool "js-storefront-tooling" \
        "Use jest_run with testPathPatterns, testNamePattern, coverage options." "jest_run"
fi

# jest:base carries no side-specific marker, so it reaches this block only when
# the command names the Storefront tree; a bare invocation stays with the Admin
# hook's unknown-context fallback.
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+jest:base(\s|--|$)'; then
    block_tool "js-storefront-tooling" \
        "Use jest_run with testPathPatterns, testNamePattern, coverage, ci options." "jest_run"
fi

if runs_binary jest; then
    block_tool "js-storefront-tooling" \
        "Use jest_run with testPathPatterns, testNamePattern, coverage options." "jest_run"
fi

# ============================================================================
# Vitest (views/components component suite) - Use vitest_run
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+unit:components(:watch|:coverage)?(\s|--|$)'; then
    block_tool "js-storefront-tooling" \
        "Use vitest_run with paths, testNamePattern, coverage options." "vitest_run"
fi

if runs_binary vitest; then
    block_tool "js-storefront-tooling" \
        "Use vitest_run with paths, testNamePattern, coverage options." "vitest_run"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+storefront:components:unit(\s|$)'; then
    block_tool "js-storefront-tooling" \
        "Use vitest_run with paths, testNamePattern, coverage options." "vitest_run"
fi

# ============================================================================
# ludtwig - Use ludtwig_check or ludtwig_fix
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+ludtwig:storefront:fix(\s|$)'; then
    block_tool "js-storefront-tooling" \
        "Use ludtwig_fix to auto-fix Twig template violations." "ludtwig_fix"
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+ludtwig:storefront(\s|$)'; then
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
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*ludtwig(\s|$)|(^|;|&&|\|)\s*(composer\s+exec|npm\s+(exec|x)|npx|pnpm\s+exec|pnpm\s+dlx|bunx|yarn\s+exec|yarn\s+run)(\s+(--?[A-Za-z0-9][-A-Za-z0-9]*|--))*\s+ludtwig(\s|$)'; then
    block_tool "js-storefront-tooling" \
        "Use ludtwig_check for Twig template linting or ludtwig_fix to auto-fix." "ludtwig_check"
fi

# ============================================================================
# Build - Use webpack_build (Storefront only)
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+run\s+(production|development)(\s|$)'; then
    block_tool "js-storefront-tooling" \
        "Use webpack_build with mode (development/production) option." "webpack_build"
fi

exit 0
