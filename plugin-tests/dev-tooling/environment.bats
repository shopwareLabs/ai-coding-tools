#!/usr/bin/env bats
# bats file_tags=dev-tooling,environment
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

setup() {
    log() { :; }
    source "${PLUGIN_DIR}/shared/environment.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR DOCKER_CONTAINER
}

# --- Native environment ---

@test "wrap_command native: passes command through unchanged" {
    LINT_ENV="native"
    LINT_WORKDIR="/project"
    run wrap_command "vendor/bin/phpunit --coverage-text"
    assert_success
    assert_output "vendor/bin/phpunit --coverage-text"
}

@test "wrap_command native: preserves XDEBUG_MODE prefix" {
    LINT_ENV="native"
    LINT_WORKDIR="/project"
    run wrap_command "XDEBUG_MODE=coverage vendor/bin/phpunit --coverage-text"
    assert_success
    assert_output "XDEBUG_MODE=coverage vendor/bin/phpunit --coverage-text"
}

# --- Docker environment ---

@test "wrap_command docker: wraps with docker exec and bash -c" {
    LINT_ENV="docker"
    DOCKER_CONTAINER="shopware_app"
    LINT_WORKDIR="/var/www/html"
    run wrap_command "vendor/bin/phpunit"
    assert_success
    assert_output --partial "docker exec -i shopware_app"
    assert_output --partial "cd /var/www/html"
    assert_output --partial "vendor/bin/phpunit"
}

@test "wrap_command docker: preserves XDEBUG_MODE prefix in bash -c string" {
    LINT_ENV="docker"
    DOCKER_CONTAINER="shopware_app"
    LINT_WORKDIR="/var/www/html"
    run wrap_command "XDEBUG_MODE=coverage vendor/bin/phpunit --coverage-text"
    assert_success
    assert_output --partial "XDEBUG_MODE=coverage vendor/bin/phpunit"
}

# --- Vagrant environment ---

@test "wrap_command vagrant: wraps with vagrant ssh -c" {
    LINT_ENV="vagrant"
    LINT_WORKDIR="/vagrant"
    run wrap_command "vendor/bin/phpunit"
    assert_success
    assert_output --partial "vagrant ssh -c"
    assert_output --partial "cd /vagrant"
    assert_output --partial "vendor/bin/phpunit"
}

# --- DDEV environment ---

@test "wrap_command ddev: non-composer command uses ddev exec" {
    LINT_ENV="ddev"
    run wrap_command "vendor/bin/phpunit"
    assert_success
    assert_output --partial "ddev exec vendor/bin/phpunit"
}

@test "wrap_command ddev: composer command uses ddev without exec" {
    LINT_ENV="ddev"
    run wrap_command "composer phpstan"
    assert_success
    assert_output "ddev composer phpstan"
    refute_output --partial "ddev exec"
}

@test "wrap_command ddev: preserves XDEBUG_MODE prefix in ddev exec" {
    LINT_ENV="ddev"
    run wrap_command "XDEBUG_MODE=coverage vendor/bin/phpunit --coverage-text"
    assert_success
    assert_output --partial "ddev exec XDEBUG_MODE=coverage vendor/bin/phpunit"
}

# --- Docker Compose environment ---

@test "wrap_command docker-compose: delegates to _compose_wrap_command" {
    LINT_ENV="docker-compose"
    _compose_wrap_command() { echo "docker exec -i shopware-web-1 bash -c 'cd /var/www/html && $1'"; }
    run wrap_command "vendor/bin/phpunit"
    assert_success
    assert_output --partial "docker exec -i shopware-web-1"
    assert_output --partial "vendor/bin/phpunit"
}

@test "wrap_npm_command docker-compose: delegates to _compose_wrap_npm_command" {
    LINT_ENV="docker-compose"
    _compose_wrap_npm_command() { echo "docker exec -i shopware-web-1 bash -c 'cd /var/www/html/src/Administration/Resources/app/administration && $1'"; }
    run wrap_npm_command "npm run lint"
    assert_success
    assert_output --partial "docker exec -i shopware-web-1"
    assert_output --partial "npm run lint"
}
