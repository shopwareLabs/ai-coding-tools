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
    _wrap_resolver_with_trap_restore
    _restore_bats_exit_trap
}

_restore_bats_exit_trap() {
    eval "${BATS_EXIT_TRAP:-trap - EXIT}"
}

# worktree_resolve_root installs its own EXIT trap for the call-owned temp file.
# In a tool dispatch that trap belongs to the dispatch subshell, but a test that
# calls the resolver WITHOUT `run` gets it installed in this process, where it
# displaces bats' trap a second time — and then a later failing assertion in
# that test produces no "not ok" line at all, only "Executed N instead of
# expected M", naming no test.
#
# Restoring the trap at each call site would work and would be forgotten: the
# next test added to this file has to know a rule nothing enforces. So the
# restore is moved into the resolver itself, under its own name, for the
# lifetime of this process. Tests call worktree_resolve_root as they would
# anywhere, and there is nothing left to remember.
#
# Only this process is affected. The generated scripts below run in their own
# bash processes and source shared/worktree.sh fresh, so they get the real
# function and the real trap, which is what makes them a faithful model of a
# tool dispatch.
_wrap_resolver_with_trap_restore() {
    eval "_worktree_resolve_root_real() $(declare -f worktree_resolve_root | tail -n +2)"
    worktree_resolve_root() {
        local rc=0
        _worktree_resolve_root_real "$@" || rc=$?
        # Restored only in the test process itself. `run` resolves in a subshell
        # where the resolver's trap dies on its own, and installing bats' trap
        # there makes it fire a second time as that subshell ends — one test then
        # emits two result lines and the file reports more tests than it has.
        if [[ "${BASHPID}" == "$$" ]]; then
            _restore_bats_exit_trap
        fi
        return "${rc}"
    }
}

teardown() {
    # The cleanups the displaced traps would have run at exit. Both are guarded
    # against an empty variable, so calling them here is safe whether or not the
    # test reached the code that arms them.
    declare -F config_cleanup >/dev/null && config_cleanup
    declare -F worktree_release_owned_temp >/dev/null && worktree_release_owned_temp
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

# --- Banner contents for each source ---

@test "the banner names the call root and the call source" {
    worktree_resolve_root "{\"project_root\":\"${WORKTREE_A}\"}"

    run worktree_root_banner
    assert_success
    assert_output "Project root: ${WORKTREE_A} (call)"
}

