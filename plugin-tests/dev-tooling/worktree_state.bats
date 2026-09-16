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
    worktree_gitdir_relative "${WORKTREE_ROOT}"
}

setup() {
    _make_git_worktree_fixture
    # A private TMPDIR, so the leak test at the end of this file can compare the
    # whole directory rather than a filename pattern. Both the state file and any
    # mktemp called without an explicit directory land here, and nothing else
    # writes into it.
    ORIGINAL_TMPDIR="${TMPDIR:-}"
    TMPDIR="${BATS_TEST_TMPDIR}/tmp"
    mkdir -p "${TMPDIR}"
    export TMPDIR
    CONFIG_PREFIX="php-tooling"
    LINT_CONFIG_FILE="${LAUNCH_ROOT}/.mcp-php-tooling.json"
    log() { :; }
    # Captured BEFORE the sources below, because config.sh installs
    # `trap config_cleanup EXIT` at source time and that replaces the EXIT trap
    # bats emits its result through. Without the restore at the end of this
    # function a FAILING test in this file produces no "not ok" line at all —
    # only "Executed N instead of expected M" — so a regression reads as a count
    # mismatch naming no test. Measured on this file: an assertion that cannot
    # hold reported nothing until this was added.
    BATS_EXIT_TRAP=$(trap -p EXIT)
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
    # Before any test body runs: the real exec_command reaches a container CLI
    # under a container environment. A test that means to exercise the probe
    # calls stub_worktree_probe to replace this.
    worktree_test_guard_probe
    eval "${BATS_EXIT_TRAP:-trap - EXIT}"
}

teardown() {
    # The cleanup the displaced trap would have run at exit.
    declare -F config_cleanup >/dev/null && config_cleanup
    worktree_state_cleanup
    TMPDIR="${ORIGINAL_TMPDIR}"
    export TMPDIR
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE PROJECT_ROOT DEV_TOOLING_STATE_FILE \
        CONFIG_PREFIX LAUNCH_ROOT WORKTREE_ROOT ORIGINAL_TMPDIR \
        WORKTREE_ENV_WORKDIR WORKTREE_LAUNCH_CONFIG_FILE WORKTREE_SELECTED_CONFIG_FILE \
        WORKTREE_PROBE_STUB_VERDICT
}

# The state file has two writers — the sticky root and the probe cache — and a
# write that rebuilt the object from nothing would drop the other's key with no
# error anywhere. The chain below is the one that produces both keys in the
# order a session does: set the sticky root, then run a probe, then write the
# sticky key again.
@test "a probe result recorded while a sticky root is set survives the next sticky write" {
    local in_root="${LAUNCH_ROOT}/.claude/worktrees/in-root"
    mkdir -p "$(dirname "${in_root}")"
    git -C "${LAUNCH_ROOT}" worktree add -q "${in_root}" -b wt-in-root-branch
    worktree_gitdir_relative "${in_root}"
    printf '{"environment":"docker"}\n' > "${LAUNCH_ROOT}/.mcp-php-tooling.json"
    LINT_ENV="docker"
    stub_worktree_probe pass

    run tool_set_project_root "{\"project_root\":\"${in_root}\"}"
    assert_success

    run worktree_resolve_root "{\"project_root\":\"${in_root}\"}"
    assert_success

    run jq -r '.probe_cache.docker | keys | length' "${DEV_TOOLING_STATE_FILE}"
    assert_success
    assert_output "1"

    run tool_set_project_root '{}'
    assert_success

    run jq -r '.probe_cache.docker | keys | length' "${DEV_TOOLING_STATE_FILE}"
    assert_success
    assert_output "1"
    run jq -r '.sticky_root // "absent"' "${DEV_TOOLING_STATE_FILE}"
    assert_success
    assert_output "absent"
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

# Clearing the sticky root is the recovery a session reaches for after
# ExitWorktree, so it is the one write that must not be blocked by the state
# file's own condition. A file removed underneath the process, or one whose
# content nothing can read, leaves nothing to preserve — a write that refused
# here would strand the session in a sticky root it cannot clear.
@test "set_project_root with no argument clears the sticky value when the state file is gone" {
    run tool_set_project_root "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_success

    rm -f "${DEV_TOOLING_STATE_FILE}"

    run tool_set_project_root '{}'
    assert_success
    assert_output --partial "Sticky project root cleared"

    run jq -r '.sticky_root // "absent"' "${DEV_TOOLING_STATE_FILE}"
    assert_success
    assert_output "absent"
}

@test "set_project_root with no argument clears the sticky value when the state file holds no object" {
    printf 'not json at all\n' > "${DEV_TOOLING_STATE_FILE}"

    run tool_set_project_root '{}'
    assert_success
    assert_output --partial "Sticky project root cleared"

    run jq -r '.sticky_root // "absent"' "${DEV_TOOLING_STATE_FILE}"
    assert_success
    assert_output "absent"
}

@test "a state write leaves the temporary directory exactly as it found it" {
    # The whole private TMPDIR is compared, not a name matching mktemp's
    # template. A glob built from the state file's name goes green the moment
    # the write puts its temp somewhere else, which is a change that leaves the
    # leak in place; the directory listing does not care what the file is called
    # or which mktemp form produced it.
    local before after
    before=$(find "${TMPDIR}" -mindepth 1 -maxdepth 1 | sort)

    run tool_set_project_root "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_success

    after=$(find "${TMPDIR}" -mindepth 1 -maxdepth 1 | sort)
    assert_equal "${after}" "${before}"
}
