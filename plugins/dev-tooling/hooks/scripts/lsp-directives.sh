#!/usr/bin/env bash
# SessionStart hook: inject LSP usage directives into conversation context.
# Assembles the prompt from per-server sections based on which LSP configs
# are present and enabled in the project (.lsp-php-tooling.json).
# Exits silently if no LSP server is enabled.
set -euo pipefail

cat > /dev/null  # drain stdin

HOOK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT_DIR="${HOOK_DIR}/prompts"

[[ -z "${CLAUDE_PROJECT_DIR:-}" ]] && exit 0
command -v jq &>/dev/null || exit 0

# Return 0 if .lsp-<prefix>.json exists in the project and has enabled=true.
is_lsp_enabled() {
    local prefix="$1"
    local config_file=""
    for loc in ".claude/.lsp-${prefix}.json" ".lsp-${prefix}.json"; do
        if [[ -f "${CLAUDE_PROJECT_DIR}/${loc}" ]]; then
            config_file="${CLAUDE_PROJECT_DIR}/${loc}"
            break
        fi
    done
    [[ -z "$config_file" ]] && return 1

    local enabled
    enabled=$(jq -r '.enabled // false' "$config_file" 2>/dev/null || echo "false")
    [[ "$enabled" == "true" ]]
}

sections=()
is_lsp_enabled "php-tooling" && sections+=("${PROMPT_DIR}/lsp-directives-php.md")

[[ ${#sections[@]} -eq 0 ]] && exit 0

# Assemble: header + one section per enabled server.
content=""
header="${PROMPT_DIR}/lsp-directives-header.md"
if [[ -f "$header" ]]; then
    content+="$(cat "$header")"$'\n\n'
fi
for f in "${sections[@]}"; do
    [[ -f "$f" ]] || continue
    content+="$(cat "$f")"$'\n\n'
done

[[ -z "$content" ]] && exit 0

additional_context=$(printf '%s' "$content" | jq -Rs '.')
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ${additional_context}
  }
}
EOF

exit 0
