#!/usr/bin/env bats
# bats file_tags=dev-tooling,session-start
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

SESSION_SCRIPT="${REPO_ROOT}/plugins/dev-tooling/hooks/scripts/session-start.sh"

run_session_start() {
    run bash -c 'echo "{}" | bash "$1"' _ "$SESSION_SCRIPT"
}

# ============================================================================
# JSON output structure
# ============================================================================

# bats test_tags=output
@test "outputs valid JSON with additionalContext" {
    run_session_start
    assert_success
    # Valid JSON
    echo "$output" | jq -e . >/dev/null
    # Correct structure
    echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"'
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | type == "string"'
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | length > 0'
}

# ============================================================================
# enforce_mcp_tools: false — disables SessionStart output
# ============================================================================

# bats test_tags=config
@test "silent when both php and js enforcement disabled" {
    setup_config "php-tooling" '{"environment": "native", "enforce_mcp_tools": false}'
    setup_config "js-tooling" '{"environment": "native", "enforce_mcp_tools": false}'
    run_session_start
    assert_success
    assert_output ""
}

@test "outputs when only php enforcement disabled" {
    setup_config "php-tooling" '{"environment": "native", "enforce_mcp_tools": false}'
    setup_config "js-tooling" '{"environment": "native", "enforce_mcp_tools": true}'
    run_session_start
    assert_success
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | length > 0'
}

@test "outputs when only js enforcement disabled" {
    setup_config "php-tooling" '{"environment": "native", "enforce_mcp_tools": true}'
    setup_config "js-tooling" '{"environment": "native", "enforce_mcp_tools": false}'
    run_session_start
    assert_success
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | length > 0'
}

@test "outputs when no config files exist" {
    export CLAUDE_PROJECT_DIR="${BATS_TEST_TMPDIR}/empty"
    mkdir -p "$CLAUDE_PROJECT_DIR"
    run_session_start
    assert_success
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | length > 0'
}

# ============================================================================
# Project directory: CLAUDE_PROJECT_DIR, else the hook input's cwd
# ============================================================================

# Run the hook with the given JSON on stdin.
run_session_start_with_input() {
    run bash -c 'printf "%s" "$1" | bash "$2"' _ "$1" "$SESSION_SCRIPT"
}

# bats test_tags=output
@test "directives name no mcp__ tool form" {
    run_session_start
    assert_success
    refute_output --partial "mcp__"
}

# The bind hint is not gated on enforcement, so with .cwd present the output is
# not empty; what enforcement read from .cwd controls is the directives.
# bats test_tags=cwd
@test "reads enforcement from the hook input cwd when CLAUDE_PROJECT_DIR is unset" {
    unset CLAUDE_PROJECT_DIR
    local project="${BATS_TEST_TMPDIR}/cwd-project"
    mkdir -p "$project"
    echo '{"enforce_mcp_tools": false}' > "${project}/.mcp-php-tooling.json"
    echo '{"enforce_mcp_tools": false}' > "${project}/.mcp-js-tooling.json"
    run_session_start_with_input "$(jq -cn --arg cwd "$project" '{cwd: $cwd}')"
    assert_success
    run jq -r '.hookSpecificOutput.additionalContext' <<< "$output"
    assert_success
    refute_output --partial "ALWAYS use MCP dev tools"
}

# Codex names the session directory only in .cwd and starts the servers unbound
# in the plugin directory; the hint names the root that binds them.
# bats test_tags=cwd
@test "names the hook input cwd as the root to bind when CLAUDE_PROJECT_DIR is unset" {
    unset CLAUDE_PROJECT_DIR
    local project="${BATS_TEST_TMPDIR}/cwd-project"
    mkdir -p "$project"
    run_session_start_with_input "$(jq -cn --arg cwd "$project" '{cwd: $cwd}')"
    assert_success
    run jq -r '.hookSpecificOutput.additionalContext' <<< "$output"
    assert_success
    assert_output --partial "reports that no project root is set, call \`set_project_root\` on that server with \`${project}\` and retry."
}

# bats test_tags=cwd
@test "adds the bind hint even when enforcement read from the hook input cwd is off" {
    unset CLAUDE_PROJECT_DIR
    local project="${BATS_TEST_TMPDIR}/cwd-project"
    mkdir -p "$project"
    echo '{"enforce_mcp_tools": false}' > "${project}/.mcp-php-tooling.json"
    echo '{"enforce_mcp_tools": false}' > "${project}/.mcp-js-tooling.json"
    run_session_start_with_input "$(jq -cn --arg cwd "$project" '{cwd: $cwd}')"
    assert_success
    run jq -r '.hookSpecificOutput.additionalContext' <<< "$output"
    assert_success
    assert_output --partial "call \`set_project_root\` on that server with \`${project}\`"
}

# A host that sets CLAUDE_PROJECT_DIR starts the servers bound, so the hint
# would only send the session to a tool it has no reason to call.
# bats test_tags=cwd
@test "omits the bind hint when CLAUDE_PROJECT_DIR is set" {
    local project="${BATS_TEST_TMPDIR}/cwd-project"
    mkdir -p "$project"
    run_session_start_with_input "$(jq -cn --arg cwd "$project" '{cwd: $cwd}')"
    assert_success
    refute_output --partial "no project root is set"
}

# bats test_tags=cwd
@test "renders scopes from the hook input cwd when CLAUDE_PROJECT_DIR is unset" {
    unset CLAUDE_PROJECT_DIR
    local project="${BATS_TEST_TMPDIR}/cwd-project"
    mkdir -p "$project"
    echo '{"scopes": {"plugin-z": {"cwd": "custom/plugins/Z"}}}' > "${project}/.mcp-php-tooling.json"
    run_session_start_with_input "$(jq -cn --arg cwd "$project" '{cwd: $cwd}')"
    assert_success
    assert_output --partial "php-tooling scopes"
    assert_output --partial "plugin-z"
}

# bats test_tags=cwd
@test "CLAUDE_PROJECT_DIR wins over the hook input cwd when both are set" {
    local project="${BATS_TEST_TMPDIR}/cwd-project"
    mkdir -p "$project"
    echo '{"scopes": {"plugin-x": {"cwd": "custom/plugins/X"}}}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    echo '{"scopes": {"plugin-z": {"cwd": "custom/plugins/Z"}}}' > "${project}/.mcp-php-tooling.json"
    run_session_start_with_input "$(jq -cn --arg cwd "$project" '{cwd: $cwd}')"
    assert_success
    assert_output --partial "plugin-x"
    refute_output --partial "plugin-z"
}

# ============================================================================
# Directive prompt by host
# ============================================================================

# Codex has no plugin subagents and no worktree-switching tools, so the Claude
# prompt would send the model to a runner and a tool that do not exist there.
# bats test_tags=cwd
@test "emits the Codex directives, free of Claude-only guidance, when CLAUDE_PROJECT_DIR is unset" {
    unset CLAUDE_PROJECT_DIR
    local project="${BATS_TEST_TMPDIR}/cwd-project"
    mkdir -p "$project"
    run_session_start_with_input "$(jq -cn --arg cwd "$project" '{cwd: $cwd}')"
    assert_success
    run jq -r '.hookSpecificOutput.additionalContext' <<< "$output"
    assert_success
    assert_output --partial "The final section of this context names the project directory"
    refute_output --partial "dev-tooling-runner"
    refute_output --partial "EnterWorktree"
    refute_output --partial "ExitWorktree"
    refute_output --partial "subagent"
}

# With no scopes declared and no bind hint, the context is the Claude prompt file
# and nothing else.
# bats test_tags=cwd
@test "emits exactly the Claude directives, without Codex-only text, when CLAUDE_PROJECT_DIR is set" {
    local project="${BATS_TEST_TMPDIR}/cwd-project"
    mkdir -p "$project"
    run_session_start_with_input "$(jq -cn --arg cwd "$project" '{cwd: $cwd}')"
    assert_success
    run jq -r '.hookSpecificOutput.additionalContext' <<< "$output"
    assert_success
    assert_output "$(cat "${REPO_ROOT}/plugins/dev-tooling/hooks/prompts/mcp-tool-directives.md")"
    refute_output --partial "The final section of this context names the project directory"
}

# The Codex prompt opens the context and is followed by the bind hint it points at.
# bats test_tags=cwd
@test "the Codex directives open the context and are followed by the bind hint" {
    unset CLAUDE_PROJECT_DIR
    local project="${BATS_TEST_TMPDIR}/cwd-project"
    mkdir -p "$project"
    run_session_start_with_input "$(jq -cn --arg cwd "$project" '{cwd: $cwd}')"
    assert_success
    local hook_output="$output"
    run jq -r '.hookSpecificOutput.additionalContext | split("\n") | .[0]' <<< "$hook_output"
    assert_success
    assert_output --partial "through the dev-tooling MCP servers, not the shell"
    run jq -r '.hookSpecificOutput.additionalContext | split("\n\n") | last' <<< "$hook_output"
    assert_success
    assert_output --partial "call \`set_project_root\` on that server with \`${project}\` and retry."
}
