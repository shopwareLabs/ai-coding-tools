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

# bats test_tags=cwd
@test "reads enforcement from the hook input cwd when CLAUDE_PROJECT_DIR is unset" {
    unset CLAUDE_PROJECT_DIR
    local project="${BATS_TEST_TMPDIR}/cwd-project"
    mkdir -p "$project"
    echo '{"enforce_mcp_tools": false}' > "${project}/.mcp-php-tooling.json"
    echo '{"enforce_mcp_tools": false}' > "${project}/.mcp-js-tooling.json"
    run_session_start_with_input "$(jq -cn --arg cwd "$project" '{cwd: $cwd}')"
    assert_success
    assert_output ""
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
