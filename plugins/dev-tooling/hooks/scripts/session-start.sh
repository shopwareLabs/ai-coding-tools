#!/usr/bin/env bash
# SessionStart hook: inject MCP dev tool usage directives + scopes metadata.
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Claude Code sets CLAUDE_PROJECT_DIR for plugin hooks and Codex does not; Codex
# has no plugin subagents or worktree-switching tools, so it gets its own prompt.
if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    PROMPT_FILE="${HOOK_DIR}/prompts/mcp-tool-directives.md"
else
    PROMPT_FILE="${HOOK_DIR}/prompts/mcp-tool-directives-codex.md"
fi

# shellcheck source=lib/common.sh
source "${HOOK_DIR}/scripts/lib/common.sh"

# The host writes hook-event JSON to stdin for every hook, including
# SessionStart; reading it fully also avoids blocking the host's write on a
# payload larger than the pipe buffer. Its .cwd is the project-dir fallback.
# Input that is not JSON names no directory; the directives still go out, so a
# resolve failure leaves PROJECT_DIR empty instead of aborting under set -e.
HOOK_INPUT=$(cat)
PROJECT_DIR=$(resolve_project_dir "$HOOK_INPUT") || PROJECT_DIR=""

is_enforced() {
    local config_prefix="$1"
    [[ -z "${PROJECT_DIR}" ]] && return 0
    local config_file=""
    for location in ".claude/.mcp-${config_prefix}.json" ".mcp-${config_prefix}.json"; do
        if [[ -f "${PROJECT_DIR}/${location}" ]]; then
            config_file="${PROJECT_DIR}/${location}"
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
    [[ -z "${PROJECT_DIR}" ]] && return 0
    command -v jq &>/dev/null || return 0

    local config_file=""
    for location in ".claude/.mcp-${prefix}.json" ".mcp-${prefix}.json"; do
        if [[ -f "${PROJECT_DIR}/${location}" ]]; then
            config_file="${PROJECT_DIR}/${location}"
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

# No CLAUDE_PROJECT_DIR means a host that names the session directory only in
# .cwd, as Codex does; it also starts the servers in the plugin's own directory,
# unbound, so the session is told which root binds them. Not gated on
# enforce_mcp_tools: an unbound server refuses every tool whatever that says.
bind_hint=""
if [[ -z "${CLAUDE_PROJECT_DIR:-}" && -n "${PROJECT_DIR}" ]]; then
    bind_hint=$(printf '%s\n\n%s' "## Project root for the dev-tooling MCP servers" \
        "If a tool of the \`php-tooling\`, \`js-admin-tooling\` or \`js-storefront-tooling\` MCP server reports that no project root is set, call \`set_project_root\` on that server with \`${PROJECT_DIR}\` and retry.")
fi

enforced=1
is_enforced "php-tooling" || is_enforced "js-tooling" || enforced=0
[[ "${enforced}" -eq 0 && -z "${bind_hint}" ]] && exit 0

context=""
if [[ "${enforced}" -eq 1 ]]; then
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
fi

if [[ -n "${bind_hint}" ]]; then
    context+="${context:+$'\n\n'}${bind_hint}"
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
