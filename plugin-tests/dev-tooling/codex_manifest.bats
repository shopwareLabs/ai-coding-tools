#!/usr/bin/env bats
# bats file_tags=dev-tooling,codex
bats_require_minimum_version 1.11.0

# The Codex packaging of dev-tooling: .codex-plugin/plugin.json, codex.mcp.json
# and the repo marketplace at .agents/plugins/marketplace.json. Codex resolves a
# plugin MCP server's relative cwd against the plugin root and passes the command
# to the OS unchanged, so a "./..." command resolves only together with cwd ".".

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"
CODEX_MANIFEST="${PLUGIN_DIR}/.codex-plugin/plugin.json"
CLAUDE_MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
CODEX_MCP="${PLUGIN_DIR}/codex.mcp.json"
CLAUDE_MCP="${PLUGIN_DIR}/.mcp.json"
CODEX_MARKETPLACE="${REPO_ROOT}/.agents/plugins/marketplace.json"
CLAUDE_MARKETPLACE="${REPO_ROOT}/.claude-plugin/marketplace.json"
DIRECTIVES="${PLUGIN_DIR}/hooks/prompts/mcp-tool-directives.md"

# Args: $1 = path of the file
_assert_json_object() {
    run jq -e 'type == "object"' "$1"
    assert_success
    assert_output "true"
}

# Args: $1 = server key in codex.mcp.json
_assert_server_launch() {
    local command cwd
    command=$(jq -r --arg k "$1" '.mcpServers[$k].command' "${CODEX_MCP}")
    cwd=$(jq -r --arg k "$1" '.mcpServers[$k].cwd' "${CODEX_MCP}")
    assert_equal "${cwd}" "."
    assert_equal "${command#./}" "mcp-server-${1%-tooling}/server.sh"
    assert [ -x "${PLUGIN_DIR}/${command#./}" ]
}

# The override variable is derived from the server's own CONFIG_PREFIX by the
# rule config.sh applies, so a re-prefixed server cannot keep a stale name here
# that Codex would silently skip.
# Args: $1 = server key in codex.mcp.json
_assert_server_forwards_config_vars() {
    local command prefix config_var
    command=$(jq -r --arg k "$1" '.mcpServers[$k].command' "${CODEX_MCP}")
    prefix=$(sed -n 's/^CONFIG_PREFIX="\([^"]*\)"$/\1/p' "${PLUGIN_DIR}/${command#./}")
    assert [ -n "${prefix}" ]
    config_var="MCP_$(printf '%s' "${prefix}" | tr '[:lower:]-' '[:upper:]_')_CONFIG"
    run jq -c --arg k "$1" --arg v "${config_var}" \
        '[.mcpServers[$k].env_vars[] | select(. == "PROJECT_ROOT" or . == $v)] | sort' "${CODEX_MCP}"
    assert_output "$(jq -cn --arg v "${config_var}" '[$v, "PROJECT_ROOT"] | sort')"
}

# bats test_tags=static
@test "the codex manifest parses as a JSON object" { _assert_json_object "${CODEX_MANIFEST}"; }
# bats test_tags=static
@test "codex.mcp.json parses as a JSON object" { _assert_json_object "${CODEX_MCP}"; }
# bats test_tags=static
@test "the codex marketplace parses as a JSON object" { _assert_json_object "${CODEX_MARKETPLACE}"; }

# bats test_tags=static
@test "the codex manifest version equals the claude manifest version" {
    run jq -r '.version' "${CODEX_MANIFEST}"
    assert_output "$(jq -r '.version' "${CLAUDE_MANIFEST}")"
}

# bats test_tags=static
@test "the codex manifest copies the claude manifest's descriptive metadata" {
    local fields='{name, description, author, license, keywords, homepage, repository}'
    run jq -cS "${fields}" "${CODEX_MANIFEST}"
    assert_output "$(jq -cS "${fields}" "${CLAUDE_MANIFEST}")"
}

# Without a hooks field Codex loads hooks/hooks.json itself; a hooks field
# would replace that file rather than add to it.
# bats test_tags=static
@test "the codex manifest declares no hooks field" {
    run jq -r 'has("hooks")' "${CODEX_MANIFEST}"
    assert_output "false"
}

# bats test_tags=static
@test "the codex manifest points mcpServers at an existing ./ file under the plugin root" {
    local path
    path=$(jq -r '.mcpServers' "${CODEX_MANIFEST}")
    assert_equal "${path:0:2}" "./"
    assert [ -f "${PLUGIN_DIR}/${path#./}" ]
}

# bats test_tags=static
@test "codex.mcp.json declares the same server keys as .mcp.json" {
    run jq -c '.mcpServers | keys' "${CODEX_MCP}"
    assert_output "$(jq -c '.mcpServers | keys' "${CLAUDE_MCP}")"
}

# bats test_tags=static
@test "php-tooling launches its executable server script relative to the plugin root" { _assert_server_launch "php-tooling"; }
# bats test_tags=static
@test "js-admin-tooling launches its executable server script relative to the plugin root" { _assert_server_launch "js-admin-tooling"; }
# bats test_tags=static
@test "js-storefront-tooling launches its executable server script relative to the plugin root" { _assert_server_launch "js-storefront-tooling"; }

# bats test_tags=static
@test "php-tooling forwards PROJECT_ROOT and its config override variable" { _assert_server_forwards_config_vars "php-tooling"; }
# bats test_tags=static
@test "js-admin-tooling forwards PROJECT_ROOT and its config override variable" { _assert_server_forwards_config_vars "js-admin-tooling"; }
# bats test_tags=static
@test "js-storefront-tooling forwards PROJECT_ROOT and its config override variable" { _assert_server_forwards_config_vars "js-storefront-tooling"; }

# A variable added to one server's list and not the others leaves that one
# server without it under Codex, which forwards only what is listed.
# bats test_tags=static
@test "every codex server forwards the same variables apart from its config override" {
    run jq -c '[.mcpServers[].env_vars | map(select(test("^MCP_.*_TOOLING_CONFIG$") | not))] | unique | length' "${CODEX_MCP}"
    assert_output "1"
}

# bats test_tags=static
@test "the codex marketplace carries the claude marketplace's name" {
    run jq -r '.name' "${CODEX_MARKETPLACE}"
    assert_output "$(jq -r '.name' "${CLAUDE_MARKETPLACE}")"
}

# bats test_tags=static
@test "the codex marketplace lists dev-tooling only, as an available local plugin" {
    run jq -c '[.plugins[] | {name, source, installation: .policy.installation}]' "${CODEX_MARKETPLACE}"
    assert_output '[{"name":"dev-tooling","source":{"source":"local","path":"./plugins/dev-tooling"},"installation":"AVAILABLE"}]'
}

# bats test_tags=static
@test "the codex marketplace entry's path holds a codex manifest" {
    local path
    path=$(jq -r '.plugins[0].source.path' "${CODEX_MARKETPLACE}")
    assert [ -f "${REPO_ROOT}/${path#./}/.codex-plugin/plugin.json" ]
}

# A bare tool name is ambiguous to a host that exposes the three servers' tools
# side by side, so every mention below the per-server listings names its server.
# bats test_tags=directives
@test "every tool mention in the directive prose names its server" {
    local tools prose mentions
    tools=$(jq -r '.tools[].name' "${PLUGIN_DIR}"/mcp-server-*/tools.json | sort -u | paste -sd '|' -)
    prose=$(grep -v '^On the `' "${DIRECTIVES}")
    mentions=$(grep -oE "\`(${tools})\`( on (the \`[a-z-]+\`|each dev-tooling|the dev-tooling) MCP server)?" <<< "${prose}")
    assert [ -n "${mentions}" ]
    run grep -v ' MCP server$' <<< "${mentions}"
    assert_output ""
}

# bats test_tags=directives
@test "every directive mention that names one server names a server providing that tool" {
    local tools prose pairs
    tools=$(jq -r '.tools[].name' "${PLUGIN_DIR}"/mcp-server-*/tools.json | sort -u | paste -sd '|' -)
    prose=$(grep -v '^On the `' "${DIRECTIVES}")
    # shellcheck disable=SC2016  # the backticks in the sed script are literal Markdown, not command substitution
    pairs=$(grep -oE "\`(${tools})\` on the \`[a-z-]+\` MCP server" <<< "${prose}" \
        | sed -E 's/^`([^`]*)` on the `([^`]*)` MCP server$/\2 \1/' | sort -u)
    assert [ -n "${pairs}" ]
    run bash -c 'while read -r server tool; do
        jq -e --arg t "${tool}" "any(.tools[]; .name == \$t)" "$1/mcp-server-${server%-tooling}/tools.json" >/dev/null 2>&1 \
            || printf "%s on %s\n" "${tool}" "${server}"
    done <<< "$2"' _ "${PLUGIN_DIR}" "${pairs}"
    assert_output ""
}
