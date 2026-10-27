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
    command -v jq &>/dev/null || return 0
    read_mcp_config "$1" "${PROJECT_DIR}"
    [[ -z "${MCP_CONFIG_JSON}" ]] && return 0
    [[ $(jq -r '.enforce_mcp_tools != false' <<< "${MCP_CONFIG_JSON}") == "true" ]]
}

# _render_scopes_section <config-prefix>
# Echoes a markdown block describing the declared scopes, or nothing when
# no scopes are present.
_render_scopes_section() {
    local prefix="$1"
    command -v jq &>/dev/null || return 0
    read_mcp_config "${prefix}" "${PROJECT_DIR}"
    [[ -z "${MCP_CONFIG_JSON}" ]] && return 0

    local has_scopes
    has_scopes=$(jq -r '.scopes // {} | keys | length' <<< "${MCP_CONFIG_JSON}" 2>/dev/null || echo "0")
    [[ "${has_scopes}" -eq 0 ]] && return 0

    local default_scope names
    default_scope=$(jq -r '.default_scope // "shopware"' <<< "${MCP_CONFIG_JSON}")
    names=$(jq -r '.scopes | keys | join(", ")' <<< "${MCP_CONFIG_JSON}")

    local ignore_note=""
    if [[ "${prefix}" == "js-tooling" ]]; then
        ignore_note=$'\n\n'"\`lint_all\`, \`lint_twig\`, \`unit_setup\`, \`vite_build\`, \`webpack_build\` and \`vitest_run\` ignore the default scope and run against the core package; \`ludtwig_check\` and \`ludtwig_fix\` take no scope at all and always run there."
    fi

    cat <<EOF

## ${prefix} scopes

Default scope: ${default_scope}
Declared scopes: shopware (implicit), ${names}

Scope determines cwd, configs, and bootstrap prereqs for ${prefix} MCP tools.
Tools accept an optional \`scope\` argument that overrides the default for
one call. Pass \`scope: "shopware"\` to target project-root code while a plugin
scope is the default.${ignore_note}
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

php_enforced=0
js_enforced=0
is_enforced "php-tooling" && php_enforced=1
is_enforced "js-tooling" && js_enforced=1
enforced=$(( php_enforced || js_enforced ))
[[ "${enforced}" -eq 0 && -z "${bind_hint}" ]] && exit 0

# _render_directives <prompt-file>
# Drops every line naming an opted-out language's server, so the prompt never directs to tools not enforced.
_render_directives() {
    local languages="PHP and JavaScript"
    [[ "${js_enforced}" -eq 0 ]] && languages="PHP"
    [[ "${php_enforced}" -eq 0 ]] && languages="JavaScript"
    awk -v php="${php_enforced}" -v js="${js_enforced}" -v languages="${languages}" '
        NR == 1 { sub(/PHP and JavaScript/, languages) }
        /`php-tooling`/ && php == 0 { next }
        /`js-(admin|storefront)-tooling`/ && js == 0 { next }
        /^$/ { blank = 1; next }
        {
            if (blank && printed) print ""
            blank = 0; printed = 1
            print
        }
    ' "$1"
}

context=""
if [[ "${enforced}" -eq 1 ]]; then
    if [[ -f "$PROMPT_FILE" ]]; then
        context=$(_render_directives "$PROMPT_FILE")
    fi

    # Append scopes sections (one per enforced config prefix that declares scopes).
    scopes_block=""
    [[ "${php_enforced}" -eq 1 ]] && scopes_block+=$(_render_scopes_section "php-tooling")
    [[ "${js_enforced}" -eq 1 ]] && scopes_block+=$(_render_scopes_section "js-tooling")

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
