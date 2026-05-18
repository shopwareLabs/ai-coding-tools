#!/usr/bin/env bash
# SessionStart hook: inject directive to run ChunkHound operations
# sequentially across subagents. Reads the static prompt from hooks/prompts/
# and emits it as JSON additionalContext.
set -euo pipefail

cat > /dev/null  # drain stdin

HOOK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT_FILE="${HOOK_DIR}/prompts/sequential-chunkhound-directives.md"

[[ ! -f "${PROMPT_FILE}" ]] && exit 0

context=$(jq -Rs '.' < "${PROMPT_FILE}")

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ${context}
  }
}
EOF

exit 0
