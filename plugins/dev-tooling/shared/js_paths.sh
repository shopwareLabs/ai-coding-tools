#!/usr/bin/env bash
# Path-scoped runs of a JS package's own linter binary, for the JS MCP servers:
# Admin Prettier and Stylelint, Storefront Stylelint, and the Admin and
# Storefront ESLint binary probe and scope-cwd rebase. Also the Stylelint check
# that refuses a second config on an aggregate script.
#
# Owned by dev-tooling. Not templated — do not add it to the mapping in
# .claude/rules/template-sync.md.
#
# A path-scoped run executes the package's own binary through `npm exec --no`,
# never the aggregate npm script: npm appends `--` arguments after the script
# body's own targets, so a path appended to the aggregate widens the run to
# those targets and cannot narrow it.
#
# Requires: exec_npm_command(), shell_quote_arg() and assert_paths_lintable()
#           from environment.sh, LINT_ENV, SCOPE_NAME, SCOPE_CWD, jq.

# Strip a leading scope cwd off a caller path. The cwd is compared without a
# leading "./" and without trailing "/", which the scope config may carry.
# Globals: SCOPE_CWD (read)
# Args: $1 = caller-supplied path
# Stdout: the path relative to the scope cwd, or unchanged without that prefix
js_strip_scope_cwd() {
    local cwd="${SCOPE_CWD#./}"
    while [[ "${cwd}" == */ ]]; do
        cwd="${cwd%/}"
    done
    printf '%s\n' "${1#"${cwd}/"}"
}

# Refuse to append a scope config to an aggregate script whose own linter
# command already passes one: the linter accepts its config option only once.
# Args: $1 = tool name, $2 = linter name, $3 = binary, $4 = aggregate npm
#       script, $5 = its body, $6 = scope-configured config (may be empty)
# Stdout: the refusal
# Returns: 0 when no scope config is set or the body passes no config, 1 otherwise
js_refuse_second_config() {
    local tool_name="$1"
    local linter="$2"
    local binary="$3"
    local aggregate="$4"
    local body="$5"
    local scoped_config="$6"

    if [[ -z "${scoped_config}" ]]; then
        return 0
    fi

    local -a words=()
    read -r -a words <<< "${body}"
    local word in_command=0
    for word in "${words[@]+"${words[@]}"}"; do
        if [[ "${in_command}" -eq 0 ]]; then
            if [[ "${word}" == "${binary}" || "${word}" == */"${binary}" ]]; then
                in_command=1
            fi
            continue
        fi
        case "${word}" in
            "&&")
                in_command=0
                ;;
            --config|--config=*|-c|-c=*)
                printf '%s\n' "Refusing to run ${tool_name}: scope \"${SCOPE_NAME}\" selects the ${linter} config \"${scoped_config}\", but npm script \"${aggregate}\" already passes its own config to ${binary}: \"${body}\". ${linter} accepts its config option only once, so the appended one cannot apply. Pass paths so the run executes ${linter} on them directly, or call with scope \"shopware\"."
                return 1
                ;;
        esac
    done
    return 0
}

# True when the path is a glob pattern the linter expands itself. The existence
# probe cannot resolve a glob, so a glob skips it.
# Args: $1 = caller-supplied path
js_path_is_glob() {
    case "$1" in
        *"*"*|*"?"*|*"["*) return 0 ;;
    esac
    return 1
}

# Refuse a path-scoped run when the package's own binary is not executable in
# node_modules/.bin where the command runs: `npm exec --no` installs nothing,
# but runs a global binary of the same name when the package has none. Probe
# exit 3 means the binary is missing, and the probe then prints the directory
# it ran in, under a container the container's path; any other non-zero exit
# means the probe itself failed.
# Args: $1 = tool name, $2 = binary, $3 = aggregate npm script, named in the
#       refusal
# Stdout: the refusal
# Returns: 0 when the binary is executable, 1 otherwise
js_assert_local_binary() {
    local tool_name="$1"
    local binary="$2"
    local aggregate="$3"
    local bin_path="node_modules/.bin/${binary}"

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
        printf '%s\n' "Refusing to run ${tool_name} with paths: \"${bin_path}\" is not installed in the package directory \"${package_dir}\". A path-scoped run executes only the package's own ${binary} binary: it installs none and uses no global one, and the aggregate \"${aggregate}\" script is not a substitute, because its own targets would widen the run. Run \`npm ci\` in that directory, or call worktree_prepare on this server for a worktree."
        return 1
    fi

    printf '%s\n' "Refusing to run ${tool_name} with paths: could not check whether the package's own ${binary} binary is installed; the probe exited with ${probe_code}.${output:+ Probe output: ${output}}"
    return 1
}

# Print, one per line, the literal paths that name directories. A path without
# an accepted extension passed the lintable probe only as a directory; one with
# an accepted extension may still be a directory, so those are tested where the
# command runs.
# Args: $1 = tool name, $2 = space-separated accepted extensions,
#       $3.. = literal paths that passed the lintable probe
# Stdout: the directories, or the refusal
# Returns: 0 on success, 1 when the test could not run
js_path_directories() {
    local tool_name="$1"
    local -a extensions=()
    read -r -a extensions <<< "$2"
    shift 2

    local -a directories=()
    local p ext named script=""
    for p in "$@"; do
        named=0
        for ext in "${extensions[@]}"; do
            if [[ "${p}" == *".${ext}" ]]; then
                named=1
            fi
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
            printf '%s\n' "Refusing to run ${tool_name} with paths: could not check which of them are directories; the probe exited with ${probe_code}.${output:+ Probe output: ${output}}"
            return 1
        fi
        local line
        while IFS= read -r line; do
            if [[ "${line}" == DIRECTORY:* ]]; then
                directories+=("${line#DIRECTORY:}")
            fi
        done <<< "${output}"
    fi

    if [[ ${#directories[@]} -gt 0 ]]; then
        printf '%s\n' "${directories[@]}"
    fi
}

# The pattern a directory reaches the linter as: the linter reads every file
# type it supports below a directory, so the directory is narrowed to the
# accepted extensions. The caller's quoting keeps the pattern away from the
# shell, so the linter expands it.
# Args: $1 = directory path, $2 = glob below it, e.g. "**/*.scss"
# Stdout: the pattern
js_directory_pattern() {
    local path="$1"

    while [[ "${path}" == */ && "${path}" != "/" ]]; do
        path="${path%/}"
    done
    printf '%s\n' "${path}/$2"
}

# Refuse glob patterns and directories under ddev: the command
# reaches `ddev exec`, which re-parses it in the container's bash without
# quoting a value that holds no space, tab, double quote or "#", so that bash
# would expand the pattern itself, without globstar, before the linter sees it.
# A value holding one of those characters is quoted again and reaches the
# linter intact.
# Args: $1 = tool name, $2 = linter name for the refusal,
#       $3.. = the caller's glob patterns and directories
# Stdout: the refusal
# Returns: 0 when every such path is re-quoted or the environment is not ddev,
#          1 otherwise
js_assert_no_pattern_under_ddev() {
    local tool_name="$1"
    local linter="$2"
    shift 2

    if [[ "${LINT_ENV:-}" != "ddev" ]]; then
        return 0
    fi

    local -a expanded=()
    local p
    for p in "$@"; do
        if [[ "${p}" != *[\ $'\t'\"\#]* ]]; then
            expanded+=("${p}")
        fi
    done
    if [[ ${#expanded[@]} -eq 0 ]]; then
        return 0
    fi

    printf '%s\n' "Refusing to run ${tool_name} with paths: under ddev these paths would reach ${linter} as glob patterns the container shell expands first: ${expanded[*]}. Pass file paths instead."
    return 1
}

# Check the caller's paths for a path-scoped run and turn them into the
# linter's targets, each shell-quoted, with a directory narrowed to the
# directory glob.
# Args: $1 = tool name, $2 = binary, $3 = aggregate npm script,
#       $4 = space-separated accepted extensions, $5 = directory glob,
#       $6 = linter name for refusals, $7 = paths JSON array
# Stdout: the targets joined by spaces, or the refusal
# Returns: 0 on success, 1 on a refusal
js_path_scoped_targets() {
    local tool_name="$1"
    local binary="$2"
    local aggregate="$3"
    local extension_list="$4"
    local directory_glob="$5"
    local linter="$6"
    local paths_json="$7"

    local -a supplied=()
    local -a literals=()
    local p
    while IFS= read -r p; do
        if [[ -z "${p}" ]]; then
            continue
        fi
        supplied+=("${p}")
        if ! js_path_is_glob "${p}"; then
            literals+=("${p}")
        fi
    done < <(printf '%s\n' "${paths_json}" | jq -r '.[]')

    js_assert_local_binary "${tool_name}" "${binary}" "${aggregate}" || return 1

    local -a directories=()
    if [[ ${#literals[@]} -gt 0 ]]; then
        local report
        if ! report=$(assert_paths_lintable "." "${extension_list}" "${literals[@]}"); then
            printf '%s\n' "${report}"
            return 1
        fi
        if ! report=$(js_path_directories "${tool_name}" "${extension_list}" "${literals[@]}"); then
            printf '%s\n' "${report}"
            return 1
        fi
        while IFS= read -r p; do
            if [[ -n "${p}" ]]; then
                directories+=("${p}")
            fi
        done <<< "${report}"
    fi

    local -a patterns=()
    for p in "${supplied[@]}"; do
        if js_path_is_glob "${p}"; then
            patterns+=("${p}")
        fi
    done
    js_assert_no_pattern_under_ddev "${tool_name}" "${linter}" \
        "${patterns[@]+"${patterns[@]}"}" "${directories[@]+"${directories[@]}"}" || return 1

    local -a quoted=()
    local target directory
    for p in "${supplied[@]}"; do
        target="${p}"
        for directory in "${directories[@]+"${directories[@]}"}"; do
            if [[ "${directory}" == "${p}" ]]; then
                target=$(js_directory_pattern "${p}" "${directory_glob}")
                break
            fi
        done
        quoted+=("$(shell_quote_arg "${target}")")
    done

    printf '%s\n' "${quoted[*]}"
}
