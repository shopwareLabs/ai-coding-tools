#!/usr/bin/env bats
# bats file_tags=dev-tooling,worktree,conformance
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
    printf '{"environment":"native"}\n' > "${LAUNCH_ROOT}/.mcp-js-tooling.json"
    mkdir -p "${LAUNCH_ROOT}/vendor"
    printf '' > "${LAUNCH_ROOT}/vendor/autoload.php"

    WORKTREE_ROOT="${BATS_TEST_TMPDIR}/wt"
    git -C "${LAUNCH_ROOT}" worktree add -q "${WORKTREE_ROOT}" -b wt-branch
    mkdir -p "${WORKTREE_ROOT}/vendor"
    printf '' > "${WORKTREE_ROOT}/vendor/autoload.php"
    mkdir -p "${WORKTREE_ROOT}/src/Administration/Resources/app/administration/node_modules"
    mkdir -p "${WORKTREE_ROOT}/src/Storefront/Resources/app/storefront/node_modules"

    # Not a worktree of the launch root, for the refusal pass.
    OUTSIDE_ROOT="${BATS_TEST_TMPDIR}/outside"
    mkdir -p "${OUTSIDE_ROOT}"
}

setup() {
    _make_git_worktree_fixture
}

teardown() {
    unset LAUNCH_ROOT WORKTREE_ROOT OUTSIDE_ROOT
}

# Generates a script that sources one server whole, then calls every tool_*
# function defined in that process — `compgen -A function tool_` builds the
# enumeration from the live function set, so a tool added later is covered
# without being told to — with the given project_root, and reports where each
# one ended up.
#
# The signal is the working directory the tool's command would have run in.
# This file is the per-tool positive coverage for that signal on all three
# servers; worktree_php_tools.bats and worktree_js_tools.bats keep only what is
# not scanned here (a failed clover read, and the derived npm working
# directory). Nothing here names worktree_enter or any other function inside the resolution
# path: hoisting the resolution into the dispatcher, renaming it, or splitting
# it keeps this suite passing as long as the command still runs in the directory
# the caller asked for.
#
# Args: $1 = server dir name, $2 = JS_CONTEXT value or empty for PHP,
#       $3 = the project_root to pass, $4 = "positive" or "negative"
_scan_server_tools() {
    local server_dir="$1" js_context="$2" project_root="$3" mode="$4"
    local script="${BATS_TEST_TMPDIR}/scan-${BATS_TEST_NUMBER}.sh"
    local calls_file="${BATS_TEST_TMPDIR}/scan-calls-${BATS_TEST_NUMBER}.log"
    local config_prefix="php-tooling"
    local js_context_line=""
    if [[ -n "${js_context}" ]]; then
        config_prefix="js-tooling"
        js_context_line="JS_CONTEXT=$(printf '%q' "${js_context}")"
    fi

    cat > "${script}" <<HEADER
#!/usr/bin/env bash
set -uo pipefail
PLUGIN_DIR=$(printf '%q' "${PLUGIN_DIR}")
CONFIG_PREFIX="${config_prefix}"
${js_context_line}
CALLS_FILE=$(printf '%q' "${calls_file}")
TARGET_ROOT=$(printf '%q' "${project_root}")
SCAN_MODE=$(printf '%q' "${mode}")
EXEMPT_TOOLS="tool_set_project_root tool_cwd"
TOOLS_JSON="\${PLUGIN_DIR}/${server_dir}/tools.json"
log() { :; }
source "\${PLUGIN_DIR}/shared/config.sh"
source "\${PLUGIN_DIR}/shared/environment.sh"
source "\${PLUGIN_DIR}/shared/scope.sh"
PROJECT_ROOT=$(printf '%q' "${LAUNCH_ROOT}")
export PROJECT_ROOT
LINT_CONFIG_FILE=$(printf '%q' "${LAUNCH_ROOT}/.mcp-${config_prefix}.json")
LINT_ENV="native"
LINT_WORKDIR="\${PROJECT_ROOT}"
source "\${PLUGIN_DIR}/shared/worktree.sh"
worktree_state_init
trap worktree_state_cleanup EXIT
# A lib that fails to source would otherwise drop its tools from the
# enumeration below and leave every remaining tool reporting OK, so the scan
# stops here instead of shrinking silently.
for f in "\${PLUGIN_DIR}/${server_dir}"/lib/*.sh; do
    # shellcheck disable=SC1090
    if ! source "\${f}"; then
        printf 'LIB-SOURCE-FAILED %s\n' "\${f}"
        exit 1
    fi
done
HEADER

    cat >> "${script}" <<'BODY'
# Both wrappers log the shell's own cwd and LINT_WORKDIR: a regression that
# keeps the resolver's cd but drops the LINT_WORKDIR rebind passes on cwd alone.
exec_command() {
    printf '[cwd=%s][workdir=%s]\n' "$(pwd)" "${LINT_WORKDIR}" >> "${CALLS_FILE}"
    printf '%s\n' "$1"
}
exec_npm_command() {
    printf '[cwd=%s][workdir=%s]\n' "$(pwd)" "${LINT_WORKDIR}" >> "${CALLS_FILE}"
    case "$1" in
        'npm pkg get "scripts.'*) printf '"a-script"\n' ;;
        *) printf '%s\n' "$1" ;;
    esac
}

# Parameters a tool refuses to run without. Only "command" qualifies today; the
# rest of the surface takes project_root alone. A tool added with a new required
# parameter and no entry here reports NO-COMMAND, which is a failure that names
# the tool rather than a silent pass.
declare -A TOOL_EXTRA_ARGS=(
    [tool_console_run]=',"command":"cache:clear"'
)

# The enumeration is itself asserted, because every marker below is a name
# anchor: a scan that never saw a tool is otherwise indistinguishable from one
# where that tool passed. tools.json is the server's own declaration of what it
# exposes, so reconciling against it keeps a tool added later covered without
# this file being edited — the property the compgen enumeration exists for.
exempt_re="^($(printf '%s' "${EXEMPT_TOOLS}" | tr ' ' '|'))$"
declared_file="${CALLS_FILE}.declared"
defined_file="${CALLS_FILE}.defined"
jq -r '.tools[].name' "${TOOLS_JSON}" | sed 's/^/tool_/' | grep -Ev "${exempt_re}" | sort -u > "${declared_file}"
compgen -A function tool_ | grep -Ev "${exempt_re}" | sort -u > "${defined_file}"

enumeration_rc=0
while read -r declared_only; do
    printf 'MISSING-TOOL %s\n' "${declared_only}"
    enumeration_rc=1
done < <(comm -23 "${declared_file}" "${defined_file}")
while read -r defined_only; do
    printf 'UNDECLARED-TOOL %s\n' "${defined_only}"
    enumeration_rc=1
done < <(comm -13 "${declared_file}" "${defined_file}")
if [[ "${enumeration_rc}" -ne 0 ]]; then
    exit 1
fi

for fn in $(compgen -A function tool_); do
    case " ${EXEMPT_TOOLS} " in
        *" ${fn} "*) continue ;;
    esac

    args="{\"project_root\":\"${TARGET_ROOT}\"${TOOL_EXTRA_ARGS[${fn}]:-}}"
    : > "${CALLS_FILE}"
    rc=0
    ( "${fn}" "${args}" >/dev/null 2>&1 ) || rc=$?

    if [[ "${SCAN_MODE}" == "negative" ]]; then
        if [[ -s "${CALLS_FILE}" ]]; then
            printf 'RAN-ANYWAY %s\n' "${fn}"
        elif [[ "${rc}" -eq 0 ]]; then
            printf 'SILENT-PASS %s\n' "${fn}"
        else
            printf 'REFUSED %s\n' "${fn}"
        fi
        continue
    fi

    if [[ ! -s "${CALLS_FILE}" ]]; then
        printf 'NO-COMMAND %s\n' "${fn}"
    elif [[ "$(head -n 1 -- "${CALLS_FILE}")" != "[cwd=${TARGET_ROOT}][workdir=${TARGET_ROOT}]" ]]; then
        printf 'WRONG-DIRECTORY %s %s\n' "${fn}" "$(head -n 1 -- "${CALLS_FILE}")"
    else
        printf 'OK %s\n' "${fn}"
    fi
done
BODY

    run bash "${script}"
}

# --- Every tool runs its command in the worktree the caller named ---

@test "every php-tooling tool_* function except the two exemptions runs in the named worktree" {
    _scan_server_tools mcp-server-php "" "${WORKTREE_ROOT}" positive
    assert_success
    refute_output --partial "MISSING-TOOL"
    refute_output --partial "UNDECLARED-TOOL"
    refute_output --partial "NO-COMMAND"
    refute_output --partial "WRONG-DIRECTORY"
    assert_output --partial "OK tool_phpstan_analyze"
    assert_output --partial "OK tool_phpunit_coverage_gaps"
    assert_output --partial "OK tool_console_run"
}

@test "every js-admin-tooling tool_* function except the two exemptions runs in the named worktree" {
    _scan_server_tools mcp-server-js-admin admin "${WORKTREE_ROOT}" positive
    assert_success
    refute_output --partial "MISSING-TOOL"
    refute_output --partial "UNDECLARED-TOOL"
    refute_output --partial "NO-COMMAND"
    refute_output --partial "WRONG-DIRECTORY"
    assert_output --partial "OK tool_lint_all"
    assert_output --partial "OK tool_lint_twig"
    assert_output --partial "OK tool_unit_setup"
    assert_output --partial "OK tool_vite_build"
}

@test "every js-storefront-tooling tool_* function except the two exemptions runs in the named worktree" {
    _scan_server_tools mcp-server-js-storefront storefront "${WORKTREE_ROOT}" positive
    assert_success
    refute_output --partial "MISSING-TOOL"
    refute_output --partial "UNDECLARED-TOOL"
    refute_output --partial "NO-COMMAND"
    refute_output --partial "WRONG-DIRECTORY"
    assert_output --partial "OK tool_webpack_build"
    assert_output --partial "OK tool_ludtwig_check"
    assert_output --partial "OK tool_ludtwig_fix"
}

# --- Every tool stops when the named root is refused ---
#
# Reaching the resolver is not the same as obeying it. A tool that resolves and
# then runs anyway executes against the launch root while the caller asked for a
# directory the resolver rejected, and the banner attributes the result to the
# directory that was refused.

@test "every php-tooling tool_* function except the two exemptions runs no command against a refused root" {
    _scan_server_tools mcp-server-php "" "${OUTSIDE_ROOT}" negative
    assert_success
    refute_output --partial "MISSING-TOOL"
    refute_output --partial "UNDECLARED-TOOL"
    refute_output --partial "RAN-ANYWAY"
    refute_output --partial "SILENT-PASS"
    assert_output --partial "REFUSED tool_phpstan_analyze"
}

@test "every js-admin-tooling tool_* function except the two exemptions runs no command against a refused root" {
    _scan_server_tools mcp-server-js-admin admin "${OUTSIDE_ROOT}" negative
    assert_success
    refute_output --partial "MISSING-TOOL"
    refute_output --partial "UNDECLARED-TOOL"
    refute_output --partial "RAN-ANYWAY"
    refute_output --partial "SILENT-PASS"
    assert_output --partial "REFUSED tool_lint_all"
}

@test "every js-storefront-tooling tool_* function except the two exemptions runs no command against a refused root" {
    _scan_server_tools mcp-server-js-storefront storefront "${OUTSIDE_ROOT}" negative
    assert_success
    refute_output --partial "MISSING-TOOL"
    refute_output --partial "UNDECLARED-TOOL"
    refute_output --partial "RAN-ANYWAY"
    refute_output --partial "SILENT-PASS"
    assert_output --partial "REFUSED tool_ludtwig_check"
}
