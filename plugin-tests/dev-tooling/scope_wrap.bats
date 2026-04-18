#!/usr/bin/env bats
# bats file_tags=dev-tooling,scope,environment
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

setup() {
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    echo '{"environment":"native"}' > "${LINT_CONFIG_FILE}"
    log() { :; }
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/shared/environment.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR DOCKER_CONTAINER SCOPE_CWD LINT_CONFIG_FILE
}

@test "wrap_command native: no scope -> passthrough" {
    LINT_ENV="native"
    LINT_WORKDIR="/project"
    SCOPE_CWD=""
    run wrap_command "vendor/bin/phpstan analyze"
    assert_success
    assert_output "vendor/bin/phpstan analyze"
}

@test "wrap_command native: with scope -> explicit cd" {
    LINT_ENV="native"
    LINT_WORKDIR="/project"
    SCOPE_CWD="custom/plugins/X"
    run wrap_command "vendor/bin/phpstan analyze"
    assert_success
    assert_output 'cd "/project/custom/plugins/X" && vendor/bin/phpstan analyze'
}

@test "wrap_command docker: scope cwd appends to container workdir" {
    LINT_ENV="docker"
    LINT_WORKDIR="/var/www/html"
    DOCKER_CONTAINER="shop"
    SCOPE_CWD="custom/plugins/X"
    run wrap_command "vendor/bin/phpstan"
    assert_success
    assert_output --partial "cd /var/www/html/custom/plugins/X && vendor/bin/phpstan"
}

@test "wrap_command vagrant: scope cwd appends to vagrant workdir" {
    LINT_ENV="vagrant"
    LINT_WORKDIR="/vagrant"
    SCOPE_CWD="custom/plugins/X"
    run wrap_command "vendor/bin/phpstan"
    assert_success
    assert_output --partial "cd /vagrant/custom/plugins/X && vendor/bin/phpstan"
}

@test "wrap_command ddev: no scope -> ddev exec unchanged" {
    LINT_ENV="ddev"
    LINT_WORKDIR="/var/www/html"
    SCOPE_CWD=""
    run wrap_command "vendor/bin/phpstan"
    assert_success
    assert_output "ddev exec vendor/bin/phpstan"
}

@test "wrap_command ddev: scope adds -d flag" {
    LINT_ENV="ddev"
    LINT_WORKDIR="/var/www/html"
    SCOPE_CWD="custom/plugins/X"
    run wrap_command "vendor/bin/phpstan"
    assert_success
    assert_output 'ddev exec -d "/var/www/html/custom/plugins/X" vendor/bin/phpstan'
}

@test "wrap_command ddev: scoped composer routes through ddev exec -d" {
    LINT_ENV="ddev"
    LINT_WORKDIR="/var/www/html"
    SCOPE_CWD="custom/plugins/X"
    run wrap_command "composer install"
    assert_success
    assert_output 'ddev exec -d "/var/www/html/custom/plugins/X" composer install'
}

@test "wrap_command ddev: no-scope composer still uses ddev composer shortcut" {
    LINT_ENV="ddev"
    LINT_WORKDIR="/var/www/html"
    SCOPE_CWD=""
    run wrap_command "composer install"
    assert_success
    assert_output "ddev composer install"
}

@test "get_js_workdir: no scope, admin context -> core admin path" {
    LINT_WORKDIR="/project"
    JS_CONTEXT="admin"
    SCOPE_CWD=""
    SCOPE_JS_SUBDIR=""
    run get_js_workdir
    assert_success
    assert_output "/project/src/Administration/Resources/app/administration"
}

@test "get_js_workdir: scope active overrides JS_CONTEXT -> scope cwd only" {
    LINT_WORKDIR="/project"
    JS_CONTEXT="admin"
    SCOPE_CWD="custom/plugins/X"
    SCOPE_JS_SUBDIR=""
    run get_js_workdir
    assert_success
    assert_output "/project/custom/plugins/X"
}

@test "get_js_workdir: scope + SCOPE_JS_SUBDIR -> joined path" {
    LINT_WORKDIR="/project"
    JS_CONTEXT="admin"
    SCOPE_CWD="custom/plugins/X"
    SCOPE_JS_SUBDIR="tests/jest/administration"
    run get_js_workdir
    assert_success
    assert_output "/project/custom/plugins/X/tests/jest/administration"
}

@test "wrap_npm_command native: scoped jest path" {
    LINT_ENV="native"
    LINT_WORKDIR="/project"
    JS_CONTEXT="admin"
    SCOPE_CWD="custom/plugins/X"
    SCOPE_JS_SUBDIR="tests/jest/administration"
    run wrap_npm_command "npm run unit"
    assert_success
    assert_output "cd /project/custom/plugins/X/tests/jest/administration && npm run unit"
}

@test "wrap_npm_command ddev: scoped path uses cd && ddev npm" {
    LINT_ENV="ddev"
    LINT_WORKDIR="/var/www/html"
    JS_CONTEXT="storefront"
    SCOPE_CWD="custom/plugins/X"
    SCOPE_JS_SUBDIR=""
    run wrap_npm_command "npm run lint"
    assert_success
    assert_output "cd /var/www/html/custom/plugins/X && ddev npm run lint"
}
