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
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | length > 0'
}

@test "additionalContext is a non-empty string" {
    run_session_start
    assert_success
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
