#!/usr/bin/env bash
# SessionStart hook: inject gh-tooling MCP tool usage directives into conversation context.
# Reads prompt from hooks/prompts/mcp-tool-directives.md and outputs to stdout.
# Respects enforce_mcp_tools setting in .mcp-gh-tooling.json.
set -euo pipefail

cat > /dev/null  # drain stdin

HOOK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT_FILE="${HOOK_DIR}/prompts/mcp-tool-directives.md"

# Check if enforcement is enabled. Defaults to true when no config exists.
if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]] && command -v jq &>/dev/null; then
    config_file=""
    for location in ".claude/.mcp-gh-tooling.json" ".mcp-gh-tooling.json"; do
        if [[ -f "${CLAUDE_PROJECT_DIR}/${location}" ]]; then
            config_file="${CLAUDE_PROJECT_DIR}/${location}"
            break
        fi
    done

    if [[ -n "$config_file" ]]; then
        val=$(jq -r 'if .enforce_mcp_tools == false then "false" else "true" end' "$config_file" 2>/dev/null || echo "true")
        [[ "$val" == "false" ]] && exit 0
    fi
fi

# Output as JSON additionalContext (matching official plugin pattern)
if [[ -f "$PROMPT_FILE" ]]; then
    context=$(jq -Rs '.' "$PROMPT_FILE")
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ${context}
  }
}
EOF
fi

exit 0
