#!/bin/bash
# Claude Code Hook: MCP API Tool Enforcer
# =========================================================
# Blocks MCP api/api_read tool calls when a dedicated tool exists.
# Controlled by block_api_tool_read and block_api_tool_write in .mcp-gh-tooling.json.
#
# Exit codes:
#   0 - Call allowed
#   2 - Call blocked (message shown to Claude)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

INPUT=$(cat)
IFS=$'\t' read -r TOOL_NAME ENDPOINT METHOD < <(
    printf '%s' "$INPUT" | jq -r '[
        (.tool_name // ""),
        (.tool_input.endpoint // ""),
        (.tool_input.method // "GET")
    ] | @tsv'
)

# Need endpoint to check
[[ -z "$ENDPOINT" ]] && exit 0

# Determine read vs write server
IS_WRITE="false"
if [[ "$TOOL_NAME" == *"gh-tooling-write"* ]]; then
    IS_WRITE="true"
fi

# Load config
CONFIG_FILE=""
if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    for location in ".claude/.mcp-gh-tooling.json" ".mcp-gh-tooling.json"; do
        if [[ -f "${CLAUDE_PROJECT_DIR}/${location}" ]]; then
            CONFIG_FILE="${CLAUDE_PROJECT_DIR}/${location}"
            break
        fi
    done
fi

# ENVIRONMENT must be set for block_tool (which references it); not applicable here
ENVIRONMENT=""

# Check the appropriate config flag
BLOCK="false"
if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
    if [[ "$IS_WRITE" == "true" ]]; then
        BLOCK=$(jq -r 'if .block_api_tool_write == true then "true" else "false" end' "$CONFIG_FILE" 2>/dev/null || echo "false")
    else
        BLOCK=$(jq -r 'if .block_api_tool_read == true then "true" else "false" end' "$CONFIG_FILE" 2>/dev/null || echo "false")
    fi
fi

[[ "$BLOCK" != "true" ]] && exit 0

# Set COMMAND for block_tool (it reads the global)
COMMAND="api ${METHOD} ${ENDPOINT}"

# ============================================================================
# Read endpoint mapping (GET requests with dedicated read tools)
# ============================================================================

# PR data
if echo "$ENDPOINT" | grep -qE 'pulls/[0-9]+/comments'; then
    block_tool "pr_comments" "Use pr_comments with number and optional jq_filter."
fi

if echo "$ENDPOINT" | grep -qE 'pulls/[0-9]+/reviews'; then
    block_tool "pr_reviews" "Use pr_reviews with number and optional jq_filter."
fi

if echo "$ENDPOINT" | grep -qE 'pulls/[0-9]+/files'; then
    block_tool "pr_files" "Use pr_files with number and optional jq_filter."
fi

if echo "$ENDPOINT" | grep -qE 'pulls/[0-9]+/commits'; then
    block_tool "pr_commits" "Use pr_commits with number and optional jq_filter."
fi

# Job data — check logs before bare job ID
if echo "$ENDPOINT" | grep -qE 'actions/jobs/[0-9]+/logs'; then
    block_tool "job_logs" "Use job_logs with job_id and optional max_lines."
fi

if echo "$ENDPOINT" | grep -qE 'actions/jobs/[0-9]+(/|$)' && ! echo "$ENDPOINT" | grep -qE 'actions/jobs/[0-9]+/logs'; then
    block_tool "job_view" "Use job_view with job_id and optional jq_filter."
fi

if echo "$ENDPOINT" | grep -qE 'check-runs/[0-9]+/annotations'; then
    block_tool "job_annotations" "Use job_annotations with check_run_id and optional jq_filter."
fi

# Commit PR associations
if echo "$ENDPOINT" | grep -qE 'commits/[0-9a-fA-F]+/pulls'; then
    block_tool "commit_pulls" "Use commit_pulls with sha."
fi

# Repo browsing
if echo "$ENDPOINT" | grep -qE 'git/trees/'; then
    block_tool "repo_tree" "Use repo_tree with owner, repo, ref, and optional recursive parameter."
fi

if echo "$ENDPOINT" | grep -qE 'contents/'; then
    block_tool "repo_tree or repo_file" "Use repo_tree for directory listings or repo_file for file content."
fi

# Labels
if echo "$ENDPOINT" | grep -qE 'labels(\?|$)'; then
    block_tool "label_list" "Use label_list with optional repo and filter parameters."
fi

# ============================================================================
# Write endpoint mapping (POST/PATCH/PUT/DELETE with dedicated write tools)
# Only checked when IS_WRITE is true (write server's api tool)
# ============================================================================

if [[ "$IS_WRITE" == "true" ]]; then

    # Create PR
    if [[ "$METHOD" == "POST" ]] && echo "$ENDPOINT" | grep -qE 'repos/[^/]+/[^/]+/pulls$'; then
        block_tool "pr_create" "Use pr_create with title, body, labels, assignees, and reviewers."
    fi

    # Merge PR
    if [[ "$METHOD" == "PUT" ]] && echo "$ENDPOINT" | grep -qE 'pulls/[0-9]+/merge'; then
        block_tool "pr_merge" "Use pr_merge with number and method (merge/squash/rebase)."
    fi

    # Create issue
    if [[ "$METHOD" == "POST" ]] && echo "$ENDPOINT" | grep -qE 'repos/[^/]+/[^/]+/issues$'; then
        block_tool "issue_create" "Use issue_create with title, body, labels, and assignees."
    fi

    # Issue/PR comments (POST)
    if [[ "$METHOD" == "POST" ]] && echo "$ENDPOINT" | grep -qE 'issues/[0-9]+/comments'; then
        block_tool "issue_comment" "Use issue_comment with number and body."
    fi

    # PR review comments (POST)
    if [[ "$METHOD" == "POST" ]] && echo "$ENDPOINT" | grep -qE 'pulls/[0-9]+/comments$'; then
        block_tool "pr_review_comment" "Use pr_review_comment with number, body, path, and line."
    fi

    # PR reviews (POST)
    if [[ "$METHOD" == "POST" ]] && echo "$ENDPOINT" | grep -qE 'pulls/[0-9]+/reviews$'; then
        block_tool "pr_review" "Use pr_review with number, event, and body."
    fi

fi

exit 0
