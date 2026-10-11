#!/bin/bash
# Test fixtures for dev-tooling hook script testing

# Load shared core helper
load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

# Path to dev-tooling hook scripts
SCRIPTS_DIR="${REPO_ROOT}/plugins/dev-tooling/hooks/scripts"

# Create temporary MCP config file
setup_config() {
    local prefix="$1"
    local content="$2"
    export CLAUDE_PROJECT_DIR="${BATS_TEST_TMPDIR}"
    echo "$content" > "${BATS_TEST_TMPDIR}/.mcp-${prefix}.json"
}

# Default setup - override CONFIG_PREFIX in test file
setup() {
    setup_config "${CONFIG_PREFIX:-php-tooling}" '{"environment": "native"}'
}

teardown() {
    unset CLAUDE_PROJECT_DIR
}

# Run a PreToolUse hook script with the hook input's cwd set. Codex sets no
# CLAUDE_PROJECT_DIR, so the cwd is how it names the project.
# Args: $1 = script name, $2 = bash command, $3 = cwd
run_hook_with_cwd() {
    local payload
    payload=$(jq -cn --arg cmd "$2" --arg cwd "$3" '{tool_input: {command: $cmd}, cwd: $cwd}')
    run bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload" "${SCRIPTS_DIR}/$1"
}

# Create a project directory holding an MCP config of the given environment,
# distinct from the one setup_config writes at BATS_TEST_TMPDIR.
# Args: $1 = config prefix, $2 = environment
# Stdout: the project directory
make_cwd_project() {
    local dir="${BATS_TEST_TMPDIR}/cwd-project"
    mkdir -p "$dir"
    jq -n --arg env "$2" '{environment: $env}' > "${dir}/.mcp-${1}.json"
    printf '%s\n' "$dir"
}

# The path $2 relative to the directory $1. Both must be absolute and
# canonical. No external tool computes this portably — BSD realpath has no
# --relative-to — and the fixtures below have both sides already.
# Args: $1 = the directory the result is relative to, $2 = the target path
# Stdout: the relative path
_absolute_path_relative_to() {
    local from="${1%/}" to="$2"
    local -a from_parts=() to_parts=()
    local IFS='/'
    read -r -a from_parts <<< "${from}"
    read -r -a to_parts <<< "${to}"

    local i=0
    while [[ "${i}" -lt "${#from_parts[@]}" && "${i}" -lt "${#to_parts[@]}" \
             && "${from_parts[${i}]}" == "${to_parts[${i}]}" ]]; do
        i=$((i + 1))
    done

    local -a result=()
    local j
    for (( j = i; j < ${#from_parts[@]}; j++ )); do
        result+=("..")
    done
    for (( j = i; j < ${#to_parts[@]}; j++ )); do
        result+=("${to_parts[${j}]}")
    done

    printf '%s\n' "${result[*]}"
}

# Rewrite the linked worktree at $1 to RELATIVE linkage on BOTH sides — the
# ".git" file's "gitdir" pointer and the per-worktree directory's "gitdir"
# back-pointer — which is the state `git worktree add --relative-paths` and
# `git -c worktree.useRelativePaths=true worktree repair` produce. Rewriting
# only the ".git" file leaves a mixed state no git 2.48+ relink produces, and
# the back-pointer resolution defect that refused every real relative-linkage
# worktree passed against exactly that mixed state.
#
# `git worktree add` writes absolute linkage unless the repository sets
# worktree.useRelativePaths, a key git 2.48 introduced. Delegating to that key
# would make these fixtures depend on the host git's version and default —
# measured: git 2.55.0 with no such key writes an absolute pointer — and the
# repository's own CI does not pin a git new enough to honor it. The pointers
# written here are the ones git resolves identically: both sides are canonical,
# so each relative form reaches the same directory as the absolute one it
# replaces.
# Args: $1 = the worktree root
worktree_gitdir_relative() {
    local wt="$1"
    local canonical target relative
    canonical=$(cd "${wt}" && pwd -P)
    target=$(< "${wt}/.git")
    target="${target#gitdir: }"
    target="${target%$'\n'}"

    # The pointer a host's git wrote is not known in advance — a git with
    # worktree.useRelativePaths set, or one new enough to default it, writes the
    # relative form already, and feeding that relative form to the relative-path
    # computation below would produce a pointer to a directory nobody named. It
    # is resolved against the worktree root first, so the absolute form is what
    # this always starts from.
    if [[ "${target}" != /* ]]; then
        target=$(cd "${wt}/${target}" && pwd -P)
    fi

    relative=$(_absolute_path_relative_to "${canonical}" "${target}")
    printf 'gitdir: %s\n' "${relative}" > "${wt}/.git"

    # The back-pointer is relative to the per-worktree directory that holds it.
    local back_relative
    back_relative=$(_absolute_path_relative_to "${target}" "${canonical}/.git")
    printf '%s\n' "${back_relative}" > "${target}/gitdir"
}

# Refuse the existence probe rather than let it run, and record that it was
# attempted. Install this in setup of every suite that can reach the probe, so
# a container CLI is unreachable by construction rather than by every test
# remembering to stub one.
#
# Without it a test that resolves a worktree under a container environment
# without stubbing `exec_command` runs the real wrapper, and under
# docker-compose that means `docker compose ps` on the host. It passes on a
# machine with no docker — the command-not-found is swallowed by the wrapper and
# the refusal happens to read like a verdict — and behaves differently on one
# that has it, which is the worst shape for a suite whose subject is not the
# probe at all.
#
# A test that means to exercise the probe calls stub_worktree_probe instead.
# Globals: sets WORKTREE_TEST_PROBE_LOG; the file counts attempts
worktree_test_guard_probe() {
    WORKTREE_TEST_PROBE_LOG="${BATS_TEST_TMPDIR}/probe-attempts"
    : > "${WORKTREE_TEST_PROBE_LOG}"
    exec_command() {
        if [[ "${1}" == "test -d "* ]]; then
            printf '%s\n' "${1}" >> "${WORKTREE_TEST_PROBE_LOG}"
            return 1
        fi
        printf '%s\n' "${1}"
    }
}

# True when something reached the probe without an explicit verdict — the
# condition worktree_test_guard_probe exists to make visible. A suite asserts it
# after a call that should not have probed.
# Returns: 0 when the probe was attempted, 1 when it was not
worktree_test_probe_was_attempted() {
    [[ -s "${WORKTREE_TEST_PROBE_LOG:-}" ]]
}

# Replace exec_command with a stub that answers worktree_enter's existence
# probe and nothing else. Under a container environment that probe would reach
# a container CLI, which no suite here may execute; the answer it gives is the
# argument, so a suite drives the probe's verdict without an environment.
#
# The verdict is stored in a global rather than captured as a local of this
# function: exec_command is called from inside a command substitution, a
# subshell that inherits the caller's globals but not a local of a function
# that has already returned. A local is unbound there, which under `set -u`
# takes the probe down with a message about the variable instead of a verdict.
#
# Every attempt is appended to WORKTREE_TEST_PROBE_LOG, the same file the
# guard writes, so a test asserting how often — or against which mapped path —
# the probe ran reads the log instead of hand-rolling its own recording stub.
# Args: $1 = "pass" or "fail"
# Globals: sets WORKTREE_PROBE_STUB_VERDICT and WORKTREE_TEST_PROBE_LOG
stub_worktree_probe() {
    WORKTREE_PROBE_STUB_VERDICT="$1"
    WORKTREE_TEST_PROBE_LOG="${BATS_TEST_TMPDIR}/probe-attempts"
    : > "${WORKTREE_TEST_PROBE_LOG}"
    exec_command() {
        if [[ "${1}" == "test -d "* ]]; then
            printf '%s\n' "${1}" >> "${WORKTREE_TEST_PROBE_LOG}"
            [[ "${WORKTREE_PROBE_STUB_VERDICT}" == "pass" ]]
            return
        fi
        printf '%s\n' "${1}"
    }
}

# Shared setup for PHP MCP tool tests.
# Sets LINT_ENV, LINT_WORKDIR, LINT_CONFIG_FILE, stubs log/exec_command,
# sources environment.sh, then sources the given tool library.
# Args: $1=PLUGIN_DIR path, $2=library path to source
setup_php_mcp_env() {
    local plugin_dir="$1" lib_path="$2"
    echo '{"environment":"native"}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    log() { :; }
    source "${plugin_dir}/shared/environment.sh"
    source "${plugin_dir}/shared/scope.sh"
    # Set AFTER sourcing environment.sh: its module-level initializers ("")
    # clobber these otherwise.
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    export PROJECT_ROOT
    # shellcheck source=/dev/null  # plugin_dir is caller-supplied at runtime
    source "${plugin_dir}/shared/worktree.sh"
    worktree_state_init
    exec_command() { echo "$1"; }
    # shellcheck source=/dev/null  # lib_path is caller-supplied at runtime; each test passes a different tool library
    source "${lib_path}"
}

# Answer an `npm pkg get "scripts.<name>"` probe the way npm answers it against
# the Shopware package.json whose "scripts" block the fixture copies verbatim
# from shopware/shopware trunk (c59a7d3484c): the body as a JSON string, or
# `{}` for a script the package does not define.
# Args: $1 = package, "administration" or "storefront", $2 = script name
# Stdout: the probe answer
shopware_trunk_script_body() {
    jq --arg name "$2" 'if has($name) then .[$name] else {} end' \
        "${BATS_TEST_DIRNAME}/fixtures/shopware-trunk/$1-package-scripts.json"
}

# Executes one command a JS tool built the way exec_npm_command does:
# wrap_npm_command wraps it for the environment, and the result is evaluated
# from the package directory get_js_workdir names under LINT_WORKDIR set to
# BATS_TEST_TMPDIR. docker, vagrant and ddev are functions doing what each does
# with its argv: docker and vagrant hand their string to a shell; `ddev npm`
# passes argv unchanged (its command file sets ExecRaw); `ddev exec -d` joins
# argv, double-quoting an argument holding a space, tab, line break, `"` or
# `#`, and parses the result with `bash -c` again. Under docker-compose the real
# compose module builds the wrapper, with only its prerequisite check and its
# container and workdir resolvers, which query docker compose, replaced. npm is
# a script implementing the two `npm exec` forms as npm 11 runs them: `-c` hands
# the string to sh with the package's node_modules/.bin first on PATH, `--`
# runs that directory's binary. Each binary named in JS_FAKE_BINARIES (default:
# eslint, stylelint and prettier) is installed in the package's node_modules/.bin
# and prints its working directory, one bracketed line per argument, and, for
# an argument holding `*`, one `match:` line per file the pattern names, as
# bash expands it with globstar from that directory.
# Globals: reads JS_CONTEXT, PLUGIN_DIR, JS_FAKE_BINARIES
# Args: $1 = native, docker, docker-compose, vagrant, ddev or ddev-worktree,
#       $2 = the command
js_execute_in_env() {
    local env="$1" cmd="$2"

    # environment.sh resets LINT_WORKDIR when sourced; a tool call rebinds it
    # through worktree_enter, and this helper calls no tool.
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    local package_dir
    package_dir=$(get_js_workdir)
    local bin_dir="${BATS_TEST_TMPDIR}/fake-bin"
    mkdir -p "${package_dir}/node_modules/.bin" "${bin_dir}"
    cat > "${bin_dir}/npm" <<'NPM'
#!/usr/bin/env bash
[[ "$1 $2" == "exec --no" ]] || exit 90
case "$3" in
    -c) PATH="${PWD}/node_modules/.bin:${PATH}" exec sh -c "$4" ;;
    --) shift 3; bin="$1"; shift; exec "${PWD}/node_modules/.bin/${bin}" "$@" ;;
esac
exit 91
NPM
    chmod +x "${bin_dir}/npm"

    local binary
    for binary in ${JS_FAKE_BINARIES-eslint stylelint prettier}; do
        cat > "${package_dir}/node_modules/.bin/${binary}" <<'LINTER'
#!/usr/bin/env bash
shopt -s globstar nullglob
printf 'cwd=%s\n' "$(pwd)"
for arg in "$@"; do printf '[%s]\n' "${arg}"; done
for arg in "$@"; do
    [[ "${arg}" == *"*"* ]] || continue
    eval "matches=( ${arg} )"
    for match in "${matches[@]}"; do printf 'match:%s\n' "${match}"; done
done
LINTER
        chmod +x "${package_dir}/node_modules/.bin/${binary}"
    done

    docker() { bash -c "${!#}"; }
    vagrant() { bash -c "$3"; }
    ddev() {
        if [[ "$1" == "npm" ]]; then
            shift
            npm "$@"
            return
        fi
        [[ "$1 $2" == "exec -d" ]] || return 92
        local dir="$3" joined="" arg
        shift 3
        for arg in "$@"; do
            if [[ "${arg}" == *[\"\ $'\t'$'\r'$'\n'\#]* ]]; then
                arg="\"${arg//\"/\\\"}\""
            fi
            joined="${joined:+${joined} }${arg}"
        done
        bash -c "cd \"${dir}\" && ( ${joined} )"
    }

    LINT_ENV="${env}"
    if [[ "${env}" == "docker-compose" ]]; then
        # PLUGIN_DIR is set by the test file that loads this helper.
        # shellcheck source=/dev/null disable=SC2153
        source "${PLUGIN_DIR}/shared/docker-compose.sh"
        _compose_check_prerequisites() { return 0; }
        _compose_resolve_container() { printf '%s\n' "shopware-web-1"; }
        _compose_resolve_workdir() { printf '%s\n' "${BATS_TEST_TMPDIR}"; }
    fi
    if [[ "${env}" == "ddev-worktree" ]]; then
        LINT_ENV="ddev"
        WORKTREE_EFFECTIVE_ROOT="${BATS_TEST_TMPDIR}/linked-worktree"
    fi
    DOCKER_CONTAINER="web"
    local wrapped
    wrapped=$(wrap_npm_command "${cmd}")
    PATH="${bin_dir}:${PATH}"
    cd "${package_dir}" || return 93
    eval "${wrapped}"
}
