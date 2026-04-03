#!/usr/bin/env bats
# bats file_tags=dev-tooling,docker-compose
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

setup() {
    log() { :; }
    COMPOSE_SERVICE="web"
    COMPOSE_WORKDIR_OVERRIDE=""
    COMPOSE_FILE_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/shared/docker-compose.sh"
}

teardown() {
    unset COMPOSE_SERVICE COMPOSE_WORKDIR_OVERRIDE COMPOSE_FILE_OVERRIDE PROJECT_ROOT
}

# --- _compose_cmd ---

@test "_compose_cmd: returns 'docker compose' without file override" {
    COMPOSE_FILE_OVERRIDE=""
    run _compose_cmd
    assert_success
    assert_output "docker compose"
}

@test "_compose_cmd: includes -f flag with file override" {
    COMPOSE_FILE_OVERRIDE="docker/compose.yaml"
    run _compose_cmd
    assert_success
    assert_output "docker compose -f ${BATS_TEST_TMPDIR}/docker/compose.yaml"
}

# --- _compose_check_prerequisites ---

@test "_compose_check_prerequisites: fails when docker not installed" {
    # Use a subshell with modified PATH to hide docker
    run bash -c "
        export PATH='/nonexistent'
        source '${PLUGIN_DIR}/shared/docker-compose.sh' 2>/dev/null
        log() { :; }
        COMPOSE_FILE_OVERRIDE=''
        _compose_check_prerequisites
    "
    assert_failure
    assert_output --partial "docker CLI not found"
}

@test "_compose_check_prerequisites: fails when compose plugin missing" {
    # Mock docker to exist but 'docker compose version' to fail
    run bash -c "
        docker() {
            if [[ \"\$1\" == 'compose' ]]; then
                echo \"docker: 'compose' is not a docker command\" >&2
                return 1
            fi
        }
        export -f docker
        log() { :; }
        source '${PLUGIN_DIR}/shared/docker-compose.sh' 2>/dev/null
        COMPOSE_FILE_OVERRIDE=''
        _compose_check_prerequisites
    "
    assert_failure
    assert_output --partial "docker compose not available"
}

# --- _compose_resolve_container ---

@test "_compose_resolve_container: finds running container for service" {
    # Mock docker compose ps output (one JSON object per line)
    docker() {
        if [[ "$1" == "compose" && "$2" == "ps" ]]; then
            echo '{"Service":"database","Name":"shopware-database-1","State":"running"}'
            echo '{"Service":"web","Name":"shopware-web-1","State":"running"}'
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    run _compose_resolve_container
    assert_success
    assert_output "shopware-web-1"
}

@test "_compose_resolve_container: fails when service not running" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "ps" ]]; then
            echo '{"Service":"database","Name":"shopware-database-1","State":"running"}'
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    run _compose_resolve_container
    assert_failure
    assert_output --partial "Service 'web' is not running"
    assert_output --partial "docker compose up -d web"
}

@test "_compose_resolve_container: fails when no services running and lists available" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "ps" ]]; then
            # No output = no running services
            return 0
        fi
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            echo '{"services":{"web":{},"database":{}}}'
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    run _compose_resolve_container
    assert_failure
    assert_output --partial "Service 'web' is not running"
}

@test "_compose_resolve_container: fails when service not defined in compose" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "ps" ]]; then
            return 0
        fi
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            echo '{"services":{"database":{},"adminer":{}}}'
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    run _compose_resolve_container
    assert_failure
    assert_output --partial "Service 'web' not found in compose config"
    assert_output --partial "Available services:"
}

# --- _compose_resolve_workdir ---

@test "_compose_resolve_workdir: returns config override when set" {
    COMPOSE_WORKDIR_OVERRIDE="/custom/path"
    run _compose_resolve_workdir
    assert_success
    assert_output "/custom/path"
}

@test "_compose_resolve_workdir: detects bind mount target matching project root" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            cat <<JSONEOF
{"services":{"web":{"volumes":[{"type":"bind","source":"${BATS_TEST_TMPDIR}","target":"/var/www/html"}]}}}
JSONEOF
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_WORKDIR_OVERRIDE=""
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    run _compose_resolve_workdir
    assert_success
    assert_output "/var/www/html"
}

@test "_compose_resolve_workdir: fails when no bind mount matches project root" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            echo '{"services":{"web":{"volumes":[{"type":"volume","source":"db-data","target":"/var/lib/mysql"}]}}}'
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_WORKDIR_OVERRIDE=""
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    run _compose_resolve_workdir
    assert_failure
    assert_output --partial "No bind mount for"
    assert_output --partial "docker-compose.workdir"
}

@test "_compose_resolve_workdir: fails when service has no volumes" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            echo '{"services":{"web":{}}}'
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_WORKDIR_OVERRIDE=""
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    run _compose_resolve_workdir
    assert_failure
    assert_output --partial "No bind mount for"
}

# --- _compose_wrap_command ---

@test "_compose_wrap_command: produces correct docker exec string" {
    # Mock both resolution functions
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() { echo "shopware-web-1"; }
    _compose_resolve_workdir() { echo "/var/www/html"; }
    run _compose_wrap_command "vendor/bin/phpstan analyse"
    assert_success
    assert_output "docker exec -i shopware-web-1 bash -c 'cd /var/www/html && vendor/bin/phpstan analyse'"
}

@test "_compose_wrap_command: propagates prerequisite check failure" {
    _compose_check_prerequisites() {
        echo "docker CLI not found. Install Docker: https://docs.docker.com/get-docker/"
        return 1
    }
    run _compose_wrap_command "vendor/bin/phpstan analyse"
    assert_failure
    assert_output --partial "docker CLI not found"
}

@test "_compose_wrap_command: propagates container resolution failure" {
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() {
        echo "Service 'web' is not running. Start it with: docker compose up -d web"
        return 1
    }
    run _compose_wrap_command "vendor/bin/phpstan analyse"
    assert_failure
    assert_output --partial "Service 'web' is not running"
}

@test "_compose_wrap_command: propagates workdir resolution failure" {
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() { echo "shopware-web-1"; }
    _compose_resolve_workdir() {
        echo "No bind mount for /project found on service 'web'. Set docker-compose.workdir in config."
        return 1
    }
    run _compose_wrap_command "vendor/bin/phpstan analyse"
    assert_failure
    assert_output --partial "No bind mount for"
}

# --- _compose_wrap_npm_command ---

@test "_compose_wrap_npm_command: appends admin JS context path" {
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() { echo "shopware-web-1"; }
    _compose_resolve_workdir() { echo "/var/www/html"; }
    JS_CONTEXT="admin"
    run _compose_wrap_npm_command "npm run lint"
    assert_success
    assert_output "docker exec -i shopware-web-1 bash -c 'cd /var/www/html/src/Administration/Resources/app/administration && npm run lint'"
}

@test "_compose_wrap_npm_command: appends storefront JS context path" {
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() { echo "shopware-web-1"; }
    _compose_resolve_workdir() { echo "/var/www/html"; }
    JS_CONTEXT="storefront"
    run _compose_wrap_npm_command "npm run lint:js"
    assert_success
    assert_output "docker exec -i shopware-web-1 bash -c 'cd /var/www/html/src/Storefront/Resources/app/storefront && npm run lint:js'"
}

@test "_compose_wrap_npm_command: propagates prerequisite failure" {
    _compose_check_prerequisites() {
        echo "Docker daemon is not running. Start Docker Desktop or the Docker service."
        return 1
    }
    JS_CONTEXT="admin"
    run _compose_wrap_npm_command "npm run lint"
    assert_failure
    assert_output --partial "Docker daemon is not running"
}
