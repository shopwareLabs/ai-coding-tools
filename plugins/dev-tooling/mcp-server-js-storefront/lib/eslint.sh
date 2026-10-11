#!/usr/bin/env bash
# ESLint tool implementation for Storefront Tooling MCP Server
# Provides eslint_check and eslint_fix MCP tools
#
# The Storefront's "lint:js" script lints two trees with two ESLint calls:
#   app tree        -> `eslint --no-error-on-unmatched-pattern
#                      --report-unused-disable-directives` in the package
#                      directory src/Storefront/Resources/app/storefront, so
#                      paths are relative to it
#   components tree -> the same flags plus `--config
#                      ./app/storefront/eslint.config.js`, run after
#                      `cd ../..`, so paths are relative to
#                      src/Storefront/Resources
# A run without paths executes the aggregate (lint:js / lint:js:fix), whose own
# targets stay authoritative. A run with paths never reaches the aggregate: it
# runs those two calls without their targets through the package's own ESLint
# binary (`npm exec --no`), so the caller's paths are the ONLY targets, and it
# fails rather than widening to the aggregate's targets when that binary is not
# installed.
#
# The components call has to start in ../..: ESLint reports a file outside its
# base path as "File ignored because outside of base path" and still exits 0,
# and with an explicit --config the base path is the working directory. It
# still has to start through npm in the package directory: ../.. holds no
# package.json, so `npm exec` started there would resolve its binary from
# another directory, and wrap_npm_command's ddev branch hands a command to
# `ddev npm` only when it starts with npm; the host shell splits any other
# compound command at its first `&&`, so only the cd would reach the container.
# `npm exec -c` runs its string through a shell in the package directory with
# the package's node_modules/.bin first on PATH, and the string does the cd.

STOREFRONT_ESLINT_BINARY="eslint"
# Flags both "lint:js" ESLint calls pass besides their targets.
STOREFRONT_ESLINT_FLAGS="--no-error-on-unmatched-pattern --report-unused-disable-directives"
# The config the components call names, relative to its ../.. working
# directory.
STOREFRONT_ESLINT_COMPONENTS_CONFIG="./app/storefront/eslint.config.js"
STOREFRONT_ESLINT_APP_BASE="."
STOREFRONT_ESLINT_COMPONENTS_BASE="../.."
# Extensions the Storefront ESLint config can match. A path that resolves to no
# file with one of them lints nothing and still exits 0.
STOREFRONT_ESLINT_EXTENSIONS="js ts mjs cjs jsx tsx vue json"

# True when the path belongs to the Storefront components tree.
# Args: $1 = caller-supplied path
_eslint_is_components_path() {
    local path="$1"
    [[ "${path}" == *"views/components/"* || "${path}" == *"views/components" ]]
}

# Rebase a components-tree path onto src/Storefront/Resources.
# Accepts the repo-root-relative form, the tree-relative form, and a path that
# already carries a package prefix.
# Args: $1 = caller-supplied path
_eslint_rebase_components_path() {
    local path="$1"
    printf '%s\n' "views/components${path#*views/components}"
}

# Rebase an app-tree path onto the app/storefront package directory.
# Args: $1 = caller-supplied path
_eslint_rebase_app_path() {
    local path="$1"
    if [[ "${path}" == *"app/storefront/"* ]]; then
        path="${path#*app/storefront/}"
    fi
    printf '%s\n' "${path}"
}

# Refuse a path-scoped run when the package's own ESLint binary is not
# installed where the command runs. `npm exec --no` never installs, but on a
# miss it still runs a globally installed binary of the same name, so the probe
# runs first and the run never reaches a binary the package did not pin. Both
# trees resolve the binary from the package directory, so one probe covers
# both.
# Args: $1 = aggregate npm script, named in the refusal
# Stdout: the refusal, when the binary is missing
# Returns: 0 when node_modules/.bin/eslint is executable, 1 otherwise
_eslint_assert_local_binary() {
    local aggregate="$1"
    local bin_path="node_modules/.bin/${STOREFRONT_ESLINT_BINARY}"

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
        printf '%s\n' "Refusing to lint with paths: \"${bin_path}\" is not installed in the package directory \"${package_dir}\". A path-scoped run executes only the package's own ${STOREFRONT_ESLINT_BINARY} binary: it installs none and uses no global one, and the aggregate \"${aggregate}\" script is not a substitute, because its own targets would widen the run. Run \`npm ci\` in that directory, or call worktree_prepare on this server for a worktree."
        return 1
    fi

    printf '%s\n' "Refusing to lint with paths: could not check whether the package's own ${STOREFRONT_ESLINT_BINARY} binary is installed; the probe exited with ${probe_code}.${output:+ Probe output: ${output}}"
    return 1
}

# Run one tree's ESLint invocation. Reached only when the caller supplied
# paths, so the aggregate is never a fallback here: its body names its own
# targets, and npm appends `--` arguments after them, so substituting it would
# widen the run instead of narrowing it to the requested paths.
# Args: $1 = tree name, "app" or "components",
#       $2 = base directory for the existence check,
#       $3 = pre-path flag string (may be empty), $4.. = rebased paths
# Stdout: linter output, or the failure message
_eslint_invoke_tree() {
    local tree="$1"
    local base_dir="$2"
    local flag_string="$3"
    shift 3

    local missing_report
    if ! missing_report=$(assert_paths_lintable "${base_dir}" "${STOREFRONT_ESLINT_EXTENSIONS}" "$@"); then
        printf '%s\n' "${missing_report}"
        return 1
    fi

    local -a quoted=()
    local p
    for p in "$@"; do
        quoted+=("$(shell_quote_arg "${p}")")
    done

    local eslint_cmd="${STOREFRONT_ESLINT_BINARY} ${STOREFRONT_ESLINT_FLAGS}"
    # _eslint_dispatch refuses the components tree under a scope, so no scope
    # config reaches this call.
    if [[ "${tree}" == "components" ]]; then
        eslint_cmd="${eslint_cmd} --config ${STOREFRONT_ESLINT_COMPONENTS_CONFIG}"
    fi
    if [[ -n "${flag_string}" ]]; then
        eslint_cmd="${eslint_cmd} ${flag_string}"
    fi
    eslint_cmd="${eslint_cmd} ${quoted[*]}"

    local cmd
    if [[ "${tree}" == "components" ]]; then
        # The inner string is quoted once more for the shell that parses this
        # command; npm's own shell then parses it, including each path's quotes.
        cmd="npm exec --no -c $(shell_quote_arg "cd ${STOREFRONT_ESLINT_COMPONENTS_BASE} && ${eslint_cmd}")"
    else
        cmd="npm exec --no -- ${eslint_cmd}"
    fi

    log "INFO" "Running ESLint (storefront, ${tree} tree): ${cmd}"

    exec_npm_command "${cmd}"
}

# Route the caller's paths onto the two trees and run each one that is used.
# Args: $1 = tool arguments JSON, $2 = aggregate npm script,
#       $3 = pre-path flag string (may be empty), $4 = scope-configured ESLint
#       config (may be empty)
_eslint_dispatch() {
    local args="$1"
    local fallback="$2"
    local flag_string="$3"
    local scoped_config="$4"

    local paths_json paths
    paths_json=$(echo "${args}" | jq -c '.paths // []')
    if ! paths=$(parse_paths_json "${paths_json}" ""); then
        printf '%s\n' "${paths}"
        return 1
    fi

    # The caller's own spelling is what is checked, before the routing below
    # rebases it onto one of the two trees. Only absolute paths are examined, so
    # the upward-traversing relative form the components tree is reached through
    # is untouched.
    worktree_assert_paths_within_root "${paths_json}" || return 1

    if [[ -z "${paths}" ]]; then
        # A no-path run executes the aggregate script bare. That script chains
        # two ESLint calls and ends in a subshell, so an appended flag would
        # land after that subshell, outside both calls — npm_script_append_gate
        # refuses it.
        # Running bare anyway would silently substitute the package script's own
        # configuration for the scope-selected one.
        if [[ -n "${scoped_config}" ]]; then
            printf '%s\n' "Refusing to run: scope \"${SCOPE_NAME}\" selects the ESLint config \"${scoped_config}\", but a run without paths can only execute \"npm run ${fallback}\" bare, which would apply the package script's own config instead. \"${fallback}\" chains two ESLint calls, so the config cannot be appended to it either. Pass paths so the run executes ESLint on them directly, or call with scope \"shopware\"."
            return 1
        fi
        local bare_cmd="npm run ${fallback}"
        log "INFO" "Running ESLint (storefront, ${fallback}): ${bare_cmd}"
        exec_npm_command "${bare_cmd}"
        return
    fi

    local -a app_paths=()
    local -a component_paths=()
    local p
    while IFS= read -r p; do
        [[ -z "${p}" ]] && continue
        if _eslint_is_components_path "${p}"; then
            component_paths+=("$(_eslint_rebase_components_path "${p}")")
        else
            app_paths+=("$(_eslint_rebase_app_path "${p}")")
        fi
    done < <(printf '%s\n' "${paths_json}" | jq -r '.[]')

    # The components call is the core Storefront's own: it changes to ../.. and
    # names ./app/storefront/eslint.config.js, which exist only relative to
    # src/Storefront/Resources/app/storefront. Under a scope the working
    # directory is the scope's package instead, where both name something else.
    if [[ ${#component_paths[@]} -gt 0 && -n "${SCOPE_CWD:-}" ]]; then
        printf '%s\n' "Refusing to lint with paths: scope \"${SCOPE_NAME}\" runs in \"${SCOPE_CWD}\", but these paths route to the core Storefront components tree, which is linted from src/Storefront/Resources with ./app/storefront/eslint.config.js: ${component_paths[*]}. Lint them with scope \"shopware\"."
        return 1
    fi

    _eslint_assert_local_binary "${fallback}" || return 1

    local overall=0
    local tree_output
    local tree_code

    if [[ ${#app_paths[@]} -gt 0 ]]; then
        tree_code=0
        tree_output=$(_eslint_invoke_tree "app" "${STOREFRONT_ESLINT_APP_BASE}" \
            "${flag_string}" "${app_paths[@]}") || tree_code=$?
        printf '%s\n' "${tree_output}"
        if [[ "${tree_code}" -ne 0 ]]; then
            overall="${tree_code}"
        fi
    fi

    if [[ ${#component_paths[@]} -gt 0 ]]; then
        tree_code=0
        tree_output=$(_eslint_invoke_tree "components" "${STOREFRONT_ESLINT_COMPONENTS_BASE}" \
            "${flag_string}" "${component_paths[@]}") || tree_code=$?
        printf '%s\n' "${tree_output}"
        if [[ "${tree_code}" -ne 0 ]]; then
            overall="${tree_code}"
        fi
    fi

    return "${overall}"
}

# ESLint check (dry-run)
# Args: JSON with paths (optional), output_format (optional), scope (optional)
tool_eslint_check() {
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
    scoped_config=$(scope_get_tool_field eslint config)

    local output_format
    output_format=$(echo "${args}" | jq -r '.output_format // "stylish"')

    local -a flags=()

    case "${output_format}" in
        json) flags+=("-f" "json") ;;
        stylish|*) flags+=("-f" "stylish") ;;
    esac

    [[ -n "${scoped_config}" ]] && flags+=("--config" "${scoped_config}")

    _eslint_dispatch "${args}" "lint:js" "${flags[*]}" "${scoped_config}"
}

# ESLint fix (auto-fix violations)
# Args: JSON with paths (optional), scope (optional)
tool_eslint_fix() {
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
    scoped_config=$(scope_get_tool_field eslint config)

    local -a flags=("--fix")
    [[ -n "${scoped_config}" ]] && flags+=("--config" "${scoped_config}")

    _eslint_dispatch "${args}" "lint:js:fix" "${flags[*]}" "${scoped_config}"
}
