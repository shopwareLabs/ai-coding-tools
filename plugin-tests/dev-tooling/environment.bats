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

# --- npm_script_body ---

@test "npm_script_body: prints a simple script body without JSON quotes" {
    exec_npm_command() { printf '%s\n' '"eslint --fix ./src"'; }
    run npm_script_body "lint:js:app:fix"
    assert_success
    assert_output "eslint --fix ./src"
}

@test "npm_script_body: prints a compound script body without JSON quotes" {
    exec_npm_command() { printf '%s\n' '"cd ../.. && eslint --config ./app/storefront/eslint.config.js"'; }
    run npm_script_body "eslint:components"
    assert_success
    assert_output "cd ../.. && eslint --config ./app/storefront/eslint.config.js"
}

@test "npm_script_body: reports a missing script with no output" {
    exec_npm_command() { printf '%s\n' '{}'; }
    run npm_script_body "eslint:app"
    assert_failure 1
    assert_output ""
}

@test "npm_script_body: queries the requested script key" {
    exec_npm_command() { printf '%s\n' "\"probed:$1\""; }
    run npm_script_body "unit:components"
    assert_success
    assert_output 'probed:npm pkg get "scripts.unit:components"'
}

# --- npm_script_append_safe ---

_assert_append_safe() {
    run npm_script_append_safe "$1"
    assert_success
}

_assert_append_unsafe() {
    run npm_script_append_safe "$1"
    assert_failure 1
}

@test "npm_script_append_safe: single command is safe" {
    _assert_append_safe "eslint --fix ./src"
}

@test "npm_script_append_safe: && chain ending in the tool is safe" {
    _assert_append_safe "cd ../.. && eslint --config x.js views/components"
}

@test "npm_script_append_safe: run-script delegation carrying -- is safe" {
    _assert_append_safe "npm run eslint:app -- ./src ./build"
}

@test "npm_script_append_safe: run-script delegation carrying -- and a flag is safe" {
    _assert_append_safe "npm run lint:scss -- --fix"
}

@test "npm_script_append_safe: && chain ending in a bare run-script is unsafe" {
    _assert_append_unsafe "npm run lint:js:app && npm run lint:js:components"
}

@test "npm_script_append_safe: a lone bare run-script is unsafe" {
    _assert_append_unsafe "npm run lint"
}

@test "npm_script_append_safe: body ending in a subshell close is unsafe" {
    _assert_append_unsafe "a && (cd .. && b)"
}

@test "npm_script_append_safe: body chaining with a semicolon is unsafe" {
    _assert_append_unsafe "x; y"
}

@test "npm_script_append_safe: body containing a pipe is unsafe" {
    _assert_append_unsafe "a | b"
}

# --- assert_paths_exist ---

@test "assert_paths_exist: succeeds when the probe reports nothing missing" {
    exec_npm_command() { printf '%s\n' ""; }
    run assert_paths_exist "../.." "views/components/checkout"
    assert_success
}

@test "assert_paths_exist: names every missing path" {
    exec_npm_command() { printf '%s\n' "MISSING:views/components/a" "MISSING:views/components/b"; }
    run assert_paths_exist "../.." "views/components/a" "views/components/b"
    assert_failure 1
    assert_output --partial "views/components/a"
    assert_output --partial "views/components/b"
}

@test "assert_paths_exist: probes from the given base directory" {
    exec_npm_command() { printf '%s\n' "$1" > "${BATS_TEST_TMPDIR}/probe.txt"; }
    run assert_paths_exist "../.." "views/components/checkout"
    assert_success
    run cat "${BATS_TEST_TMPDIR}/probe.txt"
    assert_output --partial 'cd "../.."'
}

@test "assert_paths_exist: probes without nesting a second shell" {
    exec_npm_command() { printf '%s\n' "$1" > "${BATS_TEST_TMPDIR}/probe.txt"; }
    run assert_paths_exist "." "src/plugin/cart.plugin.js"
    assert_success
    run cat "${BATS_TEST_TMPDIR}/probe.txt"
    refute_output --partial "sh -c"
}

@test "assert_paths_exist: rejects a call without any path" {
    run assert_paths_exist "../.."
    assert_failure 1
    assert_output --partial "at least one path"
}

@test "assert_paths_exist: rejects a path containing a single quote" {
    run assert_paths_exist "." "it's.js"
    assert_failure 1
    assert_output --partial "single quote"
}

# --- shell quoting ---

# Round-trips one value through a single shell parse, which is what every
# wrapper leaves the generated command with.
_assert_quote_roundtrip() {
    run bash -c "printf '%s' $(shell_quote_arg "$1")"
    assert_success
    assert_output "$1"
}

@test "shell_quote_arg: a value containing a space stays one argument" {
    _assert_quote_roundtrip "a b.js"
}

@test "shell_quote_arg: a command substitution stays literal" {
    # shellcheck disable=SC2016  # the literal $( ) is the payload under test
    _assert_quote_roundtrip 'src/$(printf INJECTED_MARKER_XYZ).js'
}

@test "shell_quote_arg: a double quote stays literal" {
    _assert_quote_roundtrip 'say"hi".js'
}

@test "shell_quote_arg: never emits a single quote" {
    run shell_quote_arg "plain.js"
    assert_success
    refute_output --partial "'"
}

@test "assert_no_shell_hostile_chars: rejects a value containing a newline" {
    run assert_no_shell_hostile_chars "path" $'a\nb.js'
    assert_failure 1
    assert_output --partial "line break"
}

@test "assert_no_shell_hostile_chars: accepts a value containing a space" {
    run assert_no_shell_hostile_chars "path" "a b.js"
    assert_success
}

# --- parse_paths_json ---

@test "parse_paths_json: quotes a path containing a space as one argument" {
    run parse_paths_json '["a b.js"]' ""
    assert_success
    assert_output '"a b.js"'
}

@test "parse_paths_json: rejects a path containing a single quote" {
    run parse_paths_json "[\"it's.js\"]" ""
    assert_failure 1
    assert_output --partial "single quote"
}

@test "parse_paths_json: returns the default for an empty array" {
    run parse_paths_json '[]' "."
    assert_success
    assert_output "."
}

@test "parse_paths_json: an absent paths key still takes the no-paths branch" {
    local paths_json
    paths_json=$(echo '{}' | jq -c '.paths // []')
    run parse_paths_json "${paths_json}" "."
    assert_success
    assert_output "."
}

@test "parse_paths_json: rejects an array containing an empty string" {
    run parse_paths_json '[""]' "."
    assert_failure 1
    assert_output --partial "non-empty strings"
}

@test "parse_paths_json: rejects an array containing a non-string entry" {
    run parse_paths_json '[1]' "."
    assert_failure 1
    assert_output --partial "non-empty strings"
}

@test "parse_paths_json: rejects a paths value that is not an array" {
    run parse_paths_json '"src/plugin/cart.js"' "."
    assert_failure 1
    assert_output --partial "must be an array of strings"
}

# --- assert_paths_lintable ---

# Runs the generated probe for real, from BATS_TEST_TMPDIR, the way the native
# wrapper runs it: one host parse, no nested shell.
_probe_against_tmpdir() {
    exec_npm_command() { ( cd "${BATS_TEST_TMPDIR}" && eval "$1" ); }
}

@test "assert_paths_exist: an injected command substitution is not executed" {
    _probe_against_tmpdir
    # shellcheck disable=SC2016  # the literal $( ) is the payload under test
    run assert_paths_exist "." 'src/$(printf INJECTED_MARKER_XYZ).js'
    assert_failure 1
    # shellcheck disable=SC2016  # the literal $( ) is what the message must echo back
    assert_output --partial 'src/$(printf INJECTED_MARKER_XYZ).js'
    refute_output --partial "src/INJECTED_MARKER_XYZ.js"
}

@test "assert_paths_lintable: accepts a directory holding a matching file" {
    mkdir -p "${BATS_TEST_TMPDIR}/src/plugin"
    touch "${BATS_TEST_TMPDIR}/src/plugin/cart.plugin.js"
    _probe_against_tmpdir
    run assert_paths_lintable "." "js ts vue" "src/plugin"
    assert_success
}

@test "assert_paths_lintable: rejects a directory holding no matching file" {
    mkdir -p "${BATS_TEST_TMPDIR}/src/scss"
    touch "${BATS_TEST_TMPDIR}/src/scss/base.scss"
    _probe_against_tmpdir
    run assert_paths_lintable "." "js ts vue" "src/scss"
    assert_failure 1
    assert_output --partial "src/scss"
    assert_output --partial "js ts vue"
}

@test "assert_paths_lintable: accepts a file carrying an accepted extension" {
    mkdir -p "${BATS_TEST_TMPDIR}/src/plugin"
    touch "${BATS_TEST_TMPDIR}/src/plugin/cart.plugin.js"
    _probe_against_tmpdir
    run assert_paths_lintable "." "js ts vue" "src/plugin/cart.plugin.js"
    assert_success
}

@test "assert_paths_lintable: rejects a file carrying another extension" {
    mkdir -p "${BATS_TEST_TMPDIR}/src/scss"
    touch "${BATS_TEST_TMPDIR}/src/scss/base.scss"
    _probe_against_tmpdir
    run assert_paths_lintable "." "js ts vue" "src/scss/base.scss"
    assert_failure 1
    assert_output --partial "src/scss/base.scss"
}

@test "assert_paths_lintable: reports a path that does not exist as missing" {
    _probe_against_tmpdir
    run assert_paths_lintable "." "js ts vue" "src/gone.js"
    assert_failure 1
    assert_output --partial "do not exist"
}

@test "assert_paths_lintable: accepts a path containing a space" {
    mkdir -p "${BATS_TEST_TMPDIR}/a b"
    touch "${BATS_TEST_TMPDIR}/a b/c.js"
    _probe_against_tmpdir
    run assert_paths_lintable "." "js" "a b/c.js"
    assert_success
}

@test "assert_paths_lintable: accepts a symlinked directory holding a matching file" {
    mkdir -p "${BATS_TEST_TMPDIR}/actual-plugin" "${BATS_TEST_TMPDIR}/src"
    touch "${BATS_TEST_TMPDIR}/actual-plugin/cart.plugin.js"
    ln -s "${BATS_TEST_TMPDIR}/actual-plugin" "${BATS_TEST_TMPDIR}/src/plugin"
    _probe_against_tmpdir
    run assert_paths_lintable "." "js ts vue" "src/plugin"
    assert_success
}

@test "assert_paths_lintable: rejects a call without an extension list" {
    run assert_paths_lintable "." "" "src/plugin"
    assert_failure 1
    assert_output --partial "extension list is required"
}

# --- stdin isolation ---

# The here-string supplies data on the call's stdin: code that lets the child
# inherit it (no `</dev/null` on the eval) echoes the data and fails the
# empty-output assertion, so a pass proves the child reads /dev/null instead.

@test "exec_command: does not consume the caller's stdin" {
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    run exec_command "cat" <<< "protocol-bytes"
    assert_success
    assert_output ""
}

@test "exec_npm_command: does not consume the caller's stdin" {
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    run exec_npm_command "cat" <<< "protocol-bytes"
    assert_success
    assert_output ""
}
