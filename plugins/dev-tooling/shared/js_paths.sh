#!/usr/bin/env bash
# Path-scoped runs of a JS package's own linter binary, for the JS MCP servers:
# Admin Prettier and Stylelint, Storefront Stylelint, and the Storefront ESLint
# binary probe.
#
# Owned by dev-tooling. Not templated — do not add it to the mapping in
# .claude/rules/template-sync.md.
#
# A path-scoped run executes the package's own binary through `npm exec --no`,
# never the aggregate npm script: npm appends `--` arguments after the script
# body's own targets, so a path appended to the aggregate widens the run to
# those targets and cannot narrow it.
#
# Requires: exec_npm_command(), shell_quote_arg(), assert_paths_lintable() and
#           _env_targets_worktree() from environment.sh, npm_script_body()
#           for the Stylelint config check, LINT_ENV, jq.

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

# Refuse glob patterns and directories under ddev on a worktree: the command
# reaches `ddev exec`, which re-parses it in the container's bash without
# quoting a value that holds no space, quote or "#", so that bash would expand
# the pattern itself, without globstar, before the linter sees it.
# Args: $1 = tool name, $2 = linter name for the refusal,
#       $3.. = the caller's glob patterns and directories
# Stdout: the refusal
# Returns: 0 when no such path is given or the call runs elsewhere, 1 otherwise
js_assert_no_pattern_under_ddev_worktree() {
    local tool_name="$1"
    local linter="$2"
    shift 2

    if [[ $# -eq 0 || "${LINT_ENV:-}" != "ddev" ]] || ! _env_targets_worktree; then
        return 0
    fi

    printf '%s\n' "Refusing to run ${tool_name} with paths: under ddev on a worktree these paths would reach ${linter} as glob patterns the container shell expands first: $*. Pass file paths instead."
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
    js_assert_no_pattern_under_ddev_worktree "${tool_name}" "${linter}" \
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

# True when a command in an npm script body runs Stylelint with a config flag
# of its own: --config, --config=, -c or -c=, counted only after the stylelint
# token of the same command, so another program's -c is not taken for one.
# Stylelint refuses a second config flag. The Storefront's Stylelint 16 accepts
# all four; the Administration's Stylelint 14 rejects -c and -c=, so a script
# using either fails on its own, and counting them refuses it earlier with a
# clearer message.
# Args: $1 = script body
# Returns: 0 when a Stylelint command in the body passes a config, 1 otherwise
js_stylelint_body_passes_config() {
    local body="$1"

    body="${body//&&/;}"
    body="${body//||/;}"
    body="${body//|/;}"

    local -a segments=()
    IFS=';' read -r -a segments <<< "${body}"

    local segment args
    for segment in "${segments[@]+"${segments[@]}"}"; do
        segment=" ${segment} "
        case "${segment}" in
            *" stylelint "*) args=" ${segment#* stylelint }" ;;
            *"/stylelint "*) args=" ${segment#*/stylelint }" ;;
            *) continue ;;
        esac
        case "${args}" in
            *" --config "*|*" --config="*|*" -c "*|*" -c="*) return 0 ;;
        esac
    done

    return 1
}

# True when an npm script hands Stylelint a config of its own, directly or
# through an `npm run` of another script in its body, so a scope config cannot
# be appended to it.
# Args: $1 = npm script name, $2 = how many nested `npm run` levels to follow
# Stdout: a failure message, when a body cannot be read or the chain is deeper
# Returns: 0 = passes a config, 1 = passes none, 2 = a body could not be read,
#          or the chain runs deeper than $2 levels
js_stylelint_script_passes_config() {
    local script="$1"
    local depth="$2"

    local body
    local body_code=0
    body=$(npm_script_body "${script}") || body_code=$?
    if [[ "${body_code}" -eq 1 ]]; then
        printf '%s\n' "npm script \"${script}\" is not defined in package.json."
        return 2
    fi
    if [[ "${body_code}" -ne 0 ]]; then
        printf '%s\n' "Could not read npm script \"${script}\" from package.json to check it for its own Stylelint config; see the server log for the failed probe."
        return 2
    fi

    if js_stylelint_body_passes_config "${body}"; then
        return 0
    fi

    local padded=" ${body} "

    if [[ "${padded}" != *" npm run "* ]]; then
        return 1
    fi

    # An unread chain may pass a config, so it is refused rather than taken as
    # passing none.
    if [[ "${depth}" -le 0 ]]; then
        printf '%s\n' "npm script \"${script}\" runs further npm scripts nested deeper than this tool follows, so it cannot be checked for its own Stylelint config."
        return 2
    fi

    local rest="${padded}"
    local inner nested_code
    while [[ "${rest}" == *" npm run "* ]]; do
        rest="${rest#* npm run }"
        while [[ "${rest}" == -* ]]; do
            rest="${rest#* }"
        done
        inner="${rest%% *}"
        nested_code=0
        js_stylelint_script_passes_config "${inner}" "$((depth - 1))" || nested_code=$?
        if [[ "${nested_code}" -ne 1 ]]; then
            return "${nested_code}"
        fi
    done

    return 1
}
