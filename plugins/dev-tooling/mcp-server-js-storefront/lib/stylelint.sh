#!/usr/bin/env bash
# Stylelint tool implementation for Storefront Tooling MCP Server
# Provides stylelint_check and stylelint_fix MCP tools
#
# Two routes, selected by whether the caller supplied paths:
#   paths supplied -> the package's own Stylelint binary through
#                     `npm exec --no -- stylelint --config stylelint.config.js
#                     --cache`, the flags of the "lint:scss" body without its
#                     `./src/scss` target, so the caller's paths are the ONLY
#                     targets. Under a scope that `--config` is left out: a
#                     scope-configured config takes its place (Stylelint
#                     refuses a second `--config` flag outright), and without
#                     one Stylelint finds the scope package's own config.
#                     A directory path is narrowed to its .scss and .css files.
#   paths omitted  -> the aggregate script ("lint:scss" / "lint:scss-fix"),
#                     whose body carries its own `./src/scss` target, which
#                     stays authoritative.
# The aggregate is never a fallback for a path-scoped run. npm appends `--`
# arguments to the END of the whole script body, so appending a path to a body
# that already names `./src/scss` widens the run to that whole tree PLUS the
# path — it can never narrow it. That matters most for stylelint_fix, which
# writes: a widened fix modifies files the caller never named.
#
# The two routes also differ in where `--fix` comes from. "lint:scss-fix"
# carries `--fix` in its own body, so the no-paths route must not add a second
# one; the path-scoped command carries none, so the path-scoped route must add
# it or stylelint_fix silently runs as a check and writes nothing.

STOREFRONT_STYLELINT_BINARY="stylelint"
# The config the "lint:scss" body names, relative to the package directory.
STOREFRONT_STYLELINT_CONFIG="stylelint.config.js"
# Extensions Stylelint reads here. Neither stylelint.config.js nor the CLI
# restricts the set, so this is the pair the SCSS rulesets actually parse. A
# path that resolves to no file with one of them lints nothing and still
# exits 0.
STOREFRONT_STYLELINT_EXTENSIONS="scss css"
# What a directory path is narrowed to: the extensions above, below it.
STOREFRONT_STYLELINT_DIRECTORY_GLOB="**/*.{scss,css}"

# True when the path is a glob pattern Stylelint expands itself rather than a
# literal filesystem path. The existence probe cannot resolve a glob, so glob
# entries skip the guard. Nothing is lost by skipping it: Stylelint exits 1 on a
# glob that matches no file and names the pattern, so the unmatched-glob case is
# still reported to the caller by the tool itself.
# Args: $1 = caller-supplied path
if ! declare -F _stylelint_storefront_path_is_glob >/dev/null; then
    _stylelint_storefront_path_is_glob() {
        case "$1" in
            *"*"*|*"?"*|*"["*) return 0 ;;
        esac
        return 1
    }
fi

# Refuse a path-scoped run when the package's own Stylelint binary is not
# installed where the command runs. `npm exec --no` never installs, but on a
# miss it still runs a globally installed binary of the same name, so the probe
# runs first and the run never reaches a binary the package did not pin.
# Args: $1 = tool name, $2 = aggregate npm script, named in the refusal
# Stdout: the refusal, when the binary is missing
# Returns: 0 when node_modules/.bin/stylelint is executable, 1 otherwise
_stylelint_storefront_assert_local_binary() {
    local tool_name="$1"
    local aggregate="$2"
    local bin_path="node_modules/.bin/${STOREFRONT_STYLELINT_BINARY}"

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
        printf '%s\n' "Refusing to run ${tool_name} with paths: \"${bin_path}\" is not installed in the package directory \"${package_dir}\". A path-scoped run executes only the package's own ${STOREFRONT_STYLELINT_BINARY} binary: it installs none and uses no global one, and the aggregate \"${aggregate}\" script is not a substitute, because its own targets would widen the run. Run \`npm ci\` in that directory, or call worktree_prepare on this server for a worktree."
        return 1
    fi

    printf '%s\n' "Refusing to run ${tool_name} with paths: could not check whether the package's own ${STOREFRONT_STYLELINT_BINARY} binary is installed; the probe exited with ${probe_code}.${output:+ Probe output: ${output}}"
    return 1
}

# True when a command in an npm script body runs Stylelint with a config flag
# of its own: --config, --config=, -c or -c=, counted only after the stylelint
# token of the same command, so another program's -c in the same script is not
# taken for one. The Storefront's Stylelint 16 accepts each of the four and
# refuses any second one.
# Args: $1 = script body
# Returns: 0 when a Stylelint command in the body passes a config, 1 otherwise
_stylelint_storefront_body_passes_config() {
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

# Print, one per line, the caller's literal paths that name directories. A
# literal path without an accepted extension has passed the lintable probe only
# as a directory holding such a file. One carrying an accepted extension can
# still be a directory, so those are tested where the command runs, through
# `npm exec -c` like the binary probe.
# Args: $1.. = literal paths that passed the lintable probe
# Stdout: the directories, or the failure message
# Returns: 0 on success, 1 when the test could not run
_stylelint_storefront_directories() {
    local -a extensions=()
    read -r -a extensions <<< "${STOREFRONT_STYLELINT_EXTENSIONS}"

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

# The target a directory reaches Stylelint as. Stylelint given a directory
# reads every file under it, so a directory becomes a glob limited to the
# accepted extensions, which Stylelint expands itself because the caller's
# quoting keeps it away from the shell.
# Args: $1 = directory path
# Stdout: the pattern
_stylelint_storefront_directory_pattern() {
    local path="$1"

    while [[ "${path}" == */ && "${path}" != "/" ]]; do
        path="${path%/}"
    done
    printf '%s\n' "${path}/${STOREFRONT_STYLELINT_DIRECTORY_GLOB}"
}

# Under ddev on a worktree the command reaches `ddev exec`, which re-parses it
# in the container's bash without quoting a value that holds no space, quote
# or "#", so that bash would expand a glob pattern itself, without globstar,
# before Stylelint sees it. A run there takes file paths only.
# Args: $1 = tool name, $2.. = the caller's glob patterns and directories
# Stdout: the refusal
# Returns: 0 when no such path is given or the call runs elsewhere, 1 otherwise
_stylelint_storefront_assert_no_pattern_under_ddev_worktree() {
    local tool_name="$1"
    shift

    if [[ $# -eq 0 || "${LINT_ENV:-}" != "ddev" ]] || ! _env_targets_worktree; then
        return 0
    fi

    printf '%s\n' "Refusing to run ${tool_name} with paths: under ddev on a worktree these paths would reach Stylelint as glob patterns the container shell expands first: $*. Pass file paths instead."
    return 1
}

# True when an npm script hands Stylelint a config of its own, directly or
# through an `npm run` of another script in its body. Stylelint refuses a second
# --config ("The flag --config can only be set once."), so a scope config cannot
# be appended to such a script.
# Args: $1 = npm script name, $2 = how many nested `npm run` levels to follow
# Stdout: a failure message, when a body cannot be read or the chain is deeper
# Returns: 0 = passes a config, 1 = passes none, 2 = a body could not be read,
#          or the chain runs deeper than $2 levels
_stylelint_storefront_script_passes_config() {
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

    if _stylelint_storefront_body_passes_config "${body}"; then
        return 0
    fi

    local padded=" ${body} "

    if [[ "${padded}" != *" npm run "* ]]; then
        return 1
    fi

    # A chain longer than this is not read to its end, so whether it passes a
    # config is unknown; that is refused rather than taken as "none".
    if [[ "${depth}" -le 0 ]]; then
        printf '%s\n' "npm script \"${script}\" runs further npm scripts nested deeper than this tool follows, so it cannot be checked for its own Stylelint config."
        return 2
    fi

    local rest="${padded}"
    local inner nested_code
    while [[ "${rest}" == *" npm run "* ]]; do
        rest="${rest#* npm run }"
        # Options such as --silent precede the script name.
        while [[ "${rest}" == -* ]]; do
            rest="${rest#* }"
        done
        inner="${rest%% *}"
        nested_code=0
        _stylelint_storefront_script_passes_config "${inner}" "$((depth - 1))" || nested_code=$?
        if [[ "${nested_code}" -ne 1 ]]; then
            return "${nested_code}"
        fi
    done

    return 1
}

# Run one Stylelint invocation for this tool.
# Args: $1 = aggregate npm script used when no paths are supplied,
#       $2 = tool name, for the refusal message,
#       $3 = pre-path flag string used on both routes (may be empty),
#       $4 = pre-path flag string used ONLY on the path-scoped route, for flags
#            the aggregate script already carries in its own body (may be empty),
#       $5 = tool arguments JSON,
#       $6 = scope-configured Stylelint config, already part of $3 (may be empty)
# Stdout: linter output, or the failure message
_stylelint_dispatch_storefront() {
    local aggregate="$1"
    local tool_name="$2"
    local flag_string="$3"
    local path_only_flags="$4"
    local args="$5"
    local scoped_config="${6:-}"

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
        # No paths: the aggregate script's own targets stay authoritative.
        # With nothing to append, it runs bare and needs no append gate.
        if [[ -z "${flag_string}" ]]; then
            local bare_cmd="npm run ${aggregate}"
            log "INFO" "Running Stylelint (storefront, ${aggregate}): ${bare_cmd}"
            exec_npm_command "${bare_cmd}"
            return
        fi

        body=$(npm_script_append_gate "${aggregate}") || gate_code=$?
        if [[ "${gate_code}" -ne 0 ]]; then
            printf '%s\n' "${body}"
            return 1
        fi

        if [[ -n "${scoped_config}" ]]; then
            local config_check
            local config_code=0
            config_check=$(_stylelint_storefront_script_passes_config "${aggregate}" 3) || config_code=$?
            if [[ "${config_code}" -eq 0 ]]; then
                printf '%s\n' "Refusing to run: scope \"${SCOPE_NAME}\" selects the Stylelint config \"${scoped_config}\", but \"npm run ${aggregate}\" already passes a config of its own, and Stylelint refuses a second --config. Pass paths so the run uses the scope config alone, or call with scope \"shopware\"."
                return 1
            fi
            if [[ "${config_code}" -ne 1 ]]; then
                printf '%s\n' "${config_check}"
                return 1
            fi
        fi

        local aggregate_cmd="npm run ${aggregate} -- ${flag_string}"
        log "INFO" "Running Stylelint (storefront, ${aggregate}): ${aggregate_cmd}"
        exec_npm_command "${aggregate_cmd}"
        return
    fi

    local -a supplied=()
    local -a literals=()
    local p
    while IFS= read -r p; do
        [[ -z "${p}" ]] && continue
        supplied+=("${p}")
        if ! _stylelint_storefront_path_is_glob "${p}"; then
            literals+=("${p}")
        fi
    done < <(printf '%s\n' "${paths_json}" | jq -r '.[]')

    _stylelint_storefront_assert_local_binary "${tool_name}" "${aggregate}" || return 1

    if [[ ${#literals[@]} -gt 0 ]]; then
        local missing_report
        if ! missing_report=$(assert_paths_lintable "." "${STOREFRONT_STYLELINT_EXTENSIONS}" "${literals[@]}"); then
            printf '%s\n' "${missing_report}"
            return 1
        fi
    fi

    local -a directories=()
    if [[ ${#literals[@]} -gt 0 ]]; then
        local directory_report
        if ! directory_report=$(_stylelint_storefront_directories "${literals[@]}"); then
            printf '%s\n' "${directory_report}"
            return 1
        fi
        while IFS= read -r p; do
            [[ -n "${p}" ]] && directories+=("${p}")
        done <<< "${directory_report}"
    fi

    local -a patterns=()
    for p in "${supplied[@]}"; do
        _stylelint_storefront_path_is_glob "${p}" && patterns+=("${p}")
    done
    _stylelint_storefront_assert_no_pattern_under_ddev_worktree "${tool_name}" \
        "${patterns[@]+"${patterns[@]}"}" "${directories[@]+"${directories[@]}"}" || return 1

    local -a quoted=()
    local target directory
    for p in "${supplied[@]}"; do
        target="${p}"
        for directory in "${directories[@]+"${directories[@]}"}"; do
            if [[ "${directory}" == "${p}" ]]; then
                target=$(_stylelint_storefront_directory_pattern "${p}")
                break
            fi
        done
        quoted+=("$(shell_quote_arg "${target}")")
    done

    # `--config stylelint.config.js --cache` are the flags the "lint:scss"
    # body passes besides its target. The config is the core Storefront
    # package's, so it is named only on an unscoped run. Under a scope a
    # configured Stylelint config is already in the flag string, and without
    # one Stylelint finds the scope package's own config itself. Anything the
    # aggregate fix script would have supplied has to be added here as well.
    local cmd="npm exec --no -- ${STOREFRONT_STYLELINT_BINARY}"
    if [[ -z "${SCOPE_CWD:-}" ]]; then
        cmd="${cmd} --config ${STOREFRONT_STYLELINT_CONFIG}"
    fi
    cmd="${cmd} --cache"
    if [[ -n "${flag_string}" ]]; then
        cmd="${cmd} ${flag_string}"
    fi
    if [[ -n "${path_only_flags}" ]]; then
        cmd="${cmd} ${path_only_flags}"
    fi
    cmd="${cmd} ${quoted[*]}"

    log "INFO" "Running Stylelint (storefront, npm exec): ${cmd}"

    exec_npm_command "${cmd}"
}

# Stylelint check (dry-run)
# Args: JSON with paths (optional), output_format (optional), scope (optional)
tool_stylelint_check() {
    local args="$1"

    worktree_enter "${args}" || return 1

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    worktree_assert_dependencies || return 1

    local scoped_config
    scoped_config=$(scope_get_tool_field stylelint config)

    local output_format
    output_format=$(echo "${args}" | jq -r '.output_format // "string"')

    # The reporter flag is always appended, so this tool never runs bare.
    local -a flags=()

    case "${output_format}" in
        json) flags+=("-f" "json") ;;
        compact) flags+=("-f" "compact") ;;
        string|*) flags+=("-f" "string") ;;
    esac

    [[ -n "${scoped_config}" ]] && flags+=("--config" "${scoped_config}")

    _stylelint_dispatch_storefront "lint:scss" "stylelint_check" "${flags[*]}" "" "${args}" "${scoped_config}"
}

# Stylelint fix (auto-fix violations)
# Args: JSON with paths (optional), scope (optional)
tool_stylelint_fix() {
    local args="$1"

    worktree_enter "${args}" || return 1

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    worktree_assert_dependencies || return 1

    local scoped_config
    scoped_config=$(scope_get_tool_field stylelint config)

    local -a flags=()
    [[ -n "${scoped_config}" ]] && flags+=("--config" "${scoped_config}")

    # Expanded through a guard: an empty array under `set -u` is not portable
    # to every bash the servers may run under, and empty is the common case
    # here (no scoped config, so nothing precedes the paths).
    local flag_string=""
    if [[ ${#flags[@]} -gt 0 ]]; then
        flag_string="${flags[*]}"
    fi

    # "--fix" is path-route only: the "lint:scss-fix" body already carries one.
    _stylelint_dispatch_storefront "lint:scss-fix" "stylelint_fix" "${flag_string}" "--fix" "${args}" "${scoped_config}"
}
