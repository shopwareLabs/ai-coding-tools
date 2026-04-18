#!/usr/bin/env bats
# bats file_tags=shopware-env,config
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

@test "resolve_lifecycle_env: preserves config LINT_ENV when config is present" {
    setup_lifecycle_mcp_env "${PLUGIN_DIR}/mcp-server-lifecycle/lib/dependencies.sh"
    LIFECYCLE_HAS_CONFIG="true"
    LINT_ENV="docker-compose"
    resolve_lifecycle_env '{}'
    assert_equal "$LINT_ENV" "docker-compose"
}

@test "resolve_lifecycle_env: sets LINT_ENV from arg when no config" {
    setup_lifecycle_mcp_env "${PLUGIN_DIR}/mcp-server-lifecycle/lib/dependencies.sh"
    LIFECYCLE_HAS_CONFIG="false"
    LINT_ENV=""
    resolve_lifecycle_env '{"environment": "native"}'
    assert_equal "$LINT_ENV" "native"
}

@test "resolve_lifecycle_env: exports DOCKER_CONTAINER when docker env with service arg" {
    setup_lifecycle_mcp_env "${PLUGIN_DIR}/mcp-server-lifecycle/lib/dependencies.sh"
    LIFECYCLE_HAS_CONFIG="false"
    resolve_lifecycle_env '{"environment": "docker", "docker_service": "shopware-app"}'
    assert_equal "$DOCKER_CONTAINER" "shopware-app"
}

@test "resolve_lifecycle_env: fails when no config and no arg" {
    setup_lifecycle_mcp_env "${PLUGIN_DIR}/mcp-server-lifecycle/lib/dependencies.sh"
    LIFECYCLE_HAS_CONFIG="false"
    run resolve_lifecycle_env '{}'
    assert_failure
    assert_output --partial "no .mcp-php-tooling.json config found"
}
