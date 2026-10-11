#!/usr/bin/env bash
# Prettier tool implementation for Admin Tooling MCP Server
# Provides prettier_check and prettier_fix MCP tools
#
# Two routes, selected by whether the caller supplied paths:
#   paths supplied -> the package's own Prettier binary through
#                     `npm exec --no -- prettier`, with the flags of the
#                     aggregate body ("--check", or "--write --cache") but none
#                     of its globs, so the caller's paths are the ONLY targets.
#                     A directory path is narrowed to its .js, .ts and .mjs
#                     files, the extensions those globs name.
#   paths omitted  -> the aggregate script ("format" / "format:fix"), whose
#                     body carries both the mode flag and its own glob
#                     targets, which stay authoritative.
# The aggregate is never a fallback for a path-scoped run. npm appends `--`
# arguments to the END of the whole script body, so appending a path to a body
# that already names `src/**/*.{js,ts}` and friends widens the run to those
# globs PLUS the path — it can never narrow it. That matters most for
# prettier_fix, which writes: a widened fix reformats files nobody named.

ADMIN_PRETTIER_BINARY="prettier"
# Extensions Prettier is pointed at here, read off the globs in the `format`
# and `format:fix` script bodies: `{js,ts}` and `ts` under src, test, scripts
# and build, `extension-tooling/**/*.mjs`, build/plugins.vite.ts and build.ts.
# A path that resolves to no file with one of them formats nothing and still
# exits 0.
ADMIN_PRETTIER_EXTENSIONS="js ts mjs"
# What a directory path is narrowed to: the extensions above, below it.
ADMIN_PRETTIER_DIRECTORY_GLOB="**/*.{js,ts,mjs}"

# True when the path is a glob pattern Prettier expands itself rather than a
# literal filesystem path. The existence probe cannot resolve a glob, so glob
# entries skip the guard.
# Args: $1 = caller-supplied path
if ! declare -F _prettier_admin_path_is_glob >/dev/null; then
    _prettier_admin_path_is_glob() {
        case "$1" in
            *"*"*|*"?"*|*"["*) return 0 ;;
        esac
        return 1
    }
fi

# Print, one per line, the caller's literal paths that name directories. A
# literal path without an accepted extension has passed the lintable probe only
# as a directory holding such a file. One carrying an accepted extension can
# still be a directory, so those are tested where the command runs, through
# `npm exec -c` like the binary probe.
# Args: $1.. = literal paths that passed the lintable probe
# Stdout: the directories, or the failure message
# Returns: 0 on success, 1 when the test could not run
_prettier_admin_directories() {
    local -a extensions=()
    read -r -a extensions <<< "${ADMIN_PRETTIER_EXTENSIONS}"

    local -a directories=()
    local p ext named script=""
    for p in "$@"; do
        named=0
        for ext in "${extensions[@]}"; do
            [[ "${p}" == *".${ext}" ]] && named=1
        done
        if [[ "${named}" -eq 0 ]]; then
            directories+=("${p}")
        else
            script="${script}[ -d $(shell_quote_arg "${p}") ] && echo DIRECTORY:$(shell_quote_arg "${p}"); "
        fi
    done

    if [[ -n "${script}" ]]; then
        local output
        local probe_code=0
        output=$(exec_npm_command "npm exec --no -c $(shell_quote_arg "${script}true")") || probe_code=$?
        if [[ "${probe_code}" -ne 0 ]]; then
            printf '%s\n' "Refusing to run with paths: could not check which of them are directories; the probe exited with ${probe_code}.${output:+ Probe output: ${output}}"
            return 1
        fi
        local line
        while IFS= read -r line; do
            [[ "${line}" == DIRECTORY:* ]] && directories+=("${line#DIRECTORY:}")
        done <<< "${output}"
    fi

    if [[ ${#directories[@]} -gt 0 ]]; then
        printf '%s\n' "${directories[@]}"
    fi
}

# The target a directory reaches Prettier as. Prettier given a directory
# formats every file type it supports under it, so a directory becomes a glob
# limited to the accepted extensions, which Prettier expands itself because the
# caller's quoting keeps it away from the shell.
# Args: $1 = directory path
# Stdout: the pattern
_prettier_admin_directory_pattern() {
    local path="$1"

    while [[ "${path}" == */ && "${path}" != "/" ]]; do
        path="${path%/}"
    done
    printf '%s\n' "${path}/${ADMIN_PRETTIER_DIRECTORY_GLOB}"
}

# Under ddev on a worktree the command reaches `ddev exec`, which re-parses it
# in the container's bash without quoting a value that holds no space, quote
# or "#", so that bash would expand a glob pattern itself, without globstar,
# before Prettier sees it. A run there takes file paths only.
# Args: $1 = tool name, $2.. = the caller's glob patterns and directories
# Stdout: the refusal
# Returns: 0 when no such path is given or the call runs elsewhere, 1 otherwise
_prettier_admin_assert_no_pattern_under_ddev_worktree() {
    local tool_name="$1"
    shift

    if [[ $# -eq 0 || "${LINT_ENV:-}" != "ddev" ]] || ! _env_targets_worktree; then
        return 0
    fi

    printf '%s\n' "Refusing to run ${tool_name} with paths: under ddev on a worktree these paths would reach Prettier as glob patterns the container shell expands first: $*. Pass file paths instead."
    return 1
}

# Refuse a path-scoped run when the package's own Prettier binary is not
# installed where the command runs. `npm exec --no` never installs, but on a
# miss it still runs a globally installed binary of the same name, so the probe
# runs first and the run never reaches a binary the package did not pin.
# Args: $1 = tool name, $2 = aggregate npm script, named in the refusal
# Stdout: the refusal, when the binary is missing
# Returns: 0 when node_modules/.bin/prettier is executable, 1 otherwise
_prettier_admin_assert_local_binary() {
    local tool_name="$1"
    local aggregate="$2"
    local bin_path="node_modules/.bin/${ADMIN_PRETTIER_BINARY}"

    # On a miss the probe prints a marker and the directory it ran in, which
    # under a container environment is the container's path, and exits 3; any
    # other non-zero exit is the probe itself failing.
    local probe="test -x ${bin_path} || { echo LOCAL_BINARY_MISSING_IN; pwd; exit 3; }"
    local output
    local probe_code=0
    output=$(exec_npm_command "npm exec --no -c $(shell_quote_arg "${probe}")") || probe_code=$?
    if [[ "${probe_code}" -eq 0 ]]; then
        return 0
    fi

    if [[ "${probe_code}" -eq 3 && "${output}" == *LOCAL_BINARY_MISSING_IN$'\n'* ]]; then
        local package_dir="${output##*LOCAL_BINARY_MISSING_IN$'\n'}"
        package_dir="${package_dir%%$'\n'*}"
        printf '%s\n' "Refusing to run ${tool_name} with paths: \"${bin_path}\" is not installed in the package directory \"${package_dir}\". A path-scoped run executes only the package's own ${ADMIN_PRETTIER_BINARY} binary: it installs none and uses no global one, and the aggregate \"${aggregate}\" script is not a substitute, because its own glob targets would widen the run. Run \`npm ci\` in that directory, or call worktree_prepare on this server for a worktree."
        return 1
    fi

    printf '%s\n' "Refusing to run ${tool_name} with paths: could not check whether the package's own ${ADMIN_PRETTIER_BINARY} binary is installed; the probe exited with ${probe_code}.${output:+ Probe output: ${output}}"
    return 1
}

# Run one Prettier invocation for this tool.
# Args: $1 = aggregate npm script used when no paths are supplied,
#       $2 = tool name, for the refusal message,
#       $3 = flags for the path-scoped route: the aggregate body's flags
#            without its globs ("--check", or "--write --cache"),
#       $4 = tool arguments JSON
# Stdout: Prettier output, or the failure message
_prettier_dispatch_admin() {
    local aggregate="$1"
    local tool_name="$2"
    local mode_flags="$3"
    local args="$4"

    local scoped_config
    scoped_config=$(scope_get_tool_field prettier config)

    local paths_json paths
    paths_json=$(echo "${args}" | jq -c '.paths // []')
    if ! paths=$(parse_paths_json "${paths_json}" ""); then
        printf '%s\n' "${paths}"
        return 1
    fi

    worktree_assert_paths_within_root "${paths_json}" || return 1

    local body
    local gate_code=0

    if [[ -z "${paths}" ]]; then
        # No paths: unchanged from before this routing existed — the aggregate
        # script runs bare, and the scoped config override is the only thing
        # ever appended to it.
        local aggregate_cmd="npm run ${aggregate}"

        if [[ -n "${scoped_config}" ]]; then
            body=$(npm_script_append_gate "${aggregate}") || gate_code=$?
            if [[ "${gate_code}" -ne 0 ]]; then
                printf '%s\n' "${body}"
                return 1
            fi
            aggregate_cmd="${aggregate_cmd} -- --config ${scoped_config}"
        fi

        log "INFO" "Running Prettier (admin, ${aggregate}): ${aggregate_cmd}"
        exec_npm_command "${aggregate_cmd}"
        return
    fi

    local -a supplied=()
    local -a literals=()
    local p
    while IFS= read -r p; do
        [[ -z "${p}" ]] && continue
        supplied+=("${p}")
        if ! _prettier_admin_path_is_glob "${p}"; then
            literals+=("${p}")
        fi
    done < <(printf '%s\n' "${paths_json}" | jq -r '.[]')

    _prettier_admin_assert_local_binary "${tool_name}" "${aggregate}" || return 1

    if [[ ${#literals[@]} -gt 0 ]]; then
        local missing_report
        if ! missing_report=$(assert_paths_lintable "." "${ADMIN_PRETTIER_EXTENSIONS}" "${literals[@]}"); then
            printf '%s\n' "${missing_report}"
            return 1
        fi
    fi

    local -a directories=()
    if [[ ${#literals[@]} -gt 0 ]]; then
        local directory_report
        if ! directory_report=$(_prettier_admin_directories "${literals[@]}"); then
            printf '%s\n' "${directory_report}"
            return 1
        fi
        while IFS= read -r p; do
            [[ -n "${p}" ]] && directories+=("${p}")
        done <<< "${directory_report}"
    fi

    local -a patterns=()
    for p in "${supplied[@]}"; do
        _prettier_admin_path_is_glob "${p}" && patterns+=("${p}")
    done
    _prettier_admin_assert_no_pattern_under_ddev_worktree "${tool_name}" \
        "${patterns[@]+"${patterns[@]}"}" "${directories[@]+"${directories[@]}"}" || return 1

    local -a quoted=()
    local target directory
    for p in "${supplied[@]}"; do
        target="${p}"
        for directory in "${directories[@]+"${directories[@]}"}"; do
            if [[ "${directory}" == "${p}" ]]; then
                target=$(_prettier_admin_directory_pattern "${p}")
                break
            fi
        done
        quoted+=("$(shell_quote_arg "${target}")")
    done

    local cmd="npm exec --no -- ${ADMIN_PRETTIER_BINARY} ${mode_flags}"
    if [[ -n "${scoped_config}" ]]; then
        cmd="${cmd} --config ${scoped_config}"
    fi
    cmd="${cmd} ${quoted[*]}"

    log "INFO" "Running Prettier (admin, npm exec): ${cmd}"

    exec_npm_command "${cmd}"
}

# Prettier check (dry-run)
# Args: JSON with paths (optional), scope (optional)
tool_prettier_check() {
    local args="${1:-}"

    worktree_enter "${args}" || return 1

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    worktree_assert_dependencies || return 1

    _prettier_dispatch_admin "format" "prettier_check" "--check" "${args}"
}

# Prettier fix (auto-format files)
# Args: JSON with paths (optional), scope (optional)
tool_prettier_fix() {
    local args="${1:-}"

    worktree_enter "${args}" || return 1

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    worktree_assert_dependencies || return 1

    # "--cache" is in the "format:fix" body; the "format" body has none.
    _prettier_dispatch_admin "format:fix" "prettier_fix" "--write --cache" "${args}"
}
