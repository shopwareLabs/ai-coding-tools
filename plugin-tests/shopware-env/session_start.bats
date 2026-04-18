#!/usr/bin/env bats
# bats file_tags=shopware-env,session-start
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

@test "session-start: outputs hookEventName=SessionStart with lifecycle tool directives" {
    run bash "${PLUGIN_DIR}/hooks/scripts/session-start.sh" < /dev/null
    assert_success

    local event_name context
    event_name=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.hookEventName')
    context=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')

    assert_equal "$event_name" "SessionStart"
    assert [ -n "$context" ]
    assert_regex "$context" "install_dependencies"
    assert_regex "$context" "database_install"
    assert_regex "$context" "plugin_create"
}
