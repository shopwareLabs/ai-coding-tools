#!/usr/bin/env bats
# bats file_tags=mcp-core,scope,environment
# Tests the shared environment module's scope handling: how SCOPE_CWD and
# SCOPE_JS_SUBDIR reach the wrapped command in each environment.
# Sources the template source of truth (templates/mcp-shared/environment.sh);
# every plugin copy is kept byte-identical to it by the template-sync CI check,
# so this one suite covers the module in all consuming plugins.
bats_require_minimum_version 1.11.0

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

setup() {
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    echo '{"environment":"native"}' > "${LINT_CONFIG_FILE}"
    log() { :; }
    source "${REPO_ROOT}/templates/mcp-shared/environment.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR DOCKER_CONTAINER SCOPE_CWD LINT_CONFIG_FILE \
        JS_CONTEXT SCOPE_JS_SUBDIR
}

# A directory whose name carries four of the characters the worktree module used
# to refuse in a project root: a space, a "$", a ";" and a single quote. They are
# the four that break in the widest range of ways — word splitting, parameter
# expansion, command separation and quote termination. The native wrappers no
# longer put the working directory into the command string, so it reaches the
# shell only as a quoted argument to cd and none of these is special any more.
# Arguments:
#   $1 - the leaf directory name to create under BATS_TEST_TMPDIR
# Outputs:
#   The absolute path of the created directory on stdout
_make_hostile_dir() {
    local dir="${BATS_TEST_TMPDIR}/$1"
    mkdir -p -- "${dir}"
    printf '%s\n' "${dir}"
}

@test "wrap_command native: no scope -> passthrough" {
    LINT_ENV="native"
    LINT_WORKDIR="/project"
    SCOPE_CWD=""
    run wrap_command "vendor/bin/phpstan analyze"
    assert_success
    assert_output "vendor/bin/phpstan analyze"
}

@test "wrap_command native: with scope -> passthrough, no directory in the command" {
    LINT_ENV="native"
    LINT_WORKDIR="/project"
    SCOPE_CWD="custom/plugins/X"
    run wrap_command "vendor/bin/phpstan analyze"
    assert_success
    assert_output "vendor/bin/phpstan analyze"
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

@test "wrap_npm_command native: scoped jest path stays out of the command" {
    LINT_ENV="native"
    LINT_WORKDIR="/project"
    JS_CONTEXT="admin"
    SCOPE_CWD="custom/plugins/X"
    SCOPE_JS_SUBDIR="tests/jest/administration"
    run wrap_npm_command "npm run unit"
    assert_success
    assert_output "npm run unit"
}

@test "exec_command native: runs in an unscoped workdir holding a space, a dollar, a semicolon and a quote" {
    LINT_ENV="native"
    LINT_WORKDIR=$(_make_hostile_dir "a b\$c;d'e")
    SCOPE_CWD=""
    run exec_command "pwd"
    assert_success
    assert_output "${LINT_WORKDIR}"
}

@test "exec_command native: runs in a scoped workdir holding a space, a dollar, a semicolon and a quote" {
    LINT_ENV="native"
    LINT_WORKDIR=$(_make_hostile_dir "a b\$c;d'e")
    SCOPE_CWD="p q\$r;s't"
    mkdir -p -- "${LINT_WORKDIR}/${SCOPE_CWD}"
    run exec_command "pwd"
    assert_success
    assert_output "${LINT_WORKDIR}/${SCOPE_CWD}"
}

@test "exec_npm_command native: runs in a JS workdir holding a space, a dollar, a semicolon and a quote" {
    LINT_ENV="native"
    LINT_WORKDIR=$(_make_hostile_dir "a b\$c;d'e")
    JS_CONTEXT=""
    SCOPE_CWD=""
    SCOPE_JS_SUBDIR=""
    run exec_npm_command "pwd"
    assert_success
    assert_output "${LINT_WORKDIR}"
}

# detect_environment assigns whatever ".environment" holds into LINT_ENV with no
# allowlist, so a typo reaches the wrappers' unknown-environment branch and the
# command it emits runs locally. The working directory has to be entered there
# too: leaving it to a `cd` inside the emitted string would put a "$" or a
# backtick from the project root into text that exec_npm_command evals.
@test "exec_npm_command: an unknown environment still runs in the workdir, not in the process directory" {
    LINT_ENV="podman"
    LINT_WORKDIR=$(_make_hostile_dir "a b\$c;d'e")
    JS_CONTEXT=""
    SCOPE_CWD=""
    SCOPE_JS_SUBDIR=""
    run exec_npm_command "pwd"
    assert_success
    assert_output "${LINT_WORKDIR}"
}

@test "wrap_npm_command: an unknown environment emits no working directory in the command" {
    LINT_ENV="podman"
    LINT_WORKDIR="/project"
    JS_CONTEXT=""
    SCOPE_CWD=""
    SCOPE_JS_SUBDIR=""
    run wrap_npm_command "npm run lint"
    assert_success
    assert_output "npm run lint"
}

@test "exec_command native: refuses a workdir that cannot be entered, naming it" {
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}/absent"
    SCOPE_CWD=""
    run exec_command "pwd"
    assert_failure
    assert_output --partial "could not be entered"
    assert_output --partial "${BATS_TEST_TMPDIR}/absent"
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
