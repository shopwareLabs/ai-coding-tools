#!/usr/bin/env bash
# Stylelint tool implementation for Storefront Tooling MCP Server
# Provides stylelint_check and stylelint_fix MCP tools
#
# Two routes, selected by whether the caller supplied paths:
#   paths supplied -> npm script "stylelint:app", whose body is a target-less
#                     `stylelint --config stylelint.config.js --cache`, so the
#                     caller's paths are the ONLY targets.
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
# one; "stylelint:app" carries none, so the path-scoped route must add it or
# stylelint_fix silently runs as a check and writes nothing.

STOREFRONT_STYLELINT_BASE_SCRIPT="stylelint:app"
# Extensions Stylelint reads here. Neither stylelint.config.js nor the CLI
# restricts the set, so this is the pair the SCSS rulesets actually parse. A
# path that resolves to no file with one of them lints nothing and still
# exits 0.
STOREFRONT_STYLELINT_EXTENSIONS="scss css"

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

# Run one Stylelint invocation for this tool.
# Args: $1 = aggregate npm script used when no paths are supplied,
#       $2 = tool name, for the refusal message,
#       $3 = pre-path flag string used on both routes (may be empty),
#       $4 = pre-path flag string used ONLY on the path-scoped route, for flags
#            the aggregate script already carries in its own body (may be empty),
#       $5 = tool arguments JSON
# Stdout: linter output, or the failure message
_stylelint_dispatch_storefront() {
    local aggregate="$1"
    local tool_name="$2"
    local flag_string="$3"
    local path_only_flags="$4"
    local args="$5"

    local paths_json paths
    paths_json=$(echo "${args}" | jq -c '.paths // []')
    if ! paths=$(parse_paths_json "${paths_json}" ""); then
        printf '%s\n' "${paths}"
        return 1
    fi

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

    body=$(npm_script_append_gate "${STOREFRONT_STYLELINT_BASE_SCRIPT}") || gate_code=$?
    if [[ "${gate_code}" -ne 0 ]]; then
        printf '%s\n' "${body}"
        printf '%s\n' "Refusing to run ${tool_name} with paths: a path-scoped run needs the target-less npm script \"${STOREFRONT_STYLELINT_BASE_SCRIPT}\", which is unusable here. The aggregate \"${aggregate}\" script is not a substitute — its body names its own targets and npm appends arguments after them, so it would cover that whole target set on top of the requested paths rather than only the requested paths."
        return 1
    fi

    if [[ ${#literals[@]} -gt 0 ]]; then
        local missing_report
        if ! missing_report=$(assert_paths_lintable "." "${STOREFRONT_STYLELINT_EXTENSIONS}" "${literals[@]}"); then
            printf '%s\n' "${missing_report}"
            return 1
        fi
    fi

    local -a quoted=()
    for p in "${supplied[@]}"; do
        quoted+=("$(shell_quote_arg "${p}")")
    done

    # The base script's body carries no mode flag of its own, so anything the
    # aggregate would have supplied has to be added here instead.
    local path_flags="${flag_string}"
    if [[ -n "${path_only_flags}" ]]; then
        if [[ -n "${path_flags}" ]]; then
            path_flags="${path_flags} ${path_only_flags}"
        else
            path_flags="${path_only_flags}"
        fi
    fi

    local cmd="npm run ${STOREFRONT_STYLELINT_BASE_SCRIPT} --"
    if [[ -n "${path_flags}" ]]; then
        cmd="${cmd} ${path_flags}"
    fi
    cmd="${cmd} ${quoted[*]}"

    log "INFO" "Running Stylelint (storefront, ${STOREFRONT_STYLELINT_BASE_SCRIPT}): ${cmd}"

    exec_npm_command "${cmd}"
}

# Stylelint check (dry-run)
# Args: JSON with paths (optional), output_format (optional), scope (optional)
tool_stylelint_check() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
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

    _stylelint_dispatch_storefront "lint:scss" "stylelint_check" "${flags[*]}" "" "${args}"
}

# Stylelint fix (auto-fix violations)
# Args: JSON with paths (optional), scope (optional)
tool_stylelint_fix() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
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
    _stylelint_dispatch_storefront "lint:scss-fix" "stylelint_fix" "${flag_string}" "--fix" "${args}"
}
