#!/usr/bin/env bash
# SessionStart hook: inject gh-tooling MCP tool usage directives into conversation context.
# Reads template from hooks/prompts/mcp-tool-directives.md, assembles dynamic sections
# from .mcp-gh-tooling.json config, and outputs to stdout as JSON additionalContext.
set -euo pipefail

cat > /dev/null  # drain stdin

HOOK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT_FILE="${HOOK_DIR}/prompts/mcp-tool-directives.md"

# Find config file
config_file=""
if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]] && command -v jq &>/dev/null; then
    for location in ".claude/.mcp-gh-tooling.json" ".mcp-gh-tooling.json"; do
        if [[ -f "${CLAUDE_PROJECT_DIR}/${location}" ]]; then
            config_file="${CLAUDE_PROJECT_DIR}/${location}"
            break
        fi
    done

    # Check enforcement
    if [[ -n "$config_file" ]]; then
        val=$(jq -r 'if .enforce_mcp_tools == false then "false" else "true" end' "$config_file" 2>/dev/null || echo "true")
        [[ "$val" == "false" ]] && exit 0
    fi
fi

[[ ! -f "$PROMPT_FILE" ]] && exit 0

# Read template
template=$(<"$PROMPT_FILE")

# Build write section
write_section=""
write_enabled="false"
if [[ -n "$config_file" ]]; then
    write_enabled=$(jq -r 'if .enable_write_server == true then "true" else "false" end' "$config_file" 2>/dev/null || echo "false")
fi

if [[ "$write_enabled" == "true" ]]; then
    write_section='## Write Operations (gh-tooling-write)
PR lifecycle: pr_create, pr_edit, pr_ready, pr_merge, pr_close, pr_reopen
Reviews: pr_review, pr_comment, pr_review_comment
Issues: issue_create, issue_edit, issue_close, issue_reopen, issue_comment
Labels: label_add, label_remove
Assignees: assignee_add, assignee_remove
Sub-issues: sub_issue_add, sub_issue_remove
Projects: project_item_add, project_status_set
API: api (all methods — POST, PATCH, PUT, DELETE)

Call these tools sequentially — never in parallel.'
else
    write_section='## Write Operations
Write operations are disabled. Do not attempt to create, edit, or modify GitHub resources.'
fi

# Build label section
label_section=""
if [[ -n "$config_file" ]]; then
    local_has_labels=$(jq 'has("labels") and (.labels | length > 0)' "$config_file" 2>/dev/null || echo "false")
    if [[ "$local_has_labels" == "true" ]]; then
        label_section="## Label Definitions
When adding, removing, or suggesting labels, use these definitions:"
        while IFS=$'\t' read -r name desc; do
            label_section+=$'\n'"- ${name}: ${desc}"
        done < <(jq -r '.labels | to_entries[] | [.key, .value] | @tsv' "$config_file")
    fi
fi

# Assemble: replace placeholders
assembled="${template/\{\{WRITE_SECTION\}\}/$write_section}"
assembled="${assembled/\{\{LABEL_SECTION\}\}/$label_section}"

# Output as JSON additionalContext
context=$(printf '%s' "$assembled" | jq -Rs '.')
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ${context}
  }
}
EOF

exit 0
