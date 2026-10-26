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

# Argument-path setup for docker-compose: restores the real exec_command that
# setup_lifecycle_mcp_env stubs out, and puts a docker stub on PATH that logs
# every argv to DOCKER_LOG and answers the compose queries issued before the exec.
setup_docker_compose_args_env() {
    setup_lifecycle_mcp_env "${PLUGIN_DIR}/mcp-server-lifecycle/lib/dependencies.sh"
    source "${PLUGIN_DIR}/shared/environment.sh"
    LIFECYCLE_HAS_CONFIG="false"
    LINT_ENV=""
    PROJECT_ROOT="$(cd "${BATS_TEST_TMPDIR}" && pwd -P)"
    LINT_WORKDIR="${PROJECT_ROOT}"
    DOCKER_LOG="${BATS_TEST_TMPDIR}/docker.log"
    : > "${DOCKER_LOG}"
    mkdir -p "${BATS_TEST_TMPDIR}/bin"
    cat > "${BATS_TEST_TMPDIR}/bin/docker" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${DOCKER_LOG}"
case "\$*" in
    *"compose version"*) echo "Docker Compose version v2.20.0" ;;
    *"ps --format json"*) echo '{"Service":"web","Name":"proj-web-1"}' ;;
    *"config --format json"*) echo '{"services":{"web":{"volumes":[{"type":"bind","source":"${PROJECT_ROOT}","target":"/var/www/html"}]}}}' ;;
esac
STUB
    chmod +x "${BATS_TEST_TMPDIR}/bin/docker"
    PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

@test "resolve_lifecycle_env: docker-compose args with compose_file reach docker with -f" {
    setup_docker_compose_args_env
    run tool_install_dependencies '{"environment": "docker-compose", "docker_service": "web", "compose_file": "docker-compose.test.yml", "composer": true}'
    assert_success
    run cat "${DOCKER_LOG}"
    assert_output --partial "compose -f ${PROJECT_ROOT}/docker-compose.test.yml"
    assert_output --partial "exec -i proj-web-1"
    assert_output --partial "composer install"
}

@test "resolve_lifecycle_env: docker-compose args without compose_file reach docker without -f" {
    setup_docker_compose_args_env
    run tool_install_dependencies '{"environment": "docker-compose", "docker_service": "web", "composer": true}'
    assert_success
    run cat "${DOCKER_LOG}"
    assert_output --partial "composer install"
    refute_output --partial "compose -f"
}

@test "resolve_lifecycle_env: refuses docker-compose args without docker_service before calling docker" {
    setup_docker_compose_args_env
    run tool_install_dependencies '{"environment": "docker-compose", "composer": true}'
    assert_failure
    assert_output --partial "docker_service"
    assert_output --partial "docker-compose"
    assert_equal "$(< "${DOCKER_LOG}")" ""
}
