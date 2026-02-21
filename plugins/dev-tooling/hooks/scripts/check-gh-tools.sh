#!/bin/bash
# Claude Code Hook: Dev Tooling MCP Enforcer (GitHub CLI)
# =========================================================
# Blocks common gh CLI bash commands in favor of gh-tooling MCP tools.
# Controlled by two fields in .mcp-gh-tooling.json:
#   enforce_mcp_tools: true (default) - blocks high-level gh subcommands
#   block_api_commands: true (opt-in)  - additionally blocks 'gh api' calls for
#                                        endpoints covered by dedicated MCP tools
#
# Exit codes:
#   0 - Command allowed
#   2 - Command blocked (message shown to Claude)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

parse_hook_input
load_mcp_config "gh-tooling"

# Explicit == true check mirrors jq boolean handling in common.sh; opt-in, defaults false.
BLOCK_API_COMMANDS="false"
if [[ -n "${CONFIG_FILE:-}" && -f "$CONFIG_FILE" ]]; then
    api_block_value=$(jq -r 'if .block_api_commands == true then "true" else "false" end' \
        "$CONFIG_FILE" 2>/dev/null || echo "false")
    BLOCK_API_COMMANDS="$api_block_value"
fi

# ============================================================================
# PR operations - Use mcp__gh-tooling__pr_*
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+pr\s+view(\s|$)'; then
    block_tool "mcp__gh-tooling__pr_view" \
        "Use pr_view with number, repo, and optional fields or comments parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+pr\s+diff(\s|$)'; then
    block_tool "mcp__gh-tooling__pr_diff" \
        "Use pr_diff with number and optional file (single-file filter) or name_only parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+pr\s+list(\s|$)'; then
    block_tool "mcp__gh-tooling__pr_list" \
        "Use pr_list with author, state, search, head, and limit parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+pr\s+checks(\s|$)'; then
    block_tool "mcp__gh-tooling__pr_checks" \
        "Use pr_checks with number to view CI check status for a PR."
fi

# ============================================================================
# Issue operations - Use mcp__gh-tooling__issue_*
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+issue\s+view(\s|$)'; then
    block_tool "mcp__gh-tooling__issue_view" \
        "Use issue_view with number and optional fields or with_comments parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+issue\s+list(\s|$)'; then
    block_tool "mcp__gh-tooling__issue_list" \
        "Use issue_list with search, state, label, and limit parameters."
fi

# ============================================================================
# Actions/CI run operations - Use mcp__gh-tooling__run_*
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+run\s+view(\s|$)'; then
    block_tool "mcp__gh-tooling__run_view or run_logs" \
        "Use run_view for status summary or run_logs (with failed_only and max_lines) for log output."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+run\s+list(\s|$)'; then
    block_tool "mcp__gh-tooling__run_list" \
        "Use run_list with branch and limit parameters."
fi

# ============================================================================
# Search operations - Use mcp__gh-tooling__search
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+search(\s|$)'; then
    block_tool "mcp__gh-tooling__search" \
        "Use search with query, type (issues/prs), repo, state, and limit parameters."
fi

# ============================================================================
# gh api endpoint blocking (opt-in via block_api_commands: true)
# Only blocks endpoints that have a dedicated gh-tooling MCP tool.
# More-specific paths (e.g. /logs) are checked before less-specific ones.
# Other gh api calls (runs, issues, search, etc.) are NOT blocked here.
# ============================================================================

if [[ "$BLOCK_API_COMMANDS" == "true" ]]; then

    # PR inline review comments → pr_comments
    if echo "$COMMAND" | grep -qE 'gh\s+api\s+repos/[^/[:space:]]+/[^/[:space:]]+/pulls/[0-9]+/comments'; then
        block_tool "mcp__gh-tooling__pr_comments" \
            "Use pr_comments with number and optional jq_filter or paginate parameters."
    fi

    if echo "$COMMAND" | grep -qE 'gh\s+api\s+repos/[^/[:space:]]+/[^/[:space:]]+/pulls/[0-9]+/reviews'; then
        block_tool "mcp__gh-tooling__pr_reviews" \
            "Use pr_reviews with number and optional jq_filter."
    fi

    if echo "$COMMAND" | grep -qE 'gh\s+api\s+repos/[^/[:space:]]+/[^/[:space:]]+/pulls/[0-9]+/files'; then
        block_tool "mcp__gh-tooling__pr_files" \
            "Use pr_files with number and optional jq_filter."
    fi

    if echo "$COMMAND" | grep -qE 'gh\s+api\s+repos/[^/[:space:]]+/[^/[:space:]]+/pulls/[0-9]+/commits'; then
        block_tool "mcp__gh-tooling__pr_commits" \
            "Use pr_commits with number and optional jq_filter."
    fi

    # Job raw logs — check before bare job ID to avoid false match → job_logs
    if echo "$COMMAND" | grep -qE 'gh\s+api\s+repos/[^/[:space:]]+/[^/[:space:]]+/actions/jobs/[0-9]+/logs'; then
        block_tool "mcp__gh-tooling__job_logs" \
            "Use job_logs with job_id and optional max_lines."
    fi

    # Job details (bare job ID, no /logs suffix) → job_view
    if echo "$COMMAND" | grep -qE 'gh\s+api\s+repos/[^/[:space:]]+/[^/[:space:]]+/actions/jobs/[0-9]+(\s|$)'; then
        block_tool "mcp__gh-tooling__job_view" \
            "Use job_view with job_id and optional jq_filter."
    fi

    if echo "$COMMAND" | grep -qE 'gh\s+api\s+repos/[^/[:space:]]+/[^/[:space:]]+/check-runs/[0-9]+/annotations'; then
        block_tool "mcp__gh-tooling__job_annotations" \
            "Use job_annotations with check_run_id and optional jq_filter."
    fi

    # Commit info (covers bare SHA and SHA/pulls) → commit_info
    if echo "$COMMAND" | grep -qE 'gh\s+api\s+repos/[^/[:space:]]+/[^/[:space:]]+/commits/[0-9a-fA-F]+'; then
        block_tool "mcp__gh-tooling__commit_info" \
            "Use commit_info with sha and optional fields or include_pulls parameters."
    fi

fi

exit 0
