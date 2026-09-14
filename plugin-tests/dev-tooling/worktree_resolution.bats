#!/usr/bin/env bats
# bats file_tags=dev-tooling,worktree,resolution
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

# A launch checkout plus real linked worktrees created with `git worktree add`,
# so validation against git's own registry (`_worktree_is_registered`) passes.
_make_git_worktree_fixture() {
    LAUNCH_ROOT="${BATS_TEST_TMPDIR}/launch"
    mkdir -p "${LAUNCH_ROOT}"
    git -C "${LAUNCH_ROOT}" init -q
    git -C "${LAUNCH_ROOT}" config user.email "test@example.com"
    git -C "${LAUNCH_ROOT}" config user.name "Test User"
    printf 'seed\n' > "${LAUNCH_ROOT}/seed.txt"
    git -C "${LAUNCH_ROOT}" add seed.txt
    git -C "${LAUNCH_ROOT}" commit -q -m "seed"
    printf '{"environment":"native"}\n' > "${LAUNCH_ROOT}/.mcp-php-tooling.json"
    mkdir -p "${LAUNCH_ROOT}/vendor"
    touch "${LAUNCH_ROOT}/vendor/autoload.php"

    WORKTREE_A="${BATS_TEST_TMPDIR}/wt-a"
    git -C "${LAUNCH_ROOT}" worktree add -q "${WORKTREE_A}" -b wt-a-branch
    WORKTREE_B="${BATS_TEST_TMPDIR}/wt-b"
    git -C "${LAUNCH_ROOT}" worktree add -q "${WORKTREE_B}" -b wt-b-branch
}

setup() {
    _make_git_worktree_fixture
    CONFIG_PREFIX="php-tooling"
    LINT_CONFIG_FILE="${LAUNCH_ROOT}/.mcp-php-tooling.json"
    log() { :; }
    source "${PLUGIN_DIR}/shared/config.sh"
    source "${PLUGIN_DIR}/shared/environment.sh"
    source "${PLUGIN_DIR}/shared/scope.sh"
    LINT_ENV="native"
    LINT_WORKDIR="${LAUNCH_ROOT}"
    PROJECT_ROOT="${LAUNCH_ROOT}"
    export PROJECT_ROOT
    # shellcheck source=/dev/null
    source "${PLUGIN_DIR}/shared/worktree.sh"
    worktree_state_init
}

teardown() {
    worktree_state_cleanup
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE PROJECT_ROOT DEV_TOOLING_STATE_FILE \
        CONFIG_PREFIX LAUNCH_ROOT WORKTREE_A WORKTREE_B
}

# Calls worktree_resolve_root and, on success, prints "root|source" so `run`
# can capture the two globals it sets without leaking the cd it performs into
# this test's own shell.
_resolve_and_report() {
    local args="$1"
    worktree_resolve_root "${args}" || return 1
    printf '%s|%s\n' "${WORKTREE_EFFECTIVE_ROOT}" "${WORKTREE_ROOT_SOURCE}"
}

# --- Precedence: call argument > sticky > launch ---

@test "a call argument takes precedence over a sticky root" {
    tool_set_project_root "{\"project_root\":\"${WORKTREE_A}\"}"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_B}\"}"
    assert_success
    assert_output "${WORKTREE_B}|call"
}

@test "a sticky root takes precedence over the launch root" {
    tool_set_project_root "{\"project_root\":\"${WORKTREE_A}\"}"

    run _resolve_and_report '{}'
    assert_success
    assert_output "${WORKTREE_A}|sticky"
}

@test "the launch root is used when neither a call argument nor a sticky root is set" {
    run _resolve_and_report '{}'
    assert_success
    assert_output "${LAUNCH_ROOT}|launch"
}

# --- Successful match against a real worktree ---

@test "a real linked worktree of the launch root resolves successfully" {
    run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_success
    assert_output "${WORKTREE_A}|call"
}

# --- Rejections ---

@test "a directory that is not a linked worktree of the launch root is refused" {
    local plain_dir="${BATS_TEST_TMPDIR}/not-a-worktree"
    mkdir -p "${plain_dir}"

    run _resolve_and_report "{\"project_root\":\"${plain_dir}\"}"
    assert_failure
    assert_output --partial "it holds no \".git\" file"
}

@test "a worktree declaring a non-native environment is refused while the launch config declares native" {
    printf '{"environment":"docker"}\n' > "${WORKTREE_A}/.mcp-php-tooling.json"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_failure
    assert_output --partial "declares the \"docker\" environment"
    assert_output --partial "a worktree outside the mounted tree does not exist inside the container"
}

@test "a worktree target is refused when the launch environment is containerized" {
    LINT_ENV="docker"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_failure
    assert_output --partial "this server was launched in the \"docker\" environment"
    assert_output --partial "supported only when the launch environment is native"
}

# Writes the given bytes as the worktree's own configuration and asserts the
# call is refused for it, naming the file. Each caller supplies one shape that
# nothing can be read from; jq answers them with three different exit statuses,
# and the guard has to refuse all of them.
_assert_worktree_config_refused() {
    printf '%s' "$1" > "${WORKTREE_A}/.mcp-php-tooling.json"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_failure
    assert_output --partial "${WORKTREE_A}/.mcp-php-tooling.json"
    assert_output --partial "is not a JSON object"
}

@test "a worktree config that does not parse as JSON is refused, naming the file" {
    _assert_worktree_config_refused '{"environment": "native"'
}

@test "a worktree config that is empty is refused, naming the file" {
    _assert_worktree_config_refused ''
}

@test "a worktree config holding only whitespace is refused, naming the file" {
    _assert_worktree_config_refused '   '
}

@test "a worktree config holding a JSON value that is not an object is refused, naming the file" {
    _assert_worktree_config_refused 'null'
}

@test "a worktree carrying no config of its own is not refused for a launch config that does not parse" {
    printf '{"environment": "native"\n' > "${LAUNCH_ROOT}/.mcp-php-tooling.json"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_success
    assert_output "${WORKTREE_A}|call"
}

# --- Fallback to the launch configuration ---

@test "a worktree carrying no config of its own falls back to the launch configuration" {
    printf '{"environment":"native","default_scope":"launch-marker","scopes":{"launch-marker":{"cwd":"x"}}}\n' \
        > "${LAUNCH_ROOT}/.mcp-php-tooling.json"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_success
    assert_output "${WORKTREE_A}|call"
}

# --- Temp-file ownership on a re-run of load_config ---

@test "a call that merges the worktree's own configs leaves the inherited _CONFIG_TEMP_FILE on disk, and removes only the file it created" {
    mkdir -p "${WORKTREE_A}/.claude"
    printf '{"environment":"native"}\n' > "${WORKTREE_A}/.mcp-php-tooling.json"
    printf '{"default_scope":"shopware"}\n' > "${WORKTREE_A}/.claude/.mcp-php-tooling.json"

    local inherited_temp
    inherited_temp=$(mktemp "${BATS_TEST_TMPDIR}/inherited.XXXXXX")
    printf '{}' > "${inherited_temp}"

    run bash -c '
        set -euo pipefail
        PLUGIN_DIR="'"${PLUGIN_DIR}"'"
        CONFIG_PREFIX="php-tooling"
        log() { :; }
        source "${PLUGIN_DIR}/shared/config.sh"
        source "${PLUGIN_DIR}/shared/environment.sh"
        source "${PLUGIN_DIR}/shared/scope.sh"
        PROJECT_ROOT="'"${LAUNCH_ROOT}"'"
        export PROJECT_ROOT
        LINT_CONFIG_FILE="'"${inherited_temp}"'"
        LINT_ENV="native"
        LINT_WORKDIR="${PROJECT_ROOT}"
        source "${PLUGIN_DIR}/shared/worktree.sh"
        worktree_state_init
        _CONFIG_TEMP_FILE="'"${inherited_temp}"'"
        worktree_resolve_root "{\"project_root\":\"'"${WORKTREE_A}"'\"}"
        printf "%s\n" "${WORKTREE_OWNED_TEMP_FILE}"
    '
    assert_success
    local owned_temp="${output}"

    assert [ -n "${owned_temp}" ]
    assert [ -f "${inherited_temp}" ]
    assert [ ! -f "${owned_temp}" ]
}

# --- worktree_assert_dependencies ---

@test "worktree_assert_dependencies refuses a PHP worktree with no installed vendor directory" {
    worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"

    run worktree_assert_dependencies
    assert_failure
    assert_output --partial "${WORKTREE_A}/vendor/autoload.php"
    assert_output --partial "composer install"
}

@test "worktree_assert_dependencies passes a PHP worktree with vendor/autoload.php present" {
    mkdir -p "${WORKTREE_A}/vendor"
    touch "${WORKTREE_A}/vendor/autoload.php"
    worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"

    run worktree_assert_dependencies
    assert_success
    assert_output ""
}

@test "worktree_assert_dependencies refuses a JS worktree with no installed node_modules" {
    JS_CONTEXT="admin"
    worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"

    run worktree_assert_dependencies
    assert_failure
    assert_output --partial "node_modules"
    assert_output --partial "npm ci"
    unset JS_CONTEXT
}

@test "worktree_assert_dependencies php passes a JS-server worktree carrying vendor but no node_modules" {
    JS_CONTEXT="storefront"
    mkdir -p "${WORKTREE_A}/vendor"
    touch "${WORKTREE_A}/vendor/autoload.php"
    worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"

    run worktree_assert_dependencies php
    assert_success
    assert_output ""
    unset JS_CONTEXT
}

@test "worktree_assert_dependencies php refuses a JS-server worktree carrying node_modules but no vendor" {
    JS_CONTEXT="storefront"
    mkdir -p "${WORKTREE_A}/src/Storefront/Resources/app/storefront/node_modules"
    worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"

    run worktree_assert_dependencies php
    assert_failure
    assert_output --partial "${WORKTREE_A}/vendor/autoload.php"
    assert_output --partial "composer install"
    unset JS_CONTEXT
}

@test "worktree_assert_dependencies refuses a dependency kind it does not know" {
    worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"

    run worktree_assert_dependencies python
    assert_failure
    assert_output --partial "unknown dependency kind"
}

# --- Path guard: the PHP boundary is the effective root, not the scope directory ---

@test "worktree_assert_paths_within_root admits an absolute path inside the worktree root but outside the scope directory" {
    mkdir -p "${WORKTREE_A}/custom/plugins/X" "${WORKTREE_A}/src/Other"
    printf '{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X"}}}\n' \
        > "${WORKTREE_A}/.mcp-php-tooling.json"
    # Not wrapped in `run`: the resolver's cd and resolve_scope's SCOPE_CWD
    # assignment must land in this test's own process for the direct call
    # below to see them. Each call is asserted explicitly rather than left as
    # a bare statement, so a failure here reads as "setup failed" and not as
    # a false pass of the assertion that follows.
    if ! worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"; then
        fail "worktree_resolve_root did not resolve the worktree root"
    fi
    if ! resolve_scope "plugin-x"; then
        fail "resolve_scope did not resolve the declared scope"
    fi
    [[ "${SCOPE_CWD}" == "custom/plugins/X" ]] || fail "resolve_scope did not set SCOPE_CWD to the scope's cwd"

    run worktree_assert_paths_within_root "[\"${WORKTREE_A}/src/Other/File.php\"]"
    assert_success
    assert_output ""
}

@test "worktree_assert_paths_within_root admits a path outside the scope directory on a JS server" {
    JS_CONTEXT="storefront"
    mkdir -p "${WORKTREE_A}/custom/plugins/X" "${WORKTREE_A}/src/Other"
    printf '{"environment":"native","scopes":{"plugin-x":{"cwd":"custom/plugins/X"}}}\n' \
        > "${WORKTREE_A}/.mcp-php-tooling.json"
    if ! worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"; then
        fail "worktree_resolve_root did not resolve the worktree root"
    fi
    if ! resolve_scope "plugin-x"; then
        fail "resolve_scope did not resolve the declared scope"
    fi
    [[ "${SCOPE_CWD}" == "custom/plugins/X" ]] || fail "resolve_scope did not set SCOPE_CWD to the scope's cwd"

    run worktree_assert_paths_within_root "[\"${WORKTREE_A}/src/Other/File.js\"]"
    assert_success
    assert_output ""
    unset JS_CONTEXT
}

@test "worktree_assert_paths_within_root admits a Storefront components path outside the JS package directory" {
    JS_CONTEXT="storefront"
    mkdir -p "${WORKTREE_A}/src/Storefront/Resources/views/components"
    if ! worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"; then
        fail "worktree_resolve_root did not resolve the worktree root"
    fi
    if ! resolve_scope ""; then
        fail "resolve_scope did not resolve the unscoped call"
    fi

    run worktree_assert_paths_within_root "[\"${WORKTREE_A}/src/Storefront/Resources/views/components/Example.js\"]"
    assert_success
    assert_output ""
    unset JS_CONTEXT
}

@test "worktree_assert_paths_within_root refuses an absolute path outside the worktree root" {
    if ! worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"; then
        fail "worktree_resolve_root did not resolve the worktree root"
    fi
    if ! resolve_scope ""; then
        fail "resolve_scope did not resolve the unscoped call"
    fi

    run worktree_assert_paths_within_root "[\"${WORKTREE_B}/src/File.php\"]"
    assert_failure
    assert_output --partial "resolve outside"
    assert_output --partial "${WORKTREE_A}"
}

# --- Banner contents for each source ---

@test "the banner names the call root and the call source" {
    worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"

    run worktree_root_banner
    assert_success
    assert_output "Project root: ${WORKTREE_A} (call)"
}

@test "the banner names the sticky root and the sticky source" {
    tool_set_project_root "{\"project_root\":\"${WORKTREE_A}\"}"
    worktree_resolve_root '{}'

    run worktree_root_banner
    assert_success
    assert_output "Project root: ${WORKTREE_A} (sticky)"
}

@test "the banner names the launch root and the launch source" {
    worktree_resolve_root '{}'

    run worktree_root_banner
    assert_success
    assert_output "Project root: ${LAUNCH_ROOT} (launch)"
}
