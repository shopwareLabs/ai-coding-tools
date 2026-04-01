#!/usr/bin/env bash
# SessionStart hook: inject MCP dev tool usage directives into conversation context.
# Reads prompt from hooks/prompts/mcp-tool-directives.md and outputs to stdout.
# Respects enforce_mcp_tools setting per config prefix (php-tooling, js-tooling).
set -euo pipefail

cat > /dev/null  # drain stdin

HOOK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT_FILE="${HOOK_DIR}/prompts/mcp-tool-directives.md"

# Check if MCP tool enforcement is enabled for a config prefix.
# Returns 0 (true) if enforced, 1 (false) if explicitly disabled.
is_enforced() {
    local config_prefix="$1"

    [[ -z "${CLAUDE_PROJECT_DIR:-}" ]] && return 0

    local config_file=""
    for location in ".claude/.mcp-${config_prefix}.json" ".mcp-${config_prefix}.json"; do
        if [[ -f "${CLAUDE_PROJECT_DIR}/${location}" ]]; then
            config_file="${CLAUDE_PROJECT_DIR}/${location}"
            break
        fi
    done

    [[ -z "$config_file" ]] && return 0
    command -v jq &>/dev/null || return 0

    local val
    val=$(jq -r 'if .enforce_mcp_tools == false then "false" else "true" end' "$config_file" 2>/dev/null || echo "true")
    [[ "$val" == "true" ]]
}

# Exit silently if all enforcement is disabled
is_enforced "php-tooling" || is_enforced "js-tooling" || exit 0

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
