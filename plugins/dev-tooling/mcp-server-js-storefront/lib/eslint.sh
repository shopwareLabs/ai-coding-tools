#!/usr/bin/env bash
# ESLint tool implementation for Storefront Tooling MCP Server
# Provides eslint_check and eslint_fix MCP tools
#
# The Storefront splits ESLint across two trees:
#   app tree        -> npm script "eslint:app", paths relative to the package
#                      directory src/Storefront/Resources/app/storefront
#   components tree -> npm script "eslint:components", which runs after
#                      `cd ../..`, so paths are relative to
#                      src/Storefront/Resources
# Versions predating that split expose only lint:js / lint:js:fix; those are
# used as the fallback.

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

# Run one tree's ESLint invocation.
# Args: $1 = preferred npm script, $2 = fallback npm script,
#       $3 = base directory for the existence check,
#       $4 = pre-path flag string (may be empty), $5.. = rebased paths
# Stdout: linter output, or the failure message
_eslint_invoke_tree() {
    local script="$1"
    local fallback="$2"
    local base_dir="$3"
    local flag_string="$4"
    shift 4

    local body
    local exit_code=0
    body=$(npm_script_append_gate "${script}") || exit_code=$?

    if [[ "${exit_code}" -eq 1 ]]; then
        script="${fallback}"
        exit_code=0
        body=$(npm_script_append_gate "${script}") || exit_code=$?
    fi

    if [[ "${exit_code}" -ne 0 ]]; then
        printf '%s\n' "${body}"
        return 1
    fi

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

    local cmd="npm run ${script} --"
    if [[ -n "${flag_string}" ]]; then
        cmd="${cmd} ${flag_string}"
    fi
    cmd="${cmd} ${quoted[*]}"

    log "INFO" "Running ESLint (storefront, ${script}): ${cmd}"

    exec_npm_command "${cmd}"
}

# Route the caller's paths onto the two trees and run each one that is used.
# Args: $1 = tool arguments JSON, $2 = fallback npm script,
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

    if [[ -z "${paths}" ]]; then
        # A no-path run executes the aggregate script bare. That script chains
        # bare `npm run` calls, so a flags-only append lands past npm's own CLI
        # parser and never reaches ESLint — npm_script_append_gate refuses it.
        # Running bare anyway would silently substitute the package script's own
        # configuration for the scope-selected one.
        if [[ -n "${scoped_config}" ]]; then
            printf '%s\n' "Refusing to run: scope \"${SCOPE_NAME}\" selects the ESLint config \"${scoped_config}\", but a run without paths can only execute \"npm run ${fallback}\" bare, which would apply the package script's own config instead. \"${fallback}\" chains bare run-scripts, so the config cannot be appended to it either. Pass paths so the run is routed to eslint:app / eslint:components, or call with scope \"shopware\"."
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

    local overall=0
    local tree_output
    local tree_code

    if [[ ${#app_paths[@]} -gt 0 ]]; then
        tree_code=0
        tree_output=$(_eslint_invoke_tree "eslint:app" "${fallback}" \
            "${STOREFRONT_ESLINT_APP_BASE}" "${flag_string}" "${app_paths[@]}") || tree_code=$?
        printf '%s\n' "${tree_output}"
        if [[ "${tree_code}" -ne 0 ]]; then
            overall="${tree_code}"
        fi
    fi

    if [[ ${#component_paths[@]} -gt 0 ]]; then
        tree_code=0
        tree_output=$(_eslint_invoke_tree "eslint:components" "${fallback}" \
            "${STOREFRONT_ESLINT_COMPONENTS_BASE}" "${flag_string}" "${component_paths[@]}") || tree_code=$?
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

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
    local scoped_config
    scoped_config=$(scope_get_tool_field eslint config)

    local output_format
    output_format=$(echo "${args}" | jq -r '.output_format // "stylish"')

    local -a flags=()

    case "${output_format}" in
        json) flags+=("-f" "json") ;;
        compact) flags+=("-f" "compact") ;;
        stylish|*) flags+=("-f" "stylish") ;;
    esac

    [[ -n "${scoped_config}" ]] && flags+=("--config" "${scoped_config}")

    _eslint_dispatch "${args}" "lint:js" "${flags[*]}" "${scoped_config}"
}

# ESLint fix (auto-fix violations)
# Args: JSON with paths (optional), scope (optional)
tool_eslint_fix() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
    local scoped_config
    scoped_config=$(scope_get_tool_field eslint config)

    local -a flags=("--fix")
    [[ -n "${scoped_config}" ]] && flags+=("--config" "${scoped_config}")

    _eslint_dispatch "${args}" "lint:js:fix" "${flags[*]}" "${scoped_config}"
}
