#!/usr/bin/env bats
# bats file_tags=mcp-core,environment
# Tests for the shared environment module: command wrapping per environment,
# argument quoting, path guards, and the npm script probes.
# Sources the template source of truth (templates/mcp-shared/environment.sh);
# every plugin copy is kept byte-identical to it by the template-sync CI check,
# so this one suite covers the module in all consuming plugins.
bats_require_minimum_version 1.11.0

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

setup() {
    log() { :; }
    source "${REPO_ROOT}/templates/mcp-shared/environment.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR DOCKER_CONTAINER
    unset PROJECT_ROOT WORKTREE_EFFECTIVE_ROOT LINT_CONFIG_FILE
    unset COMPOSE_SERVICE COMPOSE_WORKDIR_OVERRIDE COMPOSE_FILE_OVERRIDE
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
    assert_output --partial "docker exec -i \"shopware_app\""
    assert_output --partial "cd /var/www/html"
    assert_output --partial "vendor/bin/phpunit"
}

@test "wrap_command docker: a container name carrying a command separator becomes one quoted argument" {
    LINT_ENV="docker"
    DOCKER_CONTAINER='web; id'
    LINT_WORKDIR="/var/www/html"
    run wrap_command "bin/console cache:clear"
    assert_success
    assert_output "docker exec -i \"web; id\" bash -c 'cd /var/www/html && bin/console cache:clear'"
}

@test "wrap_npm_command docker: a container name carrying a command separator becomes one quoted argument" {
    LINT_ENV="docker"
    DOCKER_CONTAINER='web; id'
    LINT_WORKDIR="/var/www/html"
    run wrap_npm_command "npm run lint"
    assert_success
    assert_output "docker exec -i \"web; id\" bash -c 'cd /var/www/html && npm run lint'"
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

# --- get_workdir ---

@test "get_workdir native: returns LINT_WORKDIR unchanged" {
    LINT_ENV="native"
    LINT_WORKDIR="/project"
    run get_workdir
    assert_success
    assert_output "/project"
}

@test "get_workdir docker-compose: returns the workdir resolved from the compose config" {
    LINT_ENV="docker-compose"
    LINT_WORKDIR="(resolved at call time)"
    _compose_resolve_workdir() { printf '%s\n' "/var/www/html"; }
    run get_workdir
    assert_success
    assert_output "/var/www/html"
}

@test "get_workdir docker-compose: propagates the resolver's failure message" {
    LINT_ENV="docker-compose"
    LINT_WORKDIR="(resolved at call time)"
    _compose_resolve_workdir() {
        printf '%s\n' "No bind mount for /project found on service 'web'. Set docker-compose.workdir in config."
        return 1
    }
    run get_workdir
    assert_failure 1
    assert_output --partial "No bind mount for"
}

@test "get_workdir docker-compose: refuses when the compose module is not loaded" {
    LINT_ENV="docker-compose"
    LINT_WORKDIR="(resolved at call time)"
    run get_workdir
    assert_failure 1
    assert_output --partial "docker-compose support is not loaded"
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

@test "npm_script_body: refuses a script name that cannot be embedded, before probing" {
    exec_npm_command() { printf '%s\n' '"probe-ran"'; }
    run npm_script_body "lint'; id; :"
    assert_failure 2
    assert_output ""
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

# Under ddev the local eval consumes shell_quote_arg's escaping and `ddev exec`
# runs the rejoined argv through bash inside the container, so a value reaching
# that branch is parsed twice while the escaping is written for one.
@test "assert_no_shell_hostile_chars: under ddev, rejects a command substitution" {
    LINT_ENV="ddev"
    # shellcheck disable=SC2016  # the substitution must reach the guard as literal text, not expand here
    run assert_no_shell_hostile_chars "path" 'tests/$(id)x'
    assert_failure
    assert_output --partial "shell metacharacter"
}

@test "assert_no_shell_hostile_chars: under ddev, rejects a command separator" {
    LINT_ENV="ddev"
    run assert_no_shell_hostile_chars "path" 'tests/a;id'
    assert_failure
    assert_output --partial "shell metacharacter"
}

@test "assert_no_shell_hostile_chars: under ddev, accepts an ordinary path with a space" {
    LINT_ENV="ddev"
    run assert_no_shell_hostile_chars "path" 'src/a b.js'
    assert_success
}

@test "assert_no_shell_hostile_chars: under ddev, accepts a glob pattern" {
    LINT_ENV="ddev"
    run assert_no_shell_hostile_chars "path" 'src/**/*.js'
    assert_success
}

@test "assert_no_shell_hostile_chars: under docker, a command substitution is embeddable" {
    LINT_ENV="docker"
    # shellcheck disable=SC2016  # the substitution must reach the guard as literal text, not expand here
    run assert_no_shell_hostile_chars "path" 'tests/$(id)x'
    assert_success
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

# A line break inside one element used to split it into two paths: the decoded
# array is read back line by line, so the guard saw two break-free fragments and
# passed both. The fabricated second element here is ".", the whole tree.
@test "parse_paths_json: rejects an element containing a line break rather than splitting it" {
    run parse_paths_json "$(jq -nc '[("src/app" + "\n" + ".")]')" "."
    assert_failure
    assert_output --partial 'must not contain a line break'
    refute_output --partial '"src/app" "."'
}

@test "parse_paths_json: rejects an element containing a carriage return" {
    run parse_paths_json '["src/app\r."]' "."
    assert_failure
    assert_output --partial 'must not contain a line break'
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

# --- resolve_env_workdir ---

# The environments whose working directory is a configured base plus the host
# path's suffix below the project root. They differ only in the config key
# carrying that base, so every case below runs against all three rather than
# being copied per environment.
_CONFIGURED_WORKDIR_ENVS=(docker vagrant ddev)

# Write the config fixture holding a distinct workdir per environment above,
# and point LINT_CONFIG_FILE at it.
_write_workdir_config() {
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/workdirs.json"
    printf '%s\n' \
        '{"docker":{"workdir":"/docker/base","container":"shopware_app"},"vagrant":{"workdir":"/vagrant/base"},"ddev":{"workdir":"/ddev/base"}}' \
        > "${LINT_CONFIG_FILE}"
}

# The base _write_workdir_config gives one environment.
_config_fixture_base() {
    printf '%s\n' "/$1/base"
}

# Assert resolve_env_workdir for one host root under every environment whose
# base comes from the config. Both sides are built from the fixture base, so a
# change to the expected shape is one edit here.
# Args: $1 = host root relative to PROJECT_ROOT ("" for PROJECT_ROOT itself)
#       $2 = spelling appended to PROJECT_ROOT ("" plain, "/" trailing slash)
#       $3 = expected suffix below the base ("" for the base itself)
_assert_configured_mapping() {
    local host_rel="$1"
    local root_spelling="$2"
    local expected_rel="$3"

    local env base host_root expected
    for env in "${_CONFIGURED_WORKDIR_ENVS[@]}"; do
        LINT_ENV="${env}"
        PROJECT_ROOT="${BATS_TEST_TMPDIR}${root_spelling}"
        base="$(_config_fixture_base "${env}")"

        host_root="${PROJECT_ROOT}"
        if [[ -n "${host_rel}" ]]; then
            host_root="${host_root%/}/${host_rel}"
        fi

        expected="${base}"
        if [[ -n "${expected_rel}" ]]; then
            expected="${base}/${expected_rel}"
        fi

        run resolve_env_workdir "${host_root}"
        assert_success
        assert_output "${expected}"
    done
}

# Assert that a host root no environment-side path exists for is refused, in
# every environment whose base comes from the config.
# Args: $1 = host root, $2 = PROJECT_ROOT
_assert_configured_mapping_refuses() {
    local host_root="$1"
    local project_root="$2"

    local env
    for env in "${_CONFIGURED_WORKDIR_ENVS[@]}"; do
        LINT_ENV="${env}"
        PROJECT_ROOT="${project_root}"

        run resolve_env_workdir "${host_root}"
        assert_failure 1
        assert_output --partial "${host_root}"
        assert_output --partial "not inside the project root"
    done
}

@test "resolve_env_workdir: the launch root maps to the configured workdir" {
    _write_workdir_config
    _assert_configured_mapping "" "" ""
}

@test "resolve_env_workdir: a root below the launch root keeps its suffix below the configured workdir" {
    _write_workdir_config
    _assert_configured_mapping "custom/plugins/X" "" "custom/plugins/X"
}

@test "resolve_env_workdir: a trailing slash on the host root is not an extra path segment" {
    _write_workdir_config
    _assert_configured_mapping "custom/plugins/X/" "" "custom/plugins/X"
}

@test "resolve_env_workdir: a trailing slash on the project root is not an extra path segment" {
    _write_workdir_config
    _assert_configured_mapping "custom/plugins/X" "/" "custom/plugins/X"
}

@test "resolve_env_workdir: refuses a root outside the project root, naming it" {
    _write_workdir_config
    _assert_configured_mapping_refuses "${BATS_TEST_TMPDIR}/elsewhere" "${BATS_TEST_TMPDIR}/project"
}

@test "resolve_env_workdir: refuses a sibling whose path merely begins with the project root" {
    _write_workdir_config
    _assert_configured_mapping_refuses "${BATS_TEST_TMPDIR}/projectile" "${BATS_TEST_TMPDIR}/project"
}

# The launch-side base is an argument, not always PROJECT_ROOT. A caller whose
# root has already been resolved — the worktree module canonicalizes the call's
# root and the launch root together, so containment and the mapping measure the
# same two paths — hands that resolved launch root in, and the suffix has to be
# measured against it. Measured against the raw PROJECT_ROOT instead, the
# resolved root reads as outside the launch root and a root that exists is
# refused.
@test "resolve_env_workdir: measures the suffix against the launch base it is given" {
    _write_workdir_config
    LINT_ENV="docker"
    # Two spellings of one directory, as the two sides reach this function:
    # PROJECT_ROOT is the raw one the server started with, and the pair handed
    # in is what a symlink-resolving caller established.
    mkdir -p "${BATS_TEST_TMPDIR}/real/launch/.claude/worktrees/x"
    ln -s "${BATS_TEST_TMPDIR}/real/launch" "${BATS_TEST_TMPDIR}/launch-link"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}/launch-link"
    local resolved_root resolved_launch
    resolved_root=$(cd "${PROJECT_ROOT}/.claude/worktrees/x" && pwd -P)
    resolved_launch=$(cd "${PROJECT_ROOT}" && pwd -P)

    run resolve_env_workdir "${resolved_root}" "${resolved_launch}"
    assert_success
    assert_output "$(_config_fixture_base docker)/.claude/worktrees/x"
}

@test "resolve_env_workdir: an unset workdir falls back to the environment's documented default" {
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/defaults.json"
    printf '%s\n' '{"environment":"docker"}' > "${LINT_CONFIG_FILE}"

    local env base
    for env in "${_CONFIGURED_WORKDIR_ENVS[@]}"; do
        LINT_ENV="${env}"
        PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"
        case "${env}" in
            vagrant) base="/vagrant" ;;
            *) base="/var/www/html" ;;
        esac

        run resolve_env_workdir "${PROJECT_ROOT}/custom/plugins/X"
        assert_success
        assert_output "${base}/custom/plugins/X"
    done
}

@test "resolve_env_workdir: native returns the host path unchanged" {
    LINT_ENV="native"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"
    run resolve_env_workdir "${PROJECT_ROOT}/custom/plugins/X"
    assert_success
    assert_output "${PROJECT_ROOT}/custom/plugins/X"
}

# native builds no environment-side path: its wrapper runs the command against
# the host path it is given, so nothing is mapped and nothing is refused.
@test "resolve_env_workdir: native returns a path outside the project root unchanged" {
    LINT_ENV="native"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"
    run resolve_env_workdir "${BATS_TEST_TMPDIR}/elsewhere"
    assert_success
    assert_output "${BATS_TEST_TMPDIR}/elsewhere"
}

@test "resolve_env_workdir: refuses a call with no host path" {
    LINT_ENV="native"
    run resolve_env_workdir ""
    assert_failure 1
    assert_output --partial "a host path is required"
}

# --- _set_workdir_from_config: the re-derivation seam ---

# The seam is called for a configuration other than the launch one. Its results
# are asserted on the globals, which is where every wrapper reads them, and in
# the order a tool call reaches them: it runs inside the dispatch subshell, so
# what it writes there is what the call runs under.
@test "_set_workdir_from_config: writes the derived scalars into the globals the wrappers read" {
    local config="${BATS_TEST_TMPDIR}/worktree.json"
    printf '%s\n' '{"environment":"docker","docker":{"container":"worktree-container","workdir":"/wt/html"}}' > "${config}"

    local rc=0
    _set_workdir_from_config "/worktree" "${config}" "docker" || rc=$?

    assert_equal "${rc}" 0
    assert_equal "${LINT_WORKDIR}" "/wt/html"
    assert_equal "${DOCKER_CONTAINER}" "worktree-container"
}

@test "_set_workdir_from_config: leaves the configuration it did not read alone" {
    LINT_ENV="native"
    LINT_WORKDIR="/launch/root"
    DOCKER_CONTAINER="launch-container"
    COMPOSE_SERVICE="launch-service"
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/launch.json"
    printf '%s\n' '{"environment":"native"}' > "${LINT_CONFIG_FILE}"

    local config="${BATS_TEST_TMPDIR}/worktree.json"
    printf '%s\n' '{"environment":"docker","docker":{"container":"worktree-container","workdir":"/wt/html"}}' > "${config}"

    local rc=0
    _set_workdir_from_config "/worktree" "${config}" "docker" || rc=$?

    assert_equal "${rc}" 0
    # LINT_ENV and LINT_CONFIG_FILE are not this function's to write: it derives
    # the scalars of the file it was handed, and naming which environment those
    # belong to is the caller's decision.
    assert_equal "${LINT_ENV}" "native"
    assert_equal "${LINT_CONFIG_FILE}" "${BATS_TEST_TMPDIR}/launch.json"
}

# Every scalar is assigned on every path, so a caller that re-derives never
# reads a value left over from the environment it is leaving.
@test "_set_workdir_from_config: clears the scalars the derived environment does not use" {
    DOCKER_CONTAINER="launch-container"
    COMPOSE_SERVICE="launch-service"
    COMPOSE_WORKDIR_OVERRIDE="/launch/compose"

    local config="${BATS_TEST_TMPDIR}/worktree.json"
    printf '%s\n' '{"environment":"native"}' > "${config}"

    local rc=0
    _set_workdir_from_config "/worktree" "${config}" "native" || rc=$?

    assert_equal "${rc}" 0
    assert_equal "${LINT_WORKDIR}" "/worktree"
    assert_equal "${DOCKER_CONTAINER}" ""
    assert_equal "${COMPOSE_SERVICE}" ""
    assert_equal "${COMPOSE_WORKDIR_OVERRIDE}" ""
    assert_equal "${COMPOSE_FILE_OVERRIDE}" ""
}

@test "_set_workdir_from_config: reads each configured-workdir environment's base from the given config" {
    _write_workdir_config

    local env rc=0
    for env in "${_CONFIGURED_WORKDIR_ENVS[@]}"; do
        rc=0
        _set_workdir_from_config "/worktree" "${LINT_CONFIG_FILE}" "${env}" || rc=$?
        assert_equal "${rc}" 0
        assert_equal "${LINT_WORKDIR}" "$(_config_fixture_base "${env}")"
    done
}

@test "_set_workdir_from_config: refuses a docker config with no container, naming the config path and the field" {
    local config="${BATS_TEST_TMPDIR}/worktree.json"
    printf '%s\n' '{"environment":"docker"}' > "${config}"

    run _set_workdir_from_config "/worktree" "${config}" "docker"
    assert_failure 1
    assert_output --partial "${config}"
    assert_output --partial ".docker.container"
}

# The refusal has to reach the caller rather than the start of the process: the
# seam is called for a second configuration by a tool call, and an exit there
# would take the server down with no message a caller can read.
@test "_set_workdir_from_config: returns to its caller after refusing a docker config with no container" {
    local config="${BATS_TEST_TMPDIR}/worktree.json"
    printf '%s\n' '{"environment":"docker"}' > "${config}"

    local rc=0
    _set_workdir_from_config "/worktree" "${config}" "docker" 2>/dev/null || rc=$?

    assert_equal "${rc}" 1
}

@test "detect_environment: refuses a docker config with no container" {
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/launch.json"
    printf '%s\n' '{"environment":"docker"}' > "${LINT_CONFIG_FILE}"

    run detect_environment "/project"
    assert_failure 1
}

# A workdir of "/" is the container root. The join is where the doubled
# separator would appear, and "//x" is not the spelling any other component
# produced.
@test "resolve_env_workdir: a workdir of the container root does not double the separator" {
    LINT_ENV="ddev"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/root-workdir.json"
    printf '%s\n' '{"environment":"ddev","ddev":{"workdir":"/"}}' > "${LINT_CONFIG_FILE}"

    run resolve_env_workdir "${PROJECT_ROOT}/custom/plugins/X"
    assert_success
    assert_output "/custom/plugins/X"
}

@test "_set_workdir_from_config: refuses a config file that does not exist, naming it" {
    local absent="${BATS_TEST_TMPDIR}/absent.json"
    run _set_workdir_from_config "/worktree" "${absent}" "docker"
    assert_failure 1
    assert_output --partial "${absent}"
}

@test "_set_workdir_from_config: refuses an empty environment, naming the field" {
    local config="${BATS_TEST_TMPDIR}/worktree.json"
    printf '%s\n' '{"docker":{"container":"worktree-container"}}' > "${config}"

    run _set_workdir_from_config "/worktree" "${config}" ""
    assert_failure 1
    assert_output --partial '"environment"'
    assert_output --partial "${config}"
}

# --- SHELL_HOSTILE_METACHARS: one source, two readers ---

# The set exists as a variable so the guard below and the worktree module's
# root charset check cannot drift into different answers for one value. The test
# reads it rather than restating it, so a widened set is covered here without an
# edit — the property the variable is for.
@test "SHELL_HOSTILE_METACHARS: every character of the set is refused by the ddev guard" {
    LINT_ENV="ddev"

    local char
    for (( char = 0; char < ${#SHELL_HOSTILE_METACHARS}; char++ )); do
        local value="/srv/a${SHELL_HOSTILE_METACHARS:char:1}b"
        run assert_no_shell_hostile_chars "path" "${value}"
        assert_failure 1
        assert_output --partial "contains a shell metacharacter"
    done
}

@test "detect_environment: still binds the launch workdir from the launch config" {
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/launch.json"
    printf '%s\n' '{"environment":"docker","docker":{"container":"shopware_app","workdir":"/var/www/html"}}' > "${LINT_CONFIG_FILE}"

    detect_environment "/project"

    assert_equal "${LINT_ENV}" "docker"
    assert_equal "${LINT_WORKDIR}" "/var/www/html"
    assert_equal "${DOCKER_CONTAINER}" "shopware_app"
}

@test "detect_environment: native still binds the project root as the workdir" {
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/launch.json"
    printf '%s\n' '{"environment":"native"}' > "${LINT_CONFIG_FILE}"

    detect_environment "/project"

    assert_equal "${LINT_ENV}" "native"
    assert_equal "${LINT_WORKDIR}" "/project"
}

# --- ddev: the resolved workdir is named only for a call against a worktree ---

@test "wrap_command ddev: an unscoped command at the launch root keeps its argv" {
    LINT_ENV="ddev"
    LINT_WORKDIR="/var/www/html"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"
    WORKTREE_EFFECTIVE_ROOT="${PROJECT_ROOT}"
    run wrap_command "vendor/bin/phpunit"
    assert_success
    assert_output "ddev exec vendor/bin/phpunit"
}

@test "wrap_command ddev: an unscoped command against a worktree names the resolved workdir" {
    LINT_ENV="ddev"
    LINT_WORKDIR="/var/www/html/.claude/worktrees/x"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"
    WORKTREE_EFFECTIVE_ROOT="${PROJECT_ROOT}/.claude/worktrees/x"
    run wrap_command "vendor/bin/phpunit"
    assert_success
    assert_output 'ddev exec -d "/var/www/html/.claude/worktrees/x" vendor/bin/phpunit'
}

# The composer shortcut belongs to the launch root and nowhere else: `ddev
# composer` re-execs composer at ddev's own project root and takes no -d, so a
# worktree call routed through it would run against the launch tree while the
# banner attributes the result to the worktree. Both sides are asserted, and
# the launch-root side pins the argv byte for byte.
@test "wrap_command ddev: an unscoped composer call against a worktree names the resolved workdir" {
    LINT_ENV="ddev"
    LINT_WORKDIR="/var/www/html/.claude/worktrees/x"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"
    WORKTREE_EFFECTIVE_ROOT="${PROJECT_ROOT}/.claude/worktrees/x"
    run wrap_command "composer install"
    assert_success
    assert_output 'ddev exec -d "/var/www/html/.claude/worktrees/x" composer install'
}

@test "wrap_command ddev: an unscoped composer call at the launch root keeps the shortcut" {
    LINT_ENV="ddev"
    LINT_WORKDIR="/var/www/html"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"
    WORKTREE_EFFECTIVE_ROOT="${PROJECT_ROOT}"
    run wrap_command "composer install"
    assert_success
    assert_output "ddev composer install"
}
