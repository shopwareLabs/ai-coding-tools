#!/usr/bin/env bats
# bats file_tags=shopware-env,session-start
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

@test "session-start: outputs valid JSON with additionalContext" {
    run bash "${PLUGIN_DIR}/hooks/scripts/session-start.sh" < /dev/null
    assert_success
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null
}

@test "session-start: context includes lifecycle-tooling tools" {
    run bash "${PLUGIN_DIR}/hooks/scripts/session-start.sh" < /dev/null
    assert_success
    assert_output --partial "install_dependencies"
    assert_output --partial "database_install"
    assert_output --partial "plugin_create"
}
