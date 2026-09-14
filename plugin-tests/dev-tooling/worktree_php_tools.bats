#!/usr/bin/env bats
# bats file_tags=dev-tooling,worktree,php
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

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
    mkdir -p "${WORKTREE_ROOT}/vendor"
    touch "${WORKTREE_ROOT}/vendor/autoload.php"
}

setup() {
    _make_git_worktree_fixture
    CONFIG_PREFIX="php-tooling"
    LINT_CONFIG_FILE="${LAUNCH_ROOT}/.mcp-php-tooling.json"
    log() { :; }
    CALLS_FILE="${BATS_TEST_TMPDIR}/calls.log"
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
    # Captures both the shell's cwd (proves the resolver's cd reached this
    # call) and LINT_WORKDIR (proves the resolver also rebound the variable
    # every real command-wrapping path reads). A regression that keeps the cd
    # but drops the LINT_WORKDIR rebind would pass on cwd alone.
    exec_command() { printf '[cwd=%s][workdir=%s] %s\n' "$(pwd)" "${LINT_WORKDIR}" "$1" >> "${CALLS_FILE}"; echo "$1"; }
    source "${PLUGIN_DIR}/mcp-server-php/lib/phpstan.sh"
    source "${PLUGIN_DIR}/mcp-server-php/lib/rector.sh"
    source "${PLUGIN_DIR}/mcp-server-php/lib/ecs.sh"
    source "${PLUGIN_DIR}/mcp-server-php/lib/phpunit.sh"
    source "${PLUGIN_DIR}/mcp-server-php/lib/phpunit_coverage.sh"
    source "${PLUGIN_DIR}/mcp-server-php/lib/console.sh"
}

teardown() {
    worktree_state_cleanup
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE SCOPE_NAME SCOPE_CWD CALLS_FILE \
        PROJECT_ROOT DEV_TOOLING_STATE_FILE CONFIG_PREFIX LAUNCH_ROOT WORKTREE_ROOT
}

@test "phpstan_analyze: a project_root argument reaches the resolved working directory" {
    run tool_phpstan_analyze "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --index 0 --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}]"
}

@test "ecs_check: a project_root argument reaches the resolved working directory" {
    run tool_ecs_check "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --index 0 --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}]"
}

@test "ecs_fix: a project_root argument reaches the resolved working directory" {
    run tool_ecs_fix "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --index 0 --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}]"
}

@test "rector_check: a project_root argument reaches the resolved working directory" {
    run tool_rector_check "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --index 0 --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}]"
}

@test "rector_fix: a project_root argument reaches the resolved working directory" {
    run tool_rector_fix "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --index 0 --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}]"
}

@test "phpunit_run: a project_root argument reaches the resolved working directory" {
    run tool_phpunit_run "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --index 0 --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}]"
}

@test "console_run: a project_root argument reaches the resolved working directory" {
    run tool_console_run "{\"project_root\":\"${WORKTREE_ROOT}\",\"command\":\"cache:clear\"}"
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --index 0 --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}]"
}

@test "console_list: a project_root argument reaches the resolved working directory" {
    run tool_console_list "{\"project_root\":\"${WORKTREE_ROOT}\",\"format\":\"json\"}"
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --index 0 --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}]"
}

# phpunit_coverage_gaps declares "scope" but never resolves it, so its
# project_root wiring goes directly from worktree_resolve_root into
# worktree_assert_dependencies with no resolve_scope call between them — the
# item this suite exists to catch a regression in individually.
@test "phpunit_coverage_gaps: a project_root argument reaches the resolved working directory" {
    exec_command() { printf '[cwd=%s][workdir=%s] %s\n' "$(pwd)" "${LINT_WORKDIR}" "$1" >> "${CALLS_FILE}"; echo "clover.xml not found"; return 1; }
    run tool_phpunit_coverage_gaps "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    run cat "${CALLS_FILE}"
    assert_line --index 0 --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}]"
}
