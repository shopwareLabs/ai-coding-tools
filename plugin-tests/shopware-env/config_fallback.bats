#!/usr/bin/env bats
# bats file_tags=shopware-env,config
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

@test "resolve_lifecycle_env: uses config environment when present" {
    setup_lifecycle_mcp_env "${PLUGIN_DIR}/mcp-server-lifecycle/lib/dependencies.sh"
    LIFECYCLE_HAS_CONFIG="true"
    LINT_ENV="docker-compose"
    run resolve_lifecycle_env '{}'
    assert_success
}

@test "resolve_lifecycle_env: uses arg environment when no config" {
    setup_lifecycle_mcp_env "${PLUGIN_DIR}/mcp-server-lifecycle/lib/dependencies.sh"
    LIFECYCLE_HAS_CONFIG="false"
    run resolve_lifecycle_env '{"environment": "native"}'
    assert_success
}

@test "resolve_lifecycle_env: fails when no config and no arg" {
    setup_lifecycle_mcp_env "${PLUGIN_DIR}/mcp-server-lifecycle/lib/dependencies.sh"
    LIFECYCLE_HAS_CONFIG="false"
    run resolve_lifecycle_env '{}'
    assert_failure
    assert_output --partial "no .mcp-php-tooling.json config found"
}
