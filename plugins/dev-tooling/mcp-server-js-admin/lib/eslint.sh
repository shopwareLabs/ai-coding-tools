#!/usr/bin/env bash
# ESLint tool implementation for Admin Tooling MCP Server
# Provides eslint_check and eslint_fix MCP tools
#
# Two routes, selected by whether the caller supplied paths:
#   paths supplied -> the package's own ESLint binary through
#                     `npm exec --no -- eslint`, so the caller's paths are the
#                     ONLY targets.
#   paths omitted  -> the aggregate script ("lint" / "lint:fix"), whose body
#                     carries its own targets, which stay authoritative.
# Why the aggregate never serves a path-scoped run: shared/js_paths.sh.

ADMIN_ESLINT_BINARY="eslint"
# Extensions the Administration ESLint flat config can match, read off the
# `files:` globs in eslint.config.ts: **/*.js, **/*.ts, **/*.tsx, **/*.vue,
# **/*.html.twig and src/**/snippet/*.json. A path that resolves to no file
# with one of them lints nothing and still exits 0.
ADMIN_ESLINT_EXTENSIONS="js ts tsx vue json twig"

# Rebase a repo-root-relative path the caller pasted from a diff onto the npm
# working directory. Unscoped, that is the app/administration package. Under a
# scope it is the scope cwd, so only a leading "<scope cwd>/" is stripped: a
# plugin's own app/administration segment lies below that directory and stays.
# A path that carries neither prefix is passed through.
# Globals: SCOPE_CWD (read)
# Args: $1 = caller-supplied path
if ! declare -F _eslint_rebase_admin_path >/dev/null; then
    _eslint_rebase_admin_path() {
        local path="$1"
        if [[ -n "${SCOPE_CWD:-}" ]]; then
            printf '%s\n' "${path#"${SCOPE_CWD}/"}"
            return
        fi
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

    # The caller's own spelling is what is checked, before the rebase below
    # strips a package prefix off it.
    worktree_assert_paths_within_root "${paths_json}" || return 1

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

    js_assert_local_binary "${tool_name}" "${ADMIN_ESLINT_BINARY}" "${aggregate}" || return 1

    local missing_report
    if ! missing_report=$(assert_paths_lintable "." "${ADMIN_ESLINT_EXTENSIONS}" "${rebased[@]}"); then
        printf '%s\n' "${missing_report}"
        return 1
    fi

    local -a quoted=()
    for p in "${rebased[@]}"; do
        quoted+=("$(shell_quote_arg "${p}")")
    done

    local cmd="npm exec --no -- ${ADMIN_ESLINT_BINARY}"
    if [[ -n "${flag_string}" ]]; then
        cmd="${cmd} ${flag_string}"
    fi
    cmd="${cmd} ${quoted[*]}"

    log "INFO" "Running ESLint (admin, npm exec): ${cmd}"

    exec_npm_command "${cmd}"
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
    scope_tool_field_or_refuse scoped_config eslint config || return 1

    local output_format
    output_format=$(echo "${args}" | jq -r '.output_format // "stylish"')

    local -a flags=()

    case "${output_format}" in
        json) flags+=("-f" "json") ;;
        stylish|*) flags+=("-f" "stylish") ;;
    esac

    if [[ -n "${scoped_config}" ]]; then
        local guard
        if ! guard=$(assert_no_shell_hostile_chars "ESLint configuration" "${scoped_config}"); then
            printf '%s\n' "${guard}"
            return 1
        fi
        flags+=("--config" "$(shell_quote_arg "${scoped_config}")")
    fi

    _eslint_dispatch_admin "lint" "eslint_check" "${flags[*]}" "${args}"
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
    scope_tool_field_or_refuse scoped_config eslint config || return 1

    local -a flags=("--fix")
    if [[ -n "${scoped_config}" ]]; then
        local guard
        if ! guard=$(assert_no_shell_hostile_chars "ESLint configuration" "${scoped_config}"); then
            printf '%s\n' "${guard}"
            return 1
        fi
        flags+=("--config" "$(shell_quote_arg "${scoped_config}")")
    fi

    _eslint_dispatch_admin "lint:fix" "eslint_fix" "${flags[*]}" "${args}"
}
