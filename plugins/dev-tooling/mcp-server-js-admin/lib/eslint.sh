#!/usr/bin/env bash
# ESLint tool implementation for Admin Tooling MCP Server
# Provides eslint_check and eslint_fix MCP tools
#
# Two routes, selected by whether the caller supplied paths:
#   paths supplied -> npm script "lint:debugging", whose body is a bare
#                     `eslint`, so the caller's paths are the ONLY targets.
#   paths omitted  -> the aggregate script ("lint" / "lint:fix"), whose body
#                     carries its own targets, which stay authoritative.
# The aggregate is never a fallback for a path-scoped run. npm appends `--`
# arguments to the END of the whole script body, so appending a path to a body
# that already names `src test build.ts` widens the run to those targets PLUS
# the path — it can never narrow it to the path. A path-scoped run that cannot
# reach the target-less base script fails hard instead.

ADMIN_ESLINT_BASE_SCRIPT="lint:debugging"
# Extensions the Administration ESLint flat config can match, read off the
# `files:` globs in eslint.config.ts: **/*.js, **/*.ts, **/*.tsx, **/*.vue,
# **/*.html.twig and src/**/snippet/*.json. A path that resolves to no file
# with one of them lints nothing and still exits 0.
ADMIN_ESLINT_EXTENSIONS="js ts tsx vue json twig"

# Rebase a path onto the app/administration package directory, so a
# repo-root-relative path the caller pasted from a diff resolves in the npm
# working directory. A path that carries no package prefix is passed through.
# Args: $1 = caller-supplied path
if ! declare -F _eslint_rebase_admin_path >/dev/null; then
    _eslint_rebase_admin_path() {
        local path="$1"
        if [[ "${path}" == *"app/administration/"* ]]; then
            path="${path#*app/administration/}"
        fi
        printf '%s\n' "${path}"
    }
fi

# Run one ESLint invocation for this tool.
# Args: $1 = aggregate npm script used when no paths are supplied,
#       $2 = tool name, for the refusal message,
#       $3 = pre-path flag string (may be empty),
#       $4 = tool arguments JSON
# Stdout: linter output, or the failure message
_eslint_dispatch_admin() {
    local aggregate="$1"
    local tool_name="$2"
    local flag_string="$3"
    local args="$4"

    local paths_json paths
    paths_json=$(echo "${args}" | jq -c '.paths // []')
    if ! paths=$(parse_paths_json "${paths_json}" ""); then
        printf '%s\n' "${paths}"
        return 1
    fi

    local body
    local gate_code=0

    if [[ -z "${paths}" ]]; then
        # No paths: the aggregate script's own targets stay authoritative and
        # only the flags are appended, exactly as before this routing existed.
        body=$(npm_script_append_gate "${aggregate}") || gate_code=$?
        if [[ "${gate_code}" -ne 0 ]]; then
            printf '%s\n' "${body}"
            return 1
        fi

        local aggregate_cmd="npm run ${aggregate} -- ${flag_string}"
        log "INFO" "Running ESLint (admin, ${aggregate}): ${aggregate_cmd}"
        exec_npm_command "${aggregate_cmd}"
        return
    fi

    local -a rebased=()
    local p
    while IFS= read -r p; do
        [[ -z "${p}" ]] && continue
        rebased+=("$(_eslint_rebase_admin_path "${p}")")
    done < <(printf '%s\n' "${paths_json}" | jq -r '.[]')

    body=$(npm_script_append_gate "${ADMIN_ESLINT_BASE_SCRIPT}") || gate_code=$?
    if [[ "${gate_code}" -ne 0 ]]; then
        printf '%s\n' "${body}"
        printf '%s\n' "Refusing to run ${tool_name} with paths: a path-scoped run needs the target-less npm script \"${ADMIN_ESLINT_BASE_SCRIPT}\", which is unusable here. The aggregate \"${aggregate}\" script is not a substitute — its body names its own targets and npm appends arguments after them, so it would lint that whole target set on top of the requested paths rather than only the requested paths."
        return 1
    fi

    local missing_report
    if ! missing_report=$(assert_paths_lintable "." "${ADMIN_ESLINT_EXTENSIONS}" "${rebased[@]}"); then
        printf '%s\n' "${missing_report}"
        return 1
    fi

    local -a quoted=()
    for p in "${rebased[@]}"; do
        quoted+=("$(shell_quote_arg "${p}")")
    done

    local cmd="npm run ${ADMIN_ESLINT_BASE_SCRIPT} --"
    if [[ -n "${flag_string}" ]]; then
        cmd="${cmd} ${flag_string}"
    fi
    cmd="${cmd} ${quoted[*]}"

    log "INFO" "Running ESLint (admin, ${ADMIN_ESLINT_BASE_SCRIPT}): ${cmd}"

    exec_npm_command "${cmd}"
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
        stylish|*) flags+=("-f" "stylish") ;;
    esac

    [[ -n "${scoped_config}" ]] && flags+=("--config" "${scoped_config}")

    _eslint_dispatch_admin "lint" "eslint_check" "${flags[*]}" "${args}"
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

    _eslint_dispatch_admin "lint:fix" "eslint_fix" "${flags[*]}" "${args}"
}
