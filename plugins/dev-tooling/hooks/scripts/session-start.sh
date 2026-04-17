#!/usr/bin/env bash
# SessionStart hook: inject MCP dev tool usage directives + scopes metadata.
set -euo pipefail

cat > /dev/null  # drain stdin

HOOK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT_FILE="${HOOK_DIR}/prompts/mcp-tool-directives.md"

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

# _render_scopes_section <config-prefix>
# Echoes a markdown block describing the declared scopes, or nothing when
# no scopes are present.
_render_scopes_section() {
    local prefix="$1"
    [[ -z "${CLAUDE_PROJECT_DIR:-}" ]] && return 0
    command -v jq &>/dev/null || return 0

    local config_file=""
    for location in ".claude/.mcp-${prefix}.json" ".mcp-${prefix}.json"; do
        if [[ -f "${CLAUDE_PROJECT_DIR}/${location}" ]]; then
            config_file="${CLAUDE_PROJECT_DIR}/${location}"
            break
        fi
    done
    [[ -z "${config_file}" ]] && return 0

    local has_scopes
    has_scopes=$(jq -r '.scopes // {} | keys | length' "${config_file}" 2>/dev/null || echo "0")
    [[ "${has_scopes}" -eq 0 ]] && return 0

    local default_scope names
    default_scope=$(jq -r '.default_scope // "shopware"' "${config_file}")
    names=$(jq -r '.scopes | keys | join(", ")' "${config_file}")

    cat <<EOF

## ${prefix} scopes

Default scope: ${default_scope}
Declared scopes: shopware (implicit), ${names}

Scope determines cwd, configs, and bootstrap prereqs for ${prefix} MCP tools.
Tools accept an optional \`scope\` argument that overrides the default for
one call. Pass \`scope: "shopware"\` to target project-root code while a plugin
scope is the default.
EOF
}

is_enforced "php-tooling" || is_enforced "js-tooling" || exit 0

context=""
if [[ -f "$PROMPT_FILE" ]]; then
    context=$(cat "$PROMPT_FILE")
fi

# Append scopes sections (one per config prefix that declares scopes).
scopes_block=""
for prefix in php-tooling js-tooling; do
    section=$(_render_scopes_section "${prefix}")
    [[ -n "${section}" ]] && scopes_block+="${section}"
done

[[ -n "${scopes_block}" ]] && context+="${scopes_block}"

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
