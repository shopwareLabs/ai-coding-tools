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
    worktree_gitdir_relative "${WORKTREE_A}"
    WORKTREE_B="${BATS_TEST_TMPDIR}/wt-b"
    git -C "${LAUNCH_ROOT}" worktree add -q "${WORKTREE_B}" -b wt-b-branch
    worktree_gitdir_relative "${WORKTREE_B}"

    # Inside the launch root, which is where the four container environments
    # require a worktree target to sit: a container mounts the launch root and
    # nothing else.
    WORKTREE_IN_ROOT="${LAUNCH_ROOT}/.claude/worktrees/in-root"
    mkdir -p "$(dirname "${WORKTREE_IN_ROOT}")"
    git -C "${LAUNCH_ROOT}" worktree add -q "${WORKTREE_IN_ROOT}" -b wt-in-root-branch
    worktree_gitdir_relative "${WORKTREE_IN_ROOT}"
    mkdir -p "${WORKTREE_IN_ROOT}/vendor"
    touch "${WORKTREE_IN_ROOT}/vendor/autoload.php"
}

setup() {
    _make_git_worktree_fixture
    CONFIG_PREFIX="php-tooling"
    LINT_CONFIG_FILE="${LAUNCH_ROOT}/.mcp-php-tooling.json"
    log() { :; }
    # Captured BEFORE the sources below, because config.sh installs
    # `trap config_cleanup EXIT` at source time and that replaces the EXIT trap
    # bats emits its result through. Without the restore at the end of this
    # function a FAILING test in this file produces no "not ok" line at all —
    # only "Executed N instead of expected M" — so a regression here reads as a
    # count mismatch naming no test. Capturing after the sources saves the
    # already-displaced trap and fixes nothing.
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
    _wrap_with_trap_restore worktree_resolve_root
    _wrap_with_trap_restore tool_set_project_root
    _restore_bats_exit_trap
}

_restore_bats_exit_trap() {
    eval "${BATS_EXIT_TRAP:-trap - EXIT}"
}

# The tools that install a dispatch-subshell EXIT trap for their call-owned temp
# files do it in this process too when a test calls them WITHOUT `run`, where it
# displaces bats' trap — and then a later failing assertion in that test produces
# no "not ok" line at all, only "Executed N instead of expected M", naming no
# test. Two functions install one: worktree_resolve_root and
# tool_set_project_root, the latter since it gained the same arrangement.
#
# Restoring the trap at each call site would work and would be forgotten: the
# next test added to this file has to know a rule nothing enforces. So the
# restore is moved into the function itself, under its own name, for the
# lifetime of this process. Tests call them as they would anywhere, and there is
# nothing left to remember.
#
# Only this process is affected. The generated scripts below run in their own
# bash processes and source shared/worktree.sh fresh, so they get the real
# functions and the real traps, which is what makes them a faithful model of a
# tool dispatch.
# Args: $1 = the function to wrap
_wrap_with_trap_restore() {
    local fn="$1"
    eval "_${fn}_without_trap_restore() $(declare -f "${fn}" | tail -n +2)"
    eval "${fn}() {
    local rc=0
    _${fn}_without_trap_restore \"\$@\" || rc=\$?
    # Restored only in the test process itself. \`run\` resolves in a subshell
    # where the tool's trap dies on its own, and installing bats' trap
    # there makes it fire a second time as that subshell ends — one test then
    # emits two result lines and the file reports more tests than it has.
    if [[ \"\${BASHPID}\" == \"\$\$\" ]]; then
        _restore_bats_exit_trap
    fi
    return \"\${rc}\"
}"
}

teardown() {
    # The cleanups the displaced traps would have run at exit. Both are guarded
    # against an empty variable, so calling them here is safe whether or not the
    # test reached the code that arms them.
    declare -F config_cleanup >/dev/null && config_cleanup
    declare -F worktree_release_owned_temp >/dev/null && worktree_release_owned_temp
    worktree_state_cleanup
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE PROJECT_ROOT DEV_TOOLING_STATE_FILE \
        CONFIG_PREFIX LAUNCH_ROOT WORKTREE_A WORKTREE_B WORKTREE_IN_ROOT \
        WORKTREE_ENV_WORKDIR WORKTREE_LAUNCH_CONFIG_FILE WORKTREE_SELECTED_CONFIG_FILE \
        WORKTREE_PROBE_STUB_VERDICT
}

# Calls worktree_resolve_root and, on success, prints "root|source" so `run`
# can capture the two globals it sets without leaking the cd it performs into
# this test's own shell.
_resolve_and_report() {
    local args="$1"
    worktree_resolve_root "${args}" || return 1
    printf '%s|%s\n' "${WORKTREE_EFFECTIVE_ROOT}" "${WORKTREE_ROOT_SOURCE}"
}

# The environment-side binding the resolution left behind, which `run` would
# otherwise discard with the subshell that performed the cd.
_resolve_and_report_workdir() {
    local args="$1"
    worktree_resolve_root "${args}" || return 1
    printf '%s|%s\n' "${LINT_WORKDIR}" "${WORKTREE_ENV_WORKDIR}"
}

# The environment the resolution left in force, and the environment-side path.
_resolve_and_report_binding() {
    local args="$1"
    worktree_resolve_root "${args}" || return 1
    printf '%s|%s|%s\n' "${LINT_ENV}" "${LINT_WORKDIR}" "${WORKTREE_ENV_WORKDIR}"
}

# --- Precedence: call argument > sticky > launch ---

@test "a call argument takes precedence over a sticky root" {
    tool_set_project_root "{\"project_root\":\"${WORKTREE_A}\"}"
    # The sticky root has to be armed for the precedence claim to mean anything.
    # Without this the test passes with tool_set_project_root doing nothing at
    # all, and then it only repeats "a real linked worktree of the launch root
    # resolves successfully".
    run _worktree_state_read_sticky
    assert_success
    assert_output "${WORKTREE_A}"

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

# The two below are the forgeries the git-dir/common-dir inequality admits. Both
# were verified to kill the check they name: neutering the back-pointer test
# makes this pair the only failures in the file, and without them the whole
# cluster can be removed with every other test still green.

@test "a git too old for --path-format is refused by naming the version, not the flag" {
    # _worktree_git_dir_pair runs git through `env`, which execs a program and
    # cannot see a shell function, so the stand-in has to be a real executable
    # ahead of git on PATH. It reproduces what every git below 2.31 does with an
    # option it does not know: echo it back and exit 0, which shifts the two-line
    # read by one and used to surface as a git directory named
    # "--path-format=absolute".
    local fake_bin="${BATS_TEST_TMPDIR}/fake-bin"
    mkdir -p "${fake_bin}"
    cat > "${fake_bin}/git" <<'FAKE'
#!/usr/bin/env bash
for arg in "$@"; do
    case "${arg}" in
        --path-format=*) printf '%s\n' "${arg}" ;;
        --git-dir) printf '.git\n' ;;
        --git-common-dir) printf '.git\n' ;;
    esac
done
exit 0
FAKE
    chmod +x "${fake_bin}/git"

    PATH="${fake_bin}:${PATH}" run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_failure
    assert_output --partial "git 2.31"
    refute_output --partial 'the git directory "--path-format=absolute"'
}

@test "a hand-written .git pointing at a real sibling worktree's git directory is refused" {
    local forged="${BATS_TEST_TMPDIR}/forged"
    mkdir -p "${forged}"
    # Borrow worktree B's per-worktree directory. Every earlier test passes —
    # ".git" is a regular file, the git dir differs from the common dir, and the
    # common dir is the launch root's — but B's back-pointer names B, not this.
    local sibling_gitdir
    sibling_gitdir=$(git -C "${WORKTREE_B}" rev-parse --absolute-git-dir)
    printf 'gitdir: %s\n' "${sibling_gitdir}" > "${forged}/.git"

    run _resolve_and_report "{\"project_root\":\"${forged}\"}"
    assert_failure
    assert_output --partial "belongs to the worktree at"
    assert_output --partial "${WORKTREE_B}"
}

@test "a back-pointer written relative resolves against the per-worktree directory" {
    # `git worktree add --relative-paths` writes BOTH links relative: the
    # ".git" pointer and the back-pointer, the latter relative to the
    # per-worktree directory holding it. Resolving that back-pointer from the
    # process working directory instead refused every such worktree as
    # hand-written. The preconditions pin the all-relative state so this test
    # cannot silently weaken if the fixture regresses to absolute linkage.
    local wt_gitdir gitdir_line backpointer
    wt_gitdir=$(git -C "${WORKTREE_A}" rev-parse --path-format=absolute --git-dir)
    gitdir_line=$(< "${WORKTREE_A}/.git")
    assert [ "${gitdir_line#gitdir: /}" = "${gitdir_line}" ]
    backpointer=$(< "${wt_gitdir}/gitdir")
    assert [ "${backpointer#/}" = "${backpointer}" ]

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_success
    assert_output "${WORKTREE_A}|call"
}

@test "a relative pointer with an absolute back-pointer is still accepted" {
    # The mixed state a partial relink leaves behind: ".git" relative, the
    # back-pointer absolute. Both spellings name the same directory, so the
    # identity holds.
    local wt_gitdir canonical
    wt_gitdir=$(git -C "${WORKTREE_A}" rev-parse --path-format=absolute --git-dir)
    canonical=$(cd "${WORKTREE_A}" && pwd -P)
    printf '%s/.git\n' "${canonical}" > "${wt_gitdir}/gitdir"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_success
    assert_output "${WORKTREE_A}|call"
}

@test "a .git pointing at an administrative directory with no gitdir back-pointer is refused" {
    local real_gitdir orphan_gitdir orphan
    real_gitdir=$(git -C "${WORKTREE_B}" rev-parse --absolute-git-dir)
    orphan_gitdir="$(dirname "${real_gitdir}")/orphan"
    # A complete administrative directory minus its back-pointer. A directory
    # holding only "commondir" is rejected by git itself ("not a git
    # repository"), which lands on the earlier refusal instead and never reaches
    # the one under test; a full copy resolves and does reach it.
    cp -R "${real_gitdir}" "${orphan_gitdir}"
    rm -f "${orphan_gitdir}/gitdir"
    orphan="${BATS_TEST_TMPDIR}/orphan-root"
    mkdir -p "${orphan}"
    printf 'gitdir: %s\n' "${orphan_gitdir}" > "${orphan}/.git"

    run _resolve_and_report "{\"project_root\":\"${orphan}\"}"
    assert_failure
    assert_output --partial "holds no \"gitdir\" back-pointer"
}

# --- The environment decides whether an out-of-root target is reachable ---
#
# The old gate refused every container environment outright and refused any
# worktree that declared one. What actually decides is whether the container
# can reach the root at all, which is a question about the root's place in the
# launch tree rather than about the environment's name.

# The environments whose commands run inside a container that mounts the launch
# root. Enumerated at runtime because the verdict and the message are one shape
# for all four, and because the list is the one the module's own case statement
# carries — a fifth added there fails here without an edit.
_CONTAINER_ENVS=(docker docker-compose vagrant ddev)

# Point the launch configuration at one environment, with every configured
# workdir the same so a suite asserting a mapped path holds one expectation
# whichever of the three it is driving.
#
# LINT_WORKDIR is bound too, because the startup binding is two values and not
# one: detect_environment reads the same file for LINT_ENV and for the workdir
# the mapping is based on. A fixture that bound only the first would model a
# state no server starts in, and the mapping — which reads the startup scalar —
# would then measure the suffix below a directory the configuration never named.
_write_launch_environment() {
    printf '{"environment":"%s","docker":{"workdir":"/srv/app","container":"shopware_app"},"vagrant":{"workdir":"/srv/app"},"ddev":{"workdir":"/srv/app"}}\n' "$1" \
        > "${LAUNCH_ROOT}/.mcp-php-tooling.json"

    # The value _set_workdir_from_config assigns for each environment: the
    # configured workdir for the three, the call-time sentinel for
    # docker-compose, and the project root for native.
    case "$1" in
        docker|vagrant|ddev) LINT_WORKDIR="/srv/app" ;;
        docker-compose) LINT_WORKDIR="(resolved at call time)" ;;
        *) LINT_WORKDIR="${LAUNCH_ROOT}" ;;
    esac
}

@test "an out-of-root worktree target is refused under every container environment" {
    local environment
    for environment in "${_CONTAINER_ENVS[@]}"; do
        _assert_out_of_root_refused "${environment}"
    done
}

@test "a worktree whose own configuration declares an unrecognized environment is refused" {
    # The environment value selects which guards apply, so an unrecognized
    # spelling must refuse rather than fall through to the permissive native
    # path: a "docker " typo in the worktree's own config would otherwise skip
    # containment, charset and probe and run the command on the host.
    _write_launch_environment native
    LINT_ENV="native"
    printf '{"environment":"podman"}\n' > "${WORKTREE_A}/.mcp-php-tooling.json"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_failure
    assert_output --partial '"podman"'
    assert_output --partial "does not recognize"
}

@test "an out-of-root worktree whose OWN configuration declares a container environment is refused for containment" {
    # Containment must key on the configuration in force for the call — the
    # worktree's own — not on the launch environment: a regression that reads
    # LINT_ENV here accepts this root because the launch config is native.
    _write_launch_environment native
    LINT_ENV="native"
    printf '{"environment":"docker","docker":{"workdir":"/srv/app","container":"c"}}\n' > "${WORKTREE_A}/.mcp-php-tooling.json"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_failure
    assert_output --partial 'the "docker" environment runs commands inside a container'
}

_assert_out_of_root_refused() {
    local environment="$1"
    _write_launch_environment "${environment}"
    LINT_ENV="${environment}"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_failure
    assert_output --partial "the \"${environment}\" environment runs commands inside a container"
    assert_output --partial "The supported pattern is a worktree created inside the launch project root"
}

# The containment test is what makes an out-of-root target unreachable, so it
# has to measure where a path IS and not how it is spelled. Every check ahead of
# it compares canonical paths — the back-pointer test and `git worktree list`
# both do — so a registered worktree outside the launch root reached through a
# ".." segment passes all of them and has to be caught here.
@test "an out-of-root worktree spelled through a dot segment is refused under a container environment" {
    _write_launch_environment docker
    LINT_ENV="docker"
    stub_worktree_probe pass

    # WORKTREE_A really is outside LAUNCH_ROOT; this spelling walks out of it
    # and back in, so a raw prefix comparison reads it as inside.
    local spelled
    spelled="$(dirname "${LAUNCH_ROOT}")/$(basename "${LAUNCH_ROOT}")/../$(basename "${WORKTREE_A}")"

    run _resolve_and_report "{\"project_root\":\"${spelled}\"}"
    assert_failure
    assert_output --partial "runs commands inside a container"
    assert_output --partial "The supported pattern is a worktree created inside the launch project root"
}

# The supported pattern itself, under the three environments whose mapping is
# read from the config alone. docker-compose resolves its path through the
# compose CLI and is covered separately.
_CONFIG_ONLY_CONTAINER_ENVS=(docker vagrant ddev)

@test "an in-root worktree target resolves to the environment-side path under every config-only container environment" {
    local environment
    for environment in "${_CONFIG_ONLY_CONTAINER_ENVS[@]}"; do
        _assert_in_root_resolved "${environment}"
    done
}

_assert_in_root_resolved() {
    local environment="$1"
    _write_launch_environment "${environment}"
    LINT_ENV="${environment}"
    stub_worktree_probe pass

    run _resolve_and_report_workdir "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_success
    assert_output "/srv/app/.claude/worktrees/in-root|/srv/app/.claude/worktrees/in-root"
}

# Containment measures canonical paths, so the mapping that follows it has to
# measure the same pair. A root the caller spelled through a symlink is inside
# the launch root by every test validation runs — the back-pointer check and
# `git worktree list` compare canonically — and a mapping that compared the
# symlink's own spelling against the launch root then refused it as out-of-root,
# a peer of the dot-segment case above where the answer is the opposite one.
@test "an in-root worktree reached through a symlink resolves under a container environment" {
    _write_launch_environment docker
    LINT_ENV="docker"
    stub_worktree_probe pass

    # Beside the launch root rather than inside it, so the symlink's own
    # spelling is genuinely not below PROJECT_ROOT: this is the input the old
    # mapping refused, not one it would have accepted by accident.
    local link="${BATS_TEST_TMPDIR}/in-root-link"
    ln -s "${WORKTREE_IN_ROOT}" "${link}"

    run _resolve_and_report_workdir "{\"project_root\":\"${link}\"}"
    assert_success
    assert_output "/srv/app/.claude/worktrees/in-root|/srv/app/.claude/worktrees/in-root"
}

# The docker-compose arm reads its mount list from the compose CLI, which no
# suite here executes. What is asserted is the wiring: worktree_enter binds
# LINT_WORKDIR to the resolver's answer and records it as the environment-side
# path, rather than binding the host root. The mapping itself is covered in
# plugin-tests/mcp-shared/docker_compose.bats.
@test "an in-root worktree target under docker-compose binds the resolver's container path" {
    _write_launch_environment docker-compose
    LINT_ENV="docker-compose"
    stub_worktree_probe pass
    resolve_env_workdir() { printf '%s\n' "/var/www/html/.claude/worktrees/in-root"; }

    run _resolve_and_report_workdir "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_success
    assert_output "/var/www/html/.claude/worktrees/in-root|/var/www/html/.claude/worktrees/in-root"
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
    assert_output --partial "the configuration file in force"
    assert_output --partial "does not parse as a JSON object"
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

# The launch configuration parses at server start, so this state needs someone
# to edit the file while the session runs — which is ordinary. Before the check
# covered the inherited config, the call went through and ran with the
# environment, the scopes and every per-tool setting reading as absent, which is
# the outcome the check exists to prevent.
@test "a worktree carrying no config of its own is refused for a launch config that stopped parsing" {
    printf '{"environment": "native"\n' > "${LAUNCH_ROOT}/.mcp-php-tooling.json"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_failure
    assert_output --partial "the configuration file in force"
    assert_output --partial "does not parse as a JSON object"
    assert_output --partial "${LAUNCH_ROOT}/.mcp-php-tooling.json"
}

# --- Fallback to the launch configuration ---

@test "a worktree carrying no config of its own falls back to the launch configuration" {
    printf '{"environment":"native","default_scope":"launch-marker","scopes":{"launch-marker":{"cwd":"x"}}}\n' \
        > "${LAUNCH_ROOT}/.mcp-php-tooling.json"

    worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"

    # The resolution result is the same one a worktree carrying its own config
    # produces, so the fallback is observed through the configuration the call
    # ends up holding. "launch-marker" exists only in the launch config written
    # above.
    run jq -r '.default_scope' "${WORKTREE_SELECTED_CONFIG_FILE}"
    assert_success
    assert_output "launch-marker"
}

# --- Temp-file ownership on a re-run of load_config ---

# Both roots carry two configs, so load_config merges at each into a temp file.
# The worktree call must delete its own merged temp and leave the launch one, and
# the consequence of getting that wrong is visible one call later: the launch
# config is gone, every read of it answers empty, and the next launch-root call
# runs unscoped at the project root reporting no error at all. That later call is
# what this asserts — the ownership variables are internal, and worktree.sh's own
# comments mark one of them as not the signal and the other's assignment as a
# no-op today.
#
# The worktree call runs in a subshell because the real dispatcher runs every
# tool call in one, and the EXIT trap that releases the owned temp is installed
# there. Reproducing that is the whole point: the deletion happens as the call
# ends, and the launch root has to survive it.
@test "a later launch-root call still resolves its scope after a worktree call merged and released its own config" {
    mkdir -p "${LAUNCH_ROOT}/.claude" "${WORKTREE_A}/.claude"
    printf '{"environment":"native"}\n' > "${LAUNCH_ROOT}/.mcp-php-tooling.json"
    printf '{"default_scope":"launch-scope","scopes":{"launch-scope":{"cwd":"custom/plugins/Launch"}}}\n' \
        > "${LAUNCH_ROOT}/.claude/.mcp-php-tooling.json"
    printf '{"environment":"native"}\n' > "${WORKTREE_A}/.mcp-php-tooling.json"
    printf '{"default_scope":"wt-scope","scopes":{"wt-scope":{"cwd":"custom/plugins/Worktree"}}}\n' \
        > "${WORKTREE_A}/.claude/.mcp-php-tooling.json"

    local script="${BATS_TEST_TMPDIR}/ownership.sh"
    cat > "${script}" <<HEADER
#!/usr/bin/env bash
set -uo pipefail
PLUGIN_DIR=$(printf '%q' "${PLUGIN_DIR}")
CONFIG_PREFIX="php-tooling"
log() { :; }
PROJECT_ROOT=$(printf '%q' "${LAUNCH_ROOT}")
export PROJECT_ROOT
WORKTREE_A=$(printf '%q' "${WORKTREE_A}")
HEADER

    cat >> "${script}" <<'BODY'
source "${PLUGIN_DIR}/shared/config.sh"
# The launch-time merge, in server.sh's own order: LINT_CONFIG_FILE becomes a
# temp file that no later call may delete.
load_config "${PROJECT_ROOT}"
source "${PLUGIN_DIR}/shared/environment.sh"
source "${PLUGIN_DIR}/shared/scope.sh"
LINT_ENV="native"
LINT_WORKDIR="${PROJECT_ROOT}"
source "${PLUGIN_DIR}/shared/worktree.sh"
worktree_state_init

( worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}" >/dev/null 2>&1 )

worktree_resolve_root '{}' >/dev/null 2>&1
resolve_scope ""
printf '%s|%s\n' "${SCOPE_NAME}" "${SCOPE_CWD}"
BODY

    run bash "${script}"
    assert_success
    assert_output "launch-scope|custom/plugins/Launch"
}

# The test above proves the release does not delete the WRONG file, and it holds
# whether or not the release runs at all: the launch configuration survives a
# missing trap untouched. So the deletion itself is asserted here — the merged
# file the worktree call ended up holding, checked once while the call is still
# in flight and once after its subshell has closed.
#
# The path is named exactly rather than counted out of a directory, so wherever
# mktemp places the merged file the observation still points at it, and no file
# another process left behind can be mistaken for it. TMPDIR is redirected into
# this test's own directory all the same: worktree_state_init writes its state
# file through an explicit TMPDIR template, and the script below has no cleanup
# that would remove it.
@test "the config a worktree call merged into is deleted once that call's subshell has ended" {
    mkdir -p "${LAUNCH_ROOT}/.claude" "${WORKTREE_A}/.claude"
    printf '{"environment":"native"}\n' > "${LAUNCH_ROOT}/.mcp-php-tooling.json"
    printf '{"default_scope":"launch-scope","scopes":{"launch-scope":{"cwd":"custom/plugins/Launch"}}}\n' \
        > "${LAUNCH_ROOT}/.claude/.mcp-php-tooling.json"
    printf '{"environment":"native"}\n' > "${WORKTREE_A}/.mcp-php-tooling.json"
    printf '{"default_scope":"wt-scope","scopes":{"wt-scope":{"cwd":"custom/plugins/Worktree"}}}\n' \
        > "${WORKTREE_A}/.claude/.mcp-php-tooling.json"

    local script="${BATS_TEST_TMPDIR}/release.sh"
    cat > "${script}" <<HEADER
#!/usr/bin/env bash
set -uo pipefail
TMPDIR=$(printf '%q' "${BATS_TEST_TMPDIR}/release-tmp")
export TMPDIR
mkdir -p "\${TMPDIR}"
PLUGIN_DIR=$(printf '%q' "${PLUGIN_DIR}")
CONFIG_PREFIX="php-tooling"
log() { :; }
PROJECT_ROOT=$(printf '%q' "${LAUNCH_ROOT}")
export PROJECT_ROOT
WORKTREE_A=$(printf '%q' "${WORKTREE_A}")
HEADER

    cat >> "${script}" <<'BODY'
source "${PLUGIN_DIR}/shared/config.sh"
# The launch-time merge, in server.sh's own order, so the configuration this
# call inherits is a temp file too and cannot be confused with the one below.
load_config "${PROJECT_ROOT}"
source "${PLUGIN_DIR}/shared/environment.sh"
source "${PLUGIN_DIR}/shared/scope.sh"
LINT_ENV="native"
LINT_WORKDIR="${PROJECT_ROOT}"
source "${PLUGIN_DIR}/shared/worktree.sh"
worktree_state_init

_exists() { ls -1d "$1" 2>/dev/null | wc -l | tr -d ' '; }

# The command substitution IS the subshell the call runs in — the handler
# dispatches every tool inside one, which is where worktree_resolve_root
# installs the EXIT trap that releases the merged file. Both values are produced
# inside it, on one line, because the trap fires as it closes.
in_call=$(
    worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}" >/dev/null 2>&1
    printf '%s|%s\n' "${WORKTREE_SELECTED_CONFIG_FILE}" "$(_exists "${WORKTREE_SELECTED_CONFIG_FILE}")"
)

printf 'in-flight=%s\n' "${in_call##*|}"
printf 'after-call=%s\n' "$(_exists "${in_call%%|*}")"
BODY

    run bash "${script}"
    assert_success
    # The precondition: the call really did merge into a file that existed while
    # it ran. A worktree carrying one config, or a refused resolution, leaves
    # this at 0 and the case fails as setup rather than passing on an absence.
    assert_line "in-flight=1"
    assert_line "after-call=0"
}

# set_project_root and cwd are the two tools worktree_resolve_root does not
# reach, and both create the same call-owned files — the merged configuration
# during validation, the derivation log after it. Unlike the resolver they
# release those files explicitly on every return path, so only a call that ends
# WITHOUT reaching that release can leave one behind: that is the cancellation
# the dispatch-subshell EXIT trap they install is for, and the call below is
# driven to end that way.
#
# The interruption is placed after validation, which is where the merged file
# exists and where the tool's own release has not run yet. The interposed
# function is a timing device and not the subject, so it reports what the call
# held; a refactor that removes the seam leaves "in-flight" absent and fails
# here rather than quietly turning this into a test of a call that released on
# its own. It reports into a file because the call it interrupts has its own
# stdout redirected.
@test "the config a set_project_root call merged into is deleted when the call ends without its own release" {
    mkdir -p "${LAUNCH_ROOT}/.claude" "${WORKTREE_A}/.claude"
    printf '{"environment":"native"}\n' > "${LAUNCH_ROOT}/.mcp-php-tooling.json"
    printf '{"default_scope":"launch-scope","scopes":{"launch-scope":{"cwd":"custom/plugins/Launch"}}}\n' \
        > "${LAUNCH_ROOT}/.claude/.mcp-php-tooling.json"
    printf '{"environment":"native"}\n' > "${WORKTREE_A}/.mcp-php-tooling.json"
    printf '{"default_scope":"wt-scope","scopes":{"wt-scope":{"cwd":"custom/plugins/Worktree"}}}\n' \
        > "${WORKTREE_A}/.claude/.mcp-php-tooling.json"

    local script="${BATS_TEST_TMPDIR}/setter-release.sh"
    cat > "${script}" <<HEADER
#!/usr/bin/env bash
set -uo pipefail
TMPDIR=$(printf '%q' "${BATS_TEST_TMPDIR}/setter-release-tmp")
export TMPDIR
mkdir -p "\${TMPDIR}"
PLUGIN_DIR=$(printf '%q' "${PLUGIN_DIR}")
CONFIG_PREFIX="php-tooling"
log() { :; }
PROJECT_ROOT=$(printf '%q' "${LAUNCH_ROOT}")
export PROJECT_ROOT
WORKTREE_A=$(printf '%q' "${WORKTREE_A}")
HEADER

    cat >> "${script}" <<'BODY'
source "${PLUGIN_DIR}/shared/config.sh"
# The launch-time merge, in server.sh's own order, so the configuration this
# call inherits is a temp file too and cannot be mistaken for the call's own.
load_config "${PROJECT_ROOT}"
source "${PLUGIN_DIR}/shared/environment.sh"
source "${PLUGIN_DIR}/shared/scope.sh"
LINT_ENV="native"
LINT_WORKDIR="${PROJECT_ROOT}"
source "${PLUGIN_DIR}/shared/worktree.sh"
worktree_state_init

_exists() { ls -1d "$1" 2>/dev/null | wc -l | tr -d ' '; }
REPORT_FILE="${TMPDIR}/setter-report"
: > "${REPORT_FILE}"

# The command substitution IS the subshell the handler dispatches a tool call
# in, so it is where the trap under test fires. The interposed function records
# what the call held, then ends that subshell the way a cancellation does —
# after validation has merged the configuration and before the tool's own
# release runs. The `|| true` keeps the substitution's status from ending this
# script: SHELLOPTS reaches it with errexit set, so an unhandled 143 would stop
# the run before anything below is observed.
captured=$(
    _worktree_bind_call_environment() {
        {
            printf 'merged=%s\n' "${WORKTREE_SELECTED_CONFIG_FILE}"
            printf 'in-flight=%s\n' "$(_exists "${WORKTREE_SELECTED_CONFIG_FILE}")"
        } > "${REPORT_FILE}"
        exit 143
    }
    tool_set_project_root "{\"project_root\":\"${WORKTREE_A}\"}" >/dev/null 2>&1
    printf 'released-by-the-call\n'
) || true

cat "${REPORT_FILE}"
merged=$(sed -n 's/^merged=//p' "${REPORT_FILE}")
printf 'after-call=%s\n' "$(_exists "${merged}")"
printf 'call-returned=%s\n' "${captured}"
BODY

    run bash "${script}"
    assert_success
    # in-flight=1 is the precondition: the call really did merge into a file
    # that existed while it ran. Without it a refused resolution leaves
    # after-call=0 and the case would pass on an absence.
    assert_line "in-flight=1"
    # Empty because the substituted shell ended at the interruption instead of
    # reaching the line after the call — the state the trap is there for.
    assert_line "call-returned="
    assert_line "after-call=0"
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

# --- Path guard: a relative path may not climb out of the worktree ---
#
# The guard cannot resolve a relative path to check containment: the storefront
# tools accept three spellings of one file and only their own routing tells them
# apart, and the tree-relative spelling does not exist under the effective root
# at all. It refuses the ".." segment instead, so both sides of that decision
# are asserted — the escapes it must catch, and the documented spellings it must
# still admit.

_enter_worktree_a_unscoped() {
    if ! worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"; then
        fail "worktree_resolve_root did not resolve the worktree root"
    fi
    if ! resolve_scope ""; then
        fail "resolve_scope did not resolve the unscoped call"
    fi
}

_assert_relative_refused() {
    run worktree_assert_paths_within_root "[\"$1\"]"
    assert_failure
    assert_output --partial "climb out of the tree"
    assert_output --partial "$1"
}

_assert_relative_admitted() {
    run worktree_assert_paths_within_root "[\"$1\"]"
    assert_success
    assert_output ""
}

@test "worktree_assert_paths_within_root refuses a relative path that climbs out of the worktree" {
    _enter_worktree_a_unscoped
    _assert_relative_refused "../../../src/Core"
}

@test "worktree_assert_paths_within_root refuses an interior .. segment" {
    _enter_worktree_a_unscoped
    _assert_relative_refused "src/../../escape/File.php"
}

@test "worktree_assert_paths_within_root refuses a trailing .. segment" {
    _enter_worktree_a_unscoped
    _assert_relative_refused "src/.."
}

@test "worktree_assert_paths_within_root refuses a bare .. path" {
    _enter_worktree_a_unscoped
    _assert_relative_refused ".."
}

@test "worktree_assert_paths_within_root admits a repo-root-relative path" {
    _enter_worktree_a_unscoped
    _assert_relative_admitted "src/Storefront/Resources/views/components/Example.js"
}

@test "worktree_assert_paths_within_root admits a tree-relative path that does not exist under the root" {
    _enter_worktree_a_unscoped
    _assert_relative_admitted "views/components/Example.js"
}

@test "worktree_assert_paths_within_root admits a filename whose basename begins with dots" {
    _enter_worktree_a_unscoped
    _assert_relative_admitted "src/..gitignore"
}

# --- Gitdir linkage classification ---
#
# The classifier is the unit; _worktree_gitdir_linkage is the file read in
# front of it. Every class is asserted here because the resolution path cannot
# produce all three: a ".git" file git itself cannot parse is refused one step
# earlier, so "invalid" is reachable only through the unit.

_assert_gitdir_classified() {
    run _worktree_classify_gitdir "$1"
    assert_success
    assert_output "$2"
}

@test "the gitdir classifier reads a rooted pointer as absolute" {
    _assert_gitdir_classified 'gitdir: /var/lib/repo/.git/worktrees/wt' absolute
}

@test "the gitdir classifier reads a parent-relative pointer as relative" {
    _assert_gitdir_classified 'gitdir: ../repo/.git/worktrees/wt' relative
}

@test "the gitdir classifier reads a dot-relative pointer as relative" {
    _assert_gitdir_classified 'gitdir: ./repo/.git/worktrees/wt' relative
}

@test "the gitdir classifier reads a bare relative pointer as relative" {
    _assert_gitdir_classified 'gitdir: repo/.git/worktrees/wt' relative
}

@test "the gitdir classifier refuses a line carrying no gitdir prefix" {
    _assert_gitdir_classified 'worktree: /var/lib/repo/.git/worktrees/wt' invalid
}

@test "the gitdir classifier refuses a gitdir prefix followed by nothing" {
    _assert_gitdir_classified 'gitdir: ' invalid
}

@test "the gitdir classifier refuses an empty file" {
    _assert_gitdir_classified '' invalid
}

@test "the gitdir classifier refuses a pointer carrying a line break" {
    _assert_gitdir_classified $'gitdir: /a\nb' invalid
}

# --- An absolutely linked worktree is refused everywhere ---
#
# Enumerated at runtime, because the verdict does not vary with the
# environment: which environment a call runs under is a property of a
# configuration file, not of the pointer, so a root accepted natively today is
# reached through a container the moment one is configured.

_ALL_ENVS=(native docker docker-compose vagrant ddev)

# Rewrite a worktree's ".git" file so its pointer is the absolute per-worktree
# directory, which is what `git worktree add` writes unless the repository sets
# worktree.useRelativePaths.
_worktree_gitdir_absolute() {
    local wt="$1"
    local target
    target=$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR \
        git -C "${wt}" rev-parse --absolute-git-dir)
    printf 'gitdir: %s\n' "${target}" > "${wt}/.git"
}

@test "an absolutely linked worktree is refused under every environment, naming the remediation" {
    _worktree_gitdir_absolute "${WORKTREE_A}"

    local environment
    for environment in "${_ALL_ENVS[@]}"; do
        _write_launch_environment "${environment}"
        LINT_ENV="${environment}"

        run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
        assert_failure
        assert_output --partial "carries an absolute gitdir pointer"
        assert_output --partial "git -c worktree.useRelativePaths=true worktree repair \"${WORKTREE_A}\""
    done

    # Restore the fixture for any later test in this file.
    worktree_gitdir_relative "${WORKTREE_A}"
}

# --- Charset refusals ---

# A worktree created inside the launch root whose directory name carries the
# given characters. A branch name cannot carry them, so it is sanitized — and
# because that sanitization maps several characters onto the same letter, a
# caller creating more than one in a single test passes a distinct suffix.
# Args: $1 = the directory name, $2 = optional discriminator for the branch name
_make_in_root_worktree() {
    local name="$1"
    local discriminator="${2:-}"
    local path="${LAUNCH_ROOT}/.claude/worktrees/${name}"
    mkdir -p "$(dirname "${path}")"
    git -C "${LAUNCH_ROOT}" worktree add -q "${path}" -b "wt-${name//[!a-zA-Z0-9]/x}${discriminator}branch"
    worktree_gitdir_relative "${path}"
    printf '%s\n' "${path}"
}

@test "a worktree root carrying a single quote is refused under every environment" {
    local hostile
    hostile=$(_make_in_root_worktree "it's")

    local environment
    for environment in "${_ALL_ENVS[@]}"; do
        _write_launch_environment "${environment}"
        LINT_ENV="${environment}"

        run _resolve_and_report "{\"project_root\":\"${hostile}\"}"
        assert_failure
        assert_output --partial "contains a single quote"
    done
}

# One row per failure class a root can realistically carry: whitespace, which
# ends the directory name where the value is unquoted, and the two metacharacter
# shapes that matter — one that separates commands, one that substitutes. The
# whole set is covered by the shared-environment suite, which reads
# SHELL_HOSTILE_METACHARS rather than restating it, so this table does not grow
# a row per character.
# shellcheck disable=SC2016  # the third name really does contain a dollar sign; shellcheck reads the whole assignment as one statement
_ROOT_CHARSET_CASES=(
    'a b'
    'a;b'
    'a$b'
)

@test "a worktree root carrying a character a container command cannot carry is refused under every container environment" {
    local index name hostile
    for index in "${!_ROOT_CHARSET_CASES[@]}"; do
        name="${_ROOT_CHARSET_CASES[${index}]}"
        hostile=$(_make_in_root_worktree "${name}" "${index}")
        _assert_root_charset_refused "${hostile}"
    done
}

_assert_root_charset_refused() {
    local root="$1"
    local environment
    for environment in "${_CONTAINER_ENVS[@]}"; do
        _write_launch_environment "${environment}"
        LINT_ENV="${environment}"

        run _resolve_and_report "{\"project_root\":\"${root}\"}"
        assert_failure
        # One sentence for all four, so the refusal does not depend on which
        # environment happened to be configured.
        assert_output --partial "the \"${environment}\" environment sends this path into the container as part of the working directory"
    done
}

@test "a worktree root carrying whitespace or a metacharacter is admitted under native" {
    local accepted
    accepted=$(_make_in_root_worktree 'a b')

    _write_launch_environment native
    LINT_ENV="native"

    # Native's wrapper emits no cd and therefore no directory at all, so the
    # value reaches no shell and there is nothing for the character to break.
    run _resolve_and_report "{\"project_root\":\"${accepted}\"}"
    assert_success
    assert_output "${accepted}|call"
}

@test "the refusal names the character that cannot be carried" {
    local hostile
    hostile=$(_make_in_root_worktree 'a;b')

    _write_launch_environment docker
    LINT_ENV="docker"

    run _resolve_and_report "{\"project_root\":\"${hostile}\"}"
    assert_failure
    assert_output --partial "acts on the character \\; it carries"
}

# --- Mid-session edits of the launch configuration ---

# The launch configuration is read once, when the server starts, and the
# environment every check is keyed on comes from that reading. A test that only
# rewrote the file would model a server that re-reads it per call, which is the
# state these two cover; so the file is written with the startup content first
# and then edited to another environment, while LINT_ENV keeps the value the
# server bound.
#
# The consequence of getting this wrong is measured: validation reads the edited
# file, finds native, skips containment, the charset rule and the probe, and the
# command then runs under the startup docker binding the wrappers are still keyed
# on. Validation and execution answering for different environments is the whole
# of the defect.
_edit_launch_config_to_native() {
    printf '{"environment":"docker","docker":{"workdir":"/srv/app","container":"shopware_app"}}\n' \
        > "${LAUNCH_ROOT}/.mcp-php-tooling.json"
    LINT_ENV="docker"

    printf '{"environment":"native"}\n' > "${LAUNCH_ROOT}/.mcp-php-tooling.json"
}

@test "an edit of the launch config to native still refuses an out-of-root worktree" {
    _edit_launch_config_to_native

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_A}\"}"
    assert_failure
    assert_output --partial "the \"docker\" environment runs commands inside a container"
}

@test "an edit of the launch config to native still probes the worktree it maps" {
    _edit_launch_config_to_native

    run _resolve_and_report_workdir "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_failure
    assert_output --partial "the \"docker\" environment does not reach"
}

# The mapping base is the third thing the launch config binds at startup, beside
# the environment and the container name, and it is inert to a mid-session edit
# for the same reason: _set_workdir_from_config assigned it when the server
# started, and the mapping reads that scalar rather than the file. Reading
# `.docker.workdir` afresh here would move where a running server's
# worktree-targeted commands run while a launch-root call kept running under the
# workdir the server started with — the same class of defect as the environment
# edit above, one layer further out.
#
# Distinct from the test above, which edits the environment: this one leaves the
# environment alone and moves only the workdir.
@test "an edit of the launch workdir does not move where a worktree call maps" {
    _write_launch_environment docker
    LINT_ENV="docker"
    stub_worktree_probe pass

    # The edit: same environment, different workdir.
    printf '{"environment":"docker","docker":{"workdir":"/srv/edited"}}\n' \
        > "${LAUNCH_ROOT}/.mcp-php-tooling.json"

    run _resolve_and_report_workdir "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_success
    assert_output "/srv/app/.claude/worktrees/in-root|/srv/app/.claude/worktrees/in-root"
}

# The spelling the wrappers embed is the CANONICAL one, not the one the caller
# typed: validation resolves the root, and the resolved path is what the mapping
# and every wrapper string carry. A root reached through a symlink therefore
# passes a charset check run on the caller's spelling while the metacharacter
# travels into the command. The pair is in-root on both sides, so containment
# and the git linkage tests accept it and the charset check is the only step
# between the call and the wrapper.
@test "a worktree reached through a clean-named symlink is refused for a metacharacter in its canonical spelling" {
    local real_root="${LAUNCH_ROOT}/.claude/worktrees/real;dir"
    mkdir -p "$(dirname "${real_root}")"
    git -C "${LAUNCH_ROOT}" worktree add -q "${real_root}" -b wt-canonical-branch
    worktree_gitdir_relative "${real_root}"

    local clean_link="${LAUNCH_ROOT}/.claude/worktrees/clean"
    ln -s "real;dir" "${clean_link}"

    # The resolved spelling, which is what the refusal names: on macOS a
    # "/var/..." path resolves under "/private/var/...", and the point of the
    # assertion is that the message carries the path the shell is handed rather
    # than the clean one the caller typed.
    local canonical_real
    canonical_real=$(cd "${real_root}" && pwd -P)

    _write_launch_environment docker
    LINT_ENV="docker"
    stub_worktree_probe pass

    run _resolve_and_report "{\"project_root\":\"${clean_link}\"}"
    assert_failure
    assert_output --partial "\"${canonical_real}\""
    assert_output --partial 'the character \; it carries'
}

# --- Environment re-derivation from the worktree's own configuration ---

@test "a worktree whose own configuration declares another environment runs under it" {
    printf '{"environment":"docker","docker":{"workdir":"/srv/wt","container":"app"}}\n' \
        > "${WORKTREE_IN_ROOT}/.mcp-php-tooling.json"
    _write_launch_environment native
    LINT_ENV="native"
    stub_worktree_probe pass

    run _resolve_and_report_binding "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_success
    assert_output "docker|/srv/wt/.claude/worktrees/in-root|/srv/wt/.claude/worktrees/in-root"
}

@test "a worktree whose own configuration declares native binds the host root" {
    printf '{"environment":"native"}\n' > "${WORKTREE_IN_ROOT}/.mcp-php-tooling.json"
    _write_launch_environment docker
    LINT_ENV="docker"

    run _resolve_and_report_binding "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_success
    assert_output "native|${WORKTREE_IN_ROOT}|"
}

@test "a worktree configuration whose docker arm names no container is refused, naming the file and the field" {
    printf '{"environment":"docker","docker":{"workdir":"/srv/wt"}}\n' \
        > "${WORKTREE_IN_ROOT}/.mcp-php-tooling.json"
    _write_launch_environment native
    LINT_ENV="native"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_failure
    assert_output --partial "${WORKTREE_IN_ROOT}/.mcp-php-tooling.json"
    assert_output --partial ".docker.container"
}

@test "a worktree configuration declaring no environment is refused, naming the file and the field" {
    printf '{"default_scope":"shopware"}\n' > "${WORKTREE_IN_ROOT}/.mcp-php-tooling.json"
    _write_launch_environment native
    LINT_ENV="native"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_failure
    assert_output --partial "${WORKTREE_IN_ROOT}/.mcp-php-tooling.json"
    assert_output --partial "\"environment\" field"
}

# --- The existence probe ---

@test "the probe refuses a call whose mapped root the environment does not reach" {
    _write_launch_environment docker
    LINT_ENV="docker"
    stub_worktree_probe fail

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_failure
    assert_output --partial "does not reach \"/srv/app/.claude/worktrees/in-root\""
    assert_output --partial "the \"docker\" environment"
}

@test "the probe is not run for a native call, whose mapped root is the host root" {
    # The suite-wide guard from setup records every probe attempt, so the
    # assertion is the shared helper rather than a hand-rolled recording stub.
    _write_launch_environment native
    LINT_ENV="native"

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_success

    if worktree_test_probe_was_attempted; then
        fail "the probe was attempted for a native call"
    fi
}

@test "a later call for the same environment and root reads the recorded probe instead of probing again" {
    _write_launch_environment docker
    LINT_ENV="docker"
    stub_worktree_probe pass

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_success
    run _resolve_and_report "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_success

    run cat "${WORKTREE_TEST_PROBE_LOG}"
    assert_success
    assert_output --partial "test -d"
    assert_equal "$(wc -l < "${WORKTREE_TEST_PROBE_LOG}" | tr -d ' ')" "1"
}

@test "an edited mapped path probes again instead of reusing the pass recorded for the old mapping" {
    # The worktree's own config is re-read per call, so its workdir can change
    # between two calls while the (environment, root) pair stays identical. A
    # cache keyed on that pair alone answers for a path nothing ever probed.
    _write_launch_environment native
    LINT_ENV="native"
    printf '{"environment":"docker","docker":{"workdir":"/srv/a","container":"c"}}\n' > "${WORKTREE_IN_ROOT}/.mcp-php-tooling.json"
    stub_worktree_probe pass

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_success

    printf '{"environment":"docker","docker":{"workdir":"/srv/b","container":"c"}}\n' > "${WORKTREE_IN_ROOT}/.mcp-php-tooling.json"
    run _resolve_and_report "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_success

    run cat "${WORKTREE_TEST_PROBE_LOG}"
    assert_success
    assert_line --index 0 --partial "/srv/a/.claude/worktrees/in-root"
    assert_line --index 1 --partial "/srv/b/.claude/worktrees/in-root"
}

@test "a failing probe is not recorded, so the next call probes again" {
    _write_launch_environment docker
    LINT_ENV="docker"
    stub_worktree_probe fail

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_failure

    run jq -r '.probe_cache // "absent"' "${DEV_TOOLING_STATE_FILE}"
    assert_success
    assert_output "absent"
}

# --- The path guard's boundary is host-side under a container environment ---

@test "the path guard measures host paths against the host root under a container environment" {
    _write_launch_environment docker
    LINT_ENV="docker"
    stub_worktree_probe pass

    if ! worktree_resolve_root "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"; then
        fail "worktree_resolve_root did not resolve the in-root worktree"
    fi
    if ! resolve_scope ""; then
        fail "resolve_scope did not resolve the unscoped call"
    fi

    run worktree_assert_paths_within_root "[\"${WORKTREE_IN_ROOT}/src/File.php\"]"
    assert_success
    assert_output ""
}

@test "the path guard refuses a host path outside the worktree under a container environment" {
    _write_launch_environment docker
    LINT_ENV="docker"
    stub_worktree_probe pass

    if ! worktree_resolve_root "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"; then
        fail "worktree_resolve_root did not resolve the in-root worktree"
    fi
    if ! resolve_scope ""; then
        fail "resolve_scope did not resolve the unscoped call"
    fi

    run worktree_assert_paths_within_root "[\"${WORKTREE_A}/src/File.php\"]"
    assert_failure
    assert_output --partial "resolve outside"
    # The boundary named is the host root, not the container path the command
    # runs in, and the message states the mapping between the two.
    assert_output --partial "${WORKTREE_IN_ROOT}"
}

# --- set_project_root validates what it commits ---
#
# The sticky value outlives the call that writes it, so a set that succeeds and
# then refuses on every later call is the one failure a session cannot see: the
# tool reported success and the next call names a reason the set never showed.
# Every check a per-call root goes through therefore runs here too.

@test "set_project_root refuses a root every later call would refuse, naming the same reason" {
    printf '{"environment":"docker","docker":{"workdir":"/srv/app"}}\n' \
        > "${WORKTREE_IN_ROOT}/.mcp-php-tooling.json"
    _write_launch_environment native
    LINT_ENV="native"

    # The per-call refusal, captured first so the set can be asserted to give
    # the same one rather than merely to fail.
    run _resolve_and_report "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_failure
    assert_output --partial ".docker.container"

    run tool_set_project_root "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_failure
    assert_output --partial ".docker.container"

    run _worktree_state_read_sticky
    assert_success
    assert_output ""
}

@test "set_project_root refuses a root its environment cannot reach, naming the mapped path" {
    _write_launch_environment docker
    LINT_ENV="docker"
    stub_worktree_probe fail

    run _resolve_and_report "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_failure
    assert_output --partial "does not reach \"/srv/app/.claude/worktrees/in-root\""

    run tool_set_project_root "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_failure
    assert_output --partial "does not reach \"/srv/app/.claude/worktrees/in-root\""

    run _worktree_state_read_sticky
    assert_success
    assert_output ""
}

@test "set_project_root records the probe result a later call then reads instead of probing again" {
    _write_launch_environment docker
    LINT_ENV="docker"
    stub_worktree_probe pass

    run tool_set_project_root "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_success

    # Reading here rather than only at the end is what separates "the set probed
    # and cached" from "the set probed nothing and the call that followed probed
    # once" — both leave one line behind them.
    assert_equal "$(wc -l < "${WORKTREE_TEST_PROBE_LOG}" | tr -d ' ')" "1"

    run worktree_resolve_root "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_success

    assert_equal "$(wc -l < "${WORKTREE_TEST_PROBE_LOG}" | tr -d ' ')" "1"
}

# --- tool_cwd reports what a call would actually do ---
#
# This tool is the session's only way to see the resolution state, so a line it
# prints has to be true of a call. Both refusals below run after validation in
# worktree_resolve_root and are absent from validation itself, so a report built
# on validation alone claims a root resolves that no call would accept.

@test "cwd does not report a root as resolving when its configuration names no environment" {
    # The sticky root is set while the worktree's configuration still declares
    # an environment: _worktree_validate_root does not read that field, and it
    # is the only thing tool_set_project_root runs. The file is rewritten
    # afterwards, which is the state a session reaches by editing a worktree's
    # config, or by a worktree whose config was already in that shape and was
    # never stuck through this tool.
    printf '{"environment":"native"}\n' > "${WORKTREE_IN_ROOT}/.mcp-php-tooling.json"
    _write_launch_environment native
    LINT_ENV="native"

    run tool_set_project_root "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_success

    printf '{"default_scope":"shopware"}\n' > "${WORKTREE_IN_ROOT}/.mcp-php-tooling.json"

    # A call refuses this root, because worktree_resolve_root asks for the
    # field the configuration does not carry. The report has to say so rather
    # than print a working directory no call would ever use.
    run _resolve_and_report "{\"project_root\":\"${WORKTREE_IN_ROOT}\"}"
    assert_failure
    assert_output --partial "\"environment\" field"

    run tool_cwd '{}'
    assert_success
    assert_output --partial "Effective project root resolves: no"
    assert_output --partial "\"environment\" field"
}

@test "cwd reports a worktree whose own compose configuration applies its own workdir" {
    printf '{"environment":"docker-compose","docker-compose":{"workdir":"/worktree/base"}}\n' \
        > "${WORKTREE_IN_ROOT}/.mcp-php-tooling.json"
    printf '{"environment":"docker-compose","docker-compose":{"workdir":"/launch/base"}}\n' \
        > "${LAUNCH_ROOT}/.mcp-php-tooling.json"
    LINT_ENV="docker-compose"
    # The launch configuration is what the process started with, and the
    # worktree's own file is what a call re-derives from — which is the
    # distinction the reported working directory has to respect.
    WORKTREE_LAUNCH_CONFIG_FILE="${LAUNCH_ROOT}/.mcp-php-tooling.json"

    # The sticky value is written directly rather than through
    # tool_set_project_root: that tool now probes, and this environment's probe
    # reaches the compose CLI. What this test is about is the line cwd prints,
    # so the state it needs is arranged without running a container command.
    run _worktree_state_write_sticky "${WORKTREE_IN_ROOT}"
    assert_success

    run tool_cwd '{}'
    assert_success
    assert_output --partial "Effective project root: ${WORKTREE_IN_ROOT} (sticky)"
    assert_output --partial "Working directory, no scope applied: /worktree/base"
    refute_output --partial "/launch/base"
}

# --- Banner contents for each source ---

@test "the banner names the call root and the call source" {
    worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"

    run worktree_root_banner
    assert_success
    assert_output "Project root: ${WORKTREE_A} (call)"
}

