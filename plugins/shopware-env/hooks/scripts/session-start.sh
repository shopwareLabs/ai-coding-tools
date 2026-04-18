#!/usr/bin/env bash
# SessionStart hook: inject lifecycle tool directives.
set -euo pipefail

cat > /dev/null  # drain stdin

HOOK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT_FILE="${HOOK_DIR}/prompts/mcp-tool-directives.md"

context=""
if [[ -f "$PROMPT_FILE" ]]; then
    context=$(cat "$PROMPT_FILE")
fi

json_context=$(printf '%s' "${context}" | jq -Rs '.')
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ${json_context}
  }
}
EOF

exit 0
