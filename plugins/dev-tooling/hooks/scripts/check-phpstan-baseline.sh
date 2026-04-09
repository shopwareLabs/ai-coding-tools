#!/bin/bash
# Claude Code Hook: PHPStan Baseline Staleness Check (PostToolUse)
# =================================================================
# After phpstan_analyze runs on specific files, checks whether those
# files have entries in the PHPStan baseline. Stale baseline entries
# only surface during full-project CI runs, so this hook catches them
# early during file-scoped local analysis.
#
# Exit codes:
#   0 - No stale entries found (or not applicable)

set -euo pipefail

INPUT=$(cat)

# Extract paths array from tool_input (single jq call)
PATHS_JSON=$(printf '%s' "$INPUT" | jq -r '.tool_input.paths // empty')

# Skip if no paths provided — full-project runs validate baseline natively
if [[ -z "$PATHS_JSON" ]]; then
    exit 0
fi

# Convert JSON array to newline-separated list
PATHS_LIST=$(printf '%s' "$PATHS_JSON" | jq -r '.[]? // empty')
if [[ -z "$PATHS_LIST" ]]; then
    exit 0
fi

# Detect project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [[ -z "$PROJECT_DIR" ]]; then
    PROJECT_DIR=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
fi
if [[ -z "$PROJECT_DIR" ]]; then
    exit 0
fi

# Auto-detect baseline file
BASELINE_FILE=""
for candidate in "phpstan-baseline.neon" "phpstan-baseline.php"; do
    if [[ -f "${PROJECT_DIR}/${candidate}" ]]; then
        BASELINE_FILE="${PROJECT_DIR}/${candidate}"
        break
    fi
done

if [[ -z "$BASELINE_FILE" ]]; then
    exit 0
fi

# Grep baseline for each analyzed path
MATCHED_FILES=()
while IFS= read -r filepath; do
    [[ -z "$filepath" ]] && continue
    # Strip leading ./ if present
    filepath="${filepath#./}"
    if grep -qF "$filepath" "$BASELINE_FILE" 2>/dev/null; then
        MATCHED_FILES+=("$filepath")
    fi
done <<< "$PATHS_LIST"

if [[ ${#MATCHED_FILES[@]} -eq 0 ]]; then
    exit 0
fi

# Build warning message
BASENAME=$(basename "$BASELINE_FILE")
WARNING="PHPStan baseline check: The following analyzed files have entries in ${BASENAME}:"
for f in "${MATCHED_FILES[@]}"; do
    WARNING="${WARNING}\n- ${f}"
done
WARNING="${WARNING}\n\nThese baseline entries may be stale. If your changes fixed the underlying errors, remove the corresponding entries from ${BASENAME} to avoid CI failures."

# Output as additionalContext
CONTEXT=$(printf '%b' "$WARNING" | jq -Rs '.')
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": ${CONTEXT}
  }
}
EOF

exit 0
