#!/usr/bin/env bash
# Prettier tool implementation for Admin Tooling MCP Server
# Provides prettier_check and prettier_fix MCP tools
#
# Two routes, selected by whether the caller supplied paths:
#   paths supplied -> npm script "prettier:base", whose body is a bare
#                     `prettier`, so the caller's paths are the ONLY targets
#                     and the mode flag (--check / --write) comes from here.
#   paths omitted  -> the aggregate script ("format" / "format:fix"), whose
#                     body carries both the mode flag and its own glob
#                     targets, which stay authoritative.
# The aggregate is never a fallback for a path-scoped run. npm appends `--`
# arguments to the END of the whole script body, so appending a path to a body
# that already names `src/**/*.{js,ts}` and friends widens the run to those
# globs PLUS the path — it can never narrow it. That matters most for
# prettier_fix, which writes: a widened fix reformats files nobody named.

ADMIN_PRETTIER_BASE_SCRIPT="prettier:base"
# Extensions Prettier is pointed at here, read off the globs in the `format`
# script body: src/**/*.{js,ts}, test/**/*.{js,ts},
# build/vite-plugins/**/*.{js,ts}, build/plugins.vite.ts and build.ts. A path
# that resolves to no file with one of them formats nothing and still exits 0.
ADMIN_PRETTIER_EXTENSIONS="js ts"

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

# Run one Prettier invocation for this tool.
# Args: $1 = aggregate npm script used when no paths are supplied,
#       $2 = tool name, for the refusal message,
#       $3 = mode flag for the path-scoped route (--check or --write),
#       $4 = tool arguments JSON
# Stdout: Prettier output, or the failure message
_prettier_dispatch_admin() {
    local aggregate="$1"
    local tool_name="$2"
    local mode_flag="$3"
    local args="$4"

    local scoped_config
    scoped_config=$(scope_get_tool_field prettier config)

    local paths_json paths
    paths_json=$(echo "${args}" | jq -c '.paths // []')
    if ! paths=$(parse_paths_json "${paths_json}" ""); then
        printf '%s\n' "${paths}"
        return 1
    fi

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

    body=$(npm_script_append_gate "${ADMIN_PRETTIER_BASE_SCRIPT}") || gate_code=$?
    if [[ "${gate_code}" -ne 0 ]]; then
        printf '%s\n' "${body}"
        printf '%s\n' "Refusing to run ${tool_name} with paths: a path-scoped run needs the target-less npm script \"${ADMIN_PRETTIER_BASE_SCRIPT}\", which is unusable here. The aggregate \"${aggregate}\" script is not a substitute — its body names its own glob targets and npm appends arguments after them, so it would cover that whole target set on top of the requested paths rather than only the requested paths."
        return 1
    fi

    if [[ ${#literals[@]} -gt 0 ]]; then
        local missing_report
        if ! missing_report=$(assert_paths_lintable "." "${ADMIN_PRETTIER_EXTENSIONS}" "${literals[@]}"); then
            printf '%s\n' "${missing_report}"
            return 1
        fi
    fi

    local -a quoted=()
    for p in "${supplied[@]}"; do
        quoted+=("$(shell_quote_arg "${p}")")
    done

    local cmd="npm run ${ADMIN_PRETTIER_BASE_SCRIPT} -- ${mode_flag}"
    if [[ -n "${scoped_config}" ]]; then
        cmd="${cmd} --config ${scoped_config}"
    fi
    cmd="${cmd} ${quoted[*]}"

    log "INFO" "Running Prettier (admin, ${ADMIN_PRETTIER_BASE_SCRIPT}): ${cmd}"

    exec_npm_command "${cmd}"
}

# Prettier check (dry-run)
# Args: JSON with paths (optional), scope (optional)
tool_prettier_check() {
    local args="${1:-}"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    _prettier_dispatch_admin "format" "prettier_check" "--check" "${args}"
}

# Prettier fix (auto-format files)
# Args: JSON with paths (optional), scope (optional)
tool_prettier_fix() {
    local args="${1:-}"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    _prettier_dispatch_admin "format:fix" "prettier_fix" "--write" "${args}"
}
