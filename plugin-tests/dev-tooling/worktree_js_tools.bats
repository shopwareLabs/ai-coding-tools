#!/usr/bin/env bats
# bats file_tags=dev-tooling,worktree,js
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
    printf '{"environment":"native"}\n' > "${LAUNCH_ROOT}/.mcp-js-tooling.json"

    WORKTREE_ROOT="${BATS_TEST_TMPDIR}/wt"
    git -C "${LAUNCH_ROOT}" worktree add -q "${WORKTREE_ROOT}" -b wt-branch
    worktree_gitdir_relative "${WORKTREE_ROOT}"
    mkdir -p "${WORKTREE_ROOT}/src/Administration/Resources/app/administration/node_modules"
    mkdir -p "${WORKTREE_ROOT}/src/Storefront/Resources/app/storefront/node_modules"
}

setup() {
    _make_git_worktree_fixture
}

teardown() {
    unset LAUNCH_ROOT WORKTREE_ROOT
}

# Sources one server's shared modules and lib files fresh in an isolated
# process, calls the given tool with project_root set to WORKTREE_ROOT, and
# captures the shell's cwd at the moment the (stubbed) command would run — the
# same signal scope_php_tools.bats uses for SCOPE_CWD, applied to the cd
# worktree_resolve_root performs. A generated script file rather than an
# inline `bash -c` string: %q-quoting every substituted value keeps the
# argument JSON's embedded quotes from having to survive a second shell layer.
# Args: $1 = js_context (admin|storefront), $2 = server dir name,
#       $3 = tool function name, $4 = tool arguments JSON, $@ = lib file names
_run_js_tool() {
    local js_context="$1" server_dir="$2" tool_fn="$3" json_args="$4"
    shift 4
    local script="${BATS_TEST_TMPDIR}/run-tool-${BATS_TEST_NUMBER}.sh"
    local calls_file="${BATS_TEST_TMPDIR}/calls-${BATS_TEST_NUMBER}.log"

    # Header: every value here is substituted NOW, from this outer shell's own
    # variables — the unquoted heredoc delimiter is what makes that happen.
    cat > "${script}" <<HEADER
#!/usr/bin/env bash
set -euo pipefail
PLUGIN_DIR=$(printf '%q' "${PLUGIN_DIR}")
CONFIG_PREFIX="js-tooling"
JS_CONTEXT=$(printf '%q' "${js_context}")
CALLS_FILE=$(printf '%q' "${calls_file}")
log() { :; }
source "\${PLUGIN_DIR}/shared/config.sh"
source "\${PLUGIN_DIR}/shared/environment.sh"
source "\${PLUGIN_DIR}/shared/scope.sh"
PROJECT_ROOT=$(printf '%q' "${LAUNCH_ROOT}")
export PROJECT_ROOT
LINT_CONFIG_FILE=$(printf '%q' "${LAUNCH_ROOT}/.mcp-js-tooling.json")
LINT_ENV="native"
LINT_WORKDIR="\${PROJECT_ROOT}"
source "\${PLUGIN_DIR}/shared/worktree.sh"
worktree_state_init
trap worktree_state_cleanup EXIT
HEADER

    # Body: nothing here should expand until the generated script runs, so the
    # heredoc delimiter is quoted and every "$" reaches the child script as-is.
    # Logs cwd+command to a file rather than returning it, so a script-body
    # probe (`npm pkg get "scripts.X"`) still gets a value it can parse.
    # Both stubs log LINT_WORKDIR (and exec_npm_command additionally logs
    # get_js_workdir(), the real function every actual npm command's working
    # directory is derived from) alongside the shell's own cwd — a regression
    # that keeps the resolver's `cd` but drops the LINT_WORKDIR rebind would
    # otherwise still pass on the cwd signal alone.
    cat >> "${script}" <<'BODY'
exec_npm_command() {
    local jswd
    jswd=$(get_js_workdir)
    printf '[cwd=%s][workdir=%s][jsworkdir=%s] %s\n' "$(pwd)" "${LINT_WORKDIR}" "${jswd}" "$1" >> "${CALLS_FILE}"
    case "$1" in
        'npm pkg get "scripts.'*) printf '"a-script"\n' ;;
        *) printf '%s\n' "$1" ;;
    esac
}
exec_command() { printf '[cwd=%s][workdir=%s] %s\n' "$(pwd)" "${LINT_WORKDIR}" "$1" >> "${CALLS_FILE}"; printf '%s\n' "$1"; }
BODY

    local lib
    for lib in "$@"; do
        printf 'source "%s/%s/lib/%s"\n' "${PLUGIN_DIR}" "${server_dir}" "${lib}" >> "${script}"
    done
    printf '%s %q > /dev/null\n' "${tool_fn}" "${json_args}" >> "${script}"
    # shellcheck disable=SC2016  # ${CALLS_FILE} must expand in the generated script when it runs, not here
    printf 'cat -- "${CALLS_FILE}"\n' >> "${script}"

    run bash "${script}"
}

# Every tool on both JS servers is already covered per tool by
# worktree_conformance.bats for the [cwd][workdir] pair. The cases here stay
# because they additionally pin [jsworkdir] — the directory get_js_workdir()
# derives for the npm invocation itself out of LINT_WORKDIR and JS_CONTEXT —
# which the conformance scan does not capture. The two ludtwig cases asserted
# the [cwd][workdir] pair alone and were cut as duplicates of that scan.

# --- Admin ---

# worktree_prepare exists for exactly the state every other tool refuses, so
# both prepare cases delete node_modules first: a regression that reintroduces
# the dependency gate into the tool would refuse the call, and the conformance
# scan would not catch that because its fixture worktree carries node_modules.
@test "admin worktree_prepare: runs npm ci in the package directory of a worktree with no node_modules" {
    rm -rf "${WORKTREE_ROOT}/src/Administration/Resources/app/administration/node_modules"
    _run_js_tool admin mcp-server-js-admin tool_worktree_prepare \
        "{\"project_root\":\"${WORKTREE_ROOT}\"}" prepare.sh
    assert_success
    assert_output --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}][jsworkdir=${WORKTREE_ROOT}/src/Administration/Resources/app/administration] npm ci"
    # The success summary is not assertable here: _run_js_tool discards the
    # tool's stdout and prints only the calls log. worktree_php_tools.bats pins
    # the summary-on-success / full-output-on-failure contract.
}

@test "storefront worktree_prepare: runs npm ci in the package directory of a worktree with no node_modules" {
    rm -rf "${WORKTREE_ROOT}/src/Storefront/Resources/app/storefront/node_modules"
    _run_js_tool storefront mcp-server-js-storefront tool_worktree_prepare \
        "{\"project_root\":\"${WORKTREE_ROOT}\"}" prepare.sh
    assert_success
    assert_output --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}][jsworkdir=${WORKTREE_ROOT}/src/Storefront/Resources/app/storefront] npm ci"
    # The success summary is not assertable here: _run_js_tool discards the
    # tool's stdout and prints only the calls log. worktree_php_tools.bats pins
    # the summary-on-success / full-output-on-failure contract.
}

@test "admin lint_all: a project_root argument reaches the resolved working directory" {
    _run_js_tool admin mcp-server-js-admin tool_lint_all \
        "{\"project_root\":\"${WORKTREE_ROOT}\"}" lint-all.sh
    assert_success
    assert_output --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}][jsworkdir=${WORKTREE_ROOT}/src/Administration/Resources/app/administration]"
}

@test "admin lint_twig: a project_root argument reaches the resolved working directory" {
    _run_js_tool admin mcp-server-js-admin tool_lint_twig \
        "{\"project_root\":\"${WORKTREE_ROOT}\"}" lint-all.sh
    assert_success
    assert_output --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}][jsworkdir=${WORKTREE_ROOT}/src/Administration/Resources/app/administration]"
}

@test "admin unit_setup: a project_root argument reaches the resolved working directory" {
    _run_js_tool admin mcp-server-js-admin tool_unit_setup \
        "{\"project_root\":\"${WORKTREE_ROOT}\"}" lint-all.sh
    assert_success
    assert_output --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}][jsworkdir=${WORKTREE_ROOT}/src/Administration/Resources/app/administration]"
}

@test "admin vite_build: a project_root argument reaches the resolved working directory" {
    _run_js_tool admin mcp-server-js-admin tool_vite_build \
        "{\"project_root\":\"${WORKTREE_ROOT}\"}" build.sh
    assert_success
    assert_output --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}][jsworkdir=${WORKTREE_ROOT}/src/Administration/Resources/app/administration]"
}

# --- Storefront ---

@test "storefront webpack_build: a project_root argument reaches the resolved working directory" {
    _run_js_tool storefront mcp-server-js-storefront tool_webpack_build \
        "{\"project_root\":\"${WORKTREE_ROOT}\"}" build.sh
    assert_success
    assert_output --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}][jsworkdir=${WORKTREE_ROOT}/src/Storefront/Resources/app/storefront]"
}

# --- eslint_check, one per server ---

@test "admin eslint_check: a project_root argument reaches the resolved working directory" {
    _run_js_tool admin mcp-server-js-admin tool_eslint_check \
        "{\"project_root\":\"${WORKTREE_ROOT}\"}" eslint.sh
    assert_success
    assert_output --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}][jsworkdir=${WORKTREE_ROOT}/src/Administration/Resources/app/administration]"
}

@test "storefront eslint_check: a project_root argument reaches the resolved working directory" {
    _run_js_tool storefront mcp-server-js-storefront tool_eslint_check \
        "{\"project_root\":\"${WORKTREE_ROOT}\"}" eslint.sh
    assert_success
    assert_output --partial "[cwd=${WORKTREE_ROOT}][workdir=${WORKTREE_ROOT}][jsworkdir=${WORKTREE_ROOT}/src/Storefront/Resources/app/storefront]"
}
