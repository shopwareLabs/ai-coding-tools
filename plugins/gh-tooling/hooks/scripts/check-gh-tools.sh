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
        "Use run_list with branch, workflow, status, event, user, created, commit, and limit parameters."
fi

# ============================================================================
# Search operations - Use mcp__gh-tooling__search*
# Specific patterns checked before generic catch-all since block_tool exits.
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+search\s+code(\s|$)'; then
    block_tool "mcp__gh-tooling__search_code" \
        "Use search_code with query, repo, language, extension, filename, and limit parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+search\s+repos(\s|$)'; then
    block_tool "mcp__gh-tooling__search_repos" \
        "Use search_repos with query, owner, topic, language, stars, and sort parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+search\s+commits(\s|$)'; then
    block_tool "mcp__gh-tooling__search_commits" \
        "Use search_commits with query, repo, author, author_date, and sort parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+search(\s|$)'; then
    block_tool "mcp__gh-tooling__search" \
        "Use search with query, type (issues/prs), repo, state, and limit parameters."
fi

# ============================================================================
# PR write operations - Use mcp__gh-tooling-write__pr_*
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+pr\s+create(\s|$)'; then
    block_tool "mcp__gh-tooling-write__pr_create" \
        "Use pr_create with title, body, labels, assignees, reviewers, and draft parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+pr\s+edit(\s|$)'; then
    block_tool "mcp__gh-tooling-write__pr_edit" \
        "Use pr_edit with number, title, body, labels, and assignees parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+pr\s+ready(\s|$)'; then
    block_tool "mcp__gh-tooling-write__pr_ready" \
        "Use pr_ready with number parameter."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+pr\s+merge(\s|$)'; then
    block_tool "mcp__gh-tooling-write__pr_merge" \
        "Use pr_merge with number, method (merge/squash/rebase), and delete_branch parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+pr\s+close(\s|$)'; then
    block_tool "mcp__gh-tooling-write__pr_close" \
        "Use pr_close with number and optional comment parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+pr\s+reopen(\s|$)'; then
    block_tool "mcp__gh-tooling-write__pr_reopen" \
        "Use pr_reopen with number parameter."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+pr\s+review(\s|$)'; then
    block_tool "mcp__gh-tooling-write__pr_review" \
        "Use pr_review with number, event (approve/request_changes/comment), and body parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+pr\s+comment(\s|$)'; then
    block_tool "mcp__gh-tooling-write__pr_comment" \
        "Use pr_comment with number and body parameters."
fi

# ============================================================================
# Issue write operations - Use mcp__gh-tooling-write__issue_*
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+issue\s+create(\s|$)'; then
    block_tool "mcp__gh-tooling-write__issue_create" \
        "Use issue_create with title, body, labels, and assignees parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+issue\s+edit(\s|$)'; then
    block_tool "mcp__gh-tooling-write__issue_edit" \
        "Use issue_edit with number, title, body, labels, and assignees parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+issue\s+close(\s|$)'; then
    block_tool "mcp__gh-tooling-write__issue_close" \
        "Use issue_close with number, reason, and comment parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+issue\s+reopen(\s|$)'; then
    block_tool "mcp__gh-tooling-write__issue_reopen" \
        "Use issue_reopen with number parameter."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+issue\s+comment(\s|$)'; then
    block_tool "mcp__gh-tooling-write__issue_comment" \
        "Use issue_comment with number and body parameters."
fi

# ============================================================================
# Label operations - Use mcp__gh-tooling__label_list
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+label\s+list(\s|$)'; then
    block_tool "mcp__gh-tooling__label_list" \
        "Use label_list with optional repo and filter parameters."
fi

# ============================================================================
# Project operations - Use mcp__gh-tooling__project_* or write tools
# ============================================================================

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+project\s+item-edit(\s|$)'; then
    block_tool "mcp__gh-tooling-write__project_status_set" \
        "Use project_status_set with number, type, project name, and status name."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+project\s+item-add(\s|$)'; then
    block_tool "mcp__gh-tooling-write__project_item_add" \
        "Use project_item_add with number, type, and project name."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+project\s+view(\s|$)'; then
    block_tool "mcp__gh-tooling__project_view" \
        "Use project_view with number and optional owner parameters."
fi

if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*gh\s+project\s+list(\s|$)'; then
    block_tool "mcp__gh-tooling__project_list" \
        "Use project_list with optional owner parameter."
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

    # Commit PR associations → commit_pulls
    if echo "$COMMAND" | grep -qE 'gh\s+api\s+repos/[^/[:space:]]+/[^/[:space:]]+/commits/[0-9a-fA-F]+/pulls'; then
        block_tool "mcp__gh-tooling__commit_pulls" \
            "Use commit_pulls with sha to list PRs associated with a pushed commit."
    fi

    # Repository tree (Git Trees API) → repo_tree
    if echo "$COMMAND" | grep -qE 'gh\s+api\s+repos/[^/[:space:]]+/[^/[:space:]]+/git/trees/'; then
        block_tool "mcp__gh-tooling__repo_tree" \
            "Use repo_tree with owner, repo, ref, and optional recursive parameter."
    fi

    # Repository contents → repo_tree or repo_file
    if echo "$COMMAND" | grep -qE 'gh\s+api\s+repos/[^/[:space:]]+/[^/[:space:]]+/contents/'; then
        block_tool "mcp__gh-tooling__repo_tree or repo_file" \
            "Use repo_tree for directory listings or repo_file to fetch a single file."
    fi

fi

exit 0
