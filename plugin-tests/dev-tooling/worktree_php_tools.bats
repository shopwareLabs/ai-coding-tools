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
    worktree_gitdir_relative "${WORKTREE_ROOT}"
    mkdir -p "${WORKTREE_ROOT}/vendor"
    touch "${WORKTREE_ROOT}/vendor/autoload.php"
}

setup() {
    _make_git_worktree_fixture
    CONFIG_PREFIX="php-tooling"
    LINT_CONFIG_FILE="${LAUNCH_ROOT}/.mcp-php-tooling.json"
    log() { :; }
    CALLS_FILE="${BATS_TEST_TMPDIR}/calls.log"
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
    # Captures both the shell's cwd (proves the resolver's cd reached this
    # call) and LINT_WORKDIR (proves the resolver also rebound the variable
    # every real command-wrapping path reads). A regression that keeps the cd
    # but drops the LINT_WORKDIR rebind would pass on cwd alone.
    exec_command() { printf '[cwd=%s][workdir=%s] %s\n' "$(pwd)" "${LINT_WORKDIR}" "$1" >> "${CALLS_FILE}"; echo "$1"; }
    source "${PLUGIN_DIR}/mcp-server-php/lib/phpunit_coverage.sh"
    eval "${BATS_EXIT_TRAP:-trap - EXIT}"
}

teardown() {
    # The cleanup the displaced trap would have run at exit.
    declare -F config_cleanup >/dev/null && config_cleanup
    worktree_state_cleanup
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE SCOPE_NAME SCOPE_CWD CALLS_FILE \
        PROJECT_ROOT DEV_TOOLING_STATE_FILE CONFIG_PREFIX LAUNCH_ROOT WORKTREE_ROOT \
        WORKTREE_ENV_WORKDIR WORKTREE_LAUNCH_CONFIG_FILE WORKTREE_SELECTED_CONFIG_FILE
}

# The coverage-gap strip removes the directory the wrapped command ran in from
# the paths the Clover report carries, which are the environment's own paths.
# Under a container environment that prefix is the environment-side working
# directory, not the host root — and get_workdir is the tool's bare call site
# for it, unchanged by the rebinding. A run that stripped the host root instead
# would leave the container prefix on every reported path.
@test "phpunit_coverage_gaps strips the environment-side working directory from the clover paths" {
    local in_root="${LAUNCH_ROOT}/.claude/worktrees/in-root"
    mkdir -p "$(dirname "${in_root}")"
    git -C "${LAUNCH_ROOT}" worktree add -q "${in_root}" -b wt-in-root-branch
    worktree_gitdir_relative "${in_root}"
    mkdir -p "${in_root}/vendor"
    touch "${in_root}/vendor/autoload.php"
    printf '{"environment":"docker","docker":{"workdir":"/srv/app","container":"shopware_app"}}\n' \
        > "${LAUNCH_ROOT}/.mcp-php-tooling.json"
    LINT_ENV="docker"
    # Bound with LINT_ENV, because detect_environment binds both from the same
    # file: the environment decides which workdir key is read, and the workdir is
    # what the mapping is based on. Leaving this at the launch root would model a
    # server that never started, and the mapped path would then measure its
    # suffix below a directory the configuration never named.
    LINT_WORKDIR="/srv/app"

    exec_command() {
        case "$1" in
            "test -d "*) return 0 ;;
        esac
        printf '%s\n' '<coverage><project><file name="/srv/app/.claude/worktrees/in-root/src/Covered.php"><metrics statements="2" coveredstatements="1"/><line num="7" type="stmt" count="0"/></file></project></coverage>'
    }

    run tool_phpunit_coverage_gaps "{\"project_root\":\"${in_root}\"}"
    assert_success
    assert_output --partial "src/Covered.php"
    refute_output --partial "/srv/app"
}

# Every PHP tool's positive path — this one included — is covered per tool by
# worktree_conformance.bats, which scans the whole live tool_* set for the same
# [cwd][workdir] signal. phpunit_coverage_gaps resolves scope like the rest of
# them (mcp-server-php/lib/phpunit_coverage.sh calls resolve_scope between
# worktree_enter and worktree_assert_dependencies), so it needs no separate
# positive case here. What lives only here is the path where the clover read
# fails: the tool has to report its own read error rather than fall through to
# an empty-coverage result, and it has to have run in the named worktree while
# doing so.
@test "phpunit_coverage_gaps: a refused clover read reports the tool's own error from the resolved working directory" {
    exec_command() { printf '[cwd=%s][workdir=%s] %s\n' "$(pwd)" "${LINT_WORKDIR}" "$1" >> "${CALLS_FILE}"; echo "stub: clover read refused"; return 1; }
    run tool_phpunit_coverage_gaps "{\"project_root\":\"${WORKTREE_ROOT}\"}"
    assert_failure
    # The tool's own message for an unreadable report, naming the default
    # clover_path it resolved — not the stub's echo, which proves only that the
    # stub ran.
    assert_output --partial "Error: Cannot read clover XML at 'coverage.xml'"

    run cat "${CALLS_FILE}"
    assert_line --index 0 --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}]"
}
