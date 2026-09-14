#!/usr/bin/env bats
# bats file_tags=dev-tooling,worktree,state
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

# A launch checkout plus one real linked worktree of it, created with
# `git worktree add`, both declaring a native environment so tool_set_project_root's
# validation passes.
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

    WORKTREE_ROOT="${BATS_TEST_TMPDIR}/wt"
    git -C "${LAUNCH_ROOT}" worktree add -q "${WORKTREE_ROOT}" -b wt-branch
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
        CONFIG_PREFIX LAUNCH_ROOT WORKTREE_ROOT
}

@test "a sticky value written by set_project_root is read back by cwd" {
    run tool_set_project_root "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_success

    run tool_cwd '{}'
    assert_success
    assert_output --partial "Sticky project root: ${WORKTREE_ROOT}"
    assert_output --partial "Effective project root: ${WORKTREE_ROOT} (sticky)"
}

@test "set_project_root with no argument clears the sticky value" {
    run tool_set_project_root "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_success

    run tool_set_project_root '{}'
    assert_success
    assert_output --partial "Sticky project root cleared"

    run tool_cwd '{}'
    assert_success
    assert_output --partial "Sticky project root: none"
    assert_output --partial "Effective project root: ${LAUNCH_ROOT} (launch)"
}

@test "set_project_root succeeds when sticky_root names a directory that no longer exists" {
    run tool_set_project_root "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_success
    rm -rf "${WORKTREE_ROOT}"

    run tool_set_project_root '{}'
    assert_success
    assert_output --partial "Sticky project root cleared"
}

@test "cwd succeeds when sticky_root names a directory that no longer exists" {
    run tool_set_project_root "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_success
    rm -rf "${WORKTREE_ROOT}"

    run tool_cwd '{}'
    assert_success
    assert_output --partial "Effective project root resolves: no"
}

@test "a state write leaves no partial temporary file beside the state file" {
    run tool_set_project_root "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_success

    run bash -c 'ls -1 "$(dirname "$1")"' _ "${DEV_TOOLING_STATE_FILE}"
    assert_success
    refute_output --partial "$(basename "${DEV_TOOLING_STATE_FILE}").XXXXXX"
    # Only the state file itself is present for this run's temp prefix — no
    # sibling starting with the same name plus a suffix.
    run bash -c 'find "$(dirname "$1")" -maxdepth 1 -name "$(basename "$1").*"' _ "${DEV_TOOLING_STATE_FILE}"
    assert_success
    assert_output ""
}
