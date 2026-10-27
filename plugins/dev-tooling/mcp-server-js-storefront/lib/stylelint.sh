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
#                     scope-configured config takes its place, and without
#                     one Stylelint finds the scope package's own config.
#                     A directory path is narrowed to its .scss and .css files.
#   paths omitted  -> the aggregate script ("lint:scss" / "lint:scss-fix"),
#                     whose body carries its own `./src/scss` target, which
#                     stays authoritative.
# Why the aggregate never serves a path-scoped run: shared/js_paths.sh.
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
STOREFRONT_STYLELINT_DIRECTORY_GLOB="**/*.{scss,css}"

# Run one Stylelint invocation for this tool.
# Args: $1 = aggregate npm script used when no paths are supplied,
#       $2 = tool name, for the refusal message,
#       $3 = pre-path flag string used on both routes (may be empty),
#       $4 = pre-path flag string used ONLY on the path-scoped route, for flags
#            the aggregate script already carries in its own body (may be empty),
#       $5 = tool arguments JSON,
#       $6 = scope-configured Stylelint config (may be empty)
# Stdout: linter output, or the failure message
_stylelint_dispatch_storefront() {
    local aggregate="$1"
    local tool_name="$2"
    local flag_string="$3"
    local path_only_flags="$4"
    local args="$5"
    local scoped_config="$6"

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

        js_refuse_second_config "${tool_name}" "Stylelint" "${STOREFRONT_STYLELINT_BINARY}" \
            "${aggregate}" "${body}" "${scoped_config}" || return 1

        local aggregate_cmd="npm run ${aggregate} -- ${flag_string}"
        log "INFO" "Running Stylelint (storefront, ${aggregate}): ${aggregate_cmd}"
        exec_npm_command "${aggregate_cmd}"
        return
    fi

    local targets
    if ! targets=$(js_path_scoped_targets "${tool_name}" "${STOREFRONT_STYLELINT_BINARY}" "${aggregate}" \
        "${STOREFRONT_STYLELINT_EXTENSIONS}" "${STOREFRONT_STYLELINT_DIRECTORY_GLOB}" "Stylelint" "${paths_json}"); then
        printf '%s\n' "${targets}"
        return 1
    fi

    # The "lint:scss" body's flags besides its target.
    local cmd="npm exec --no -- ${STOREFRONT_STYLELINT_BINARY}"
    # SCOPE_CWD, not the scope's Stylelint config: any scope runs outside the package holding this config.
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
    cmd="${cmd} ${targets}"

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
    scope_tool_field_or_refuse scoped_config stylelint config || return 1

    local output_format
    output_format=$(echo "${args}" | jq -r '.output_format // "string"')

    # The reporter flag is always appended, so this tool never runs bare.
    local -a flags=()

    case "${output_format}" in
        json) flags+=("-f" "json") ;;
        compact) flags+=("-f" "compact") ;;
        string|*) flags+=("-f" "string") ;;
    esac

    local config_flag
    scope_config_flag_or_refuse config_flag "Stylelint configuration" "${scoped_config}" || return 1
    [[ -n "${config_flag}" ]] && flags+=("${config_flag}")

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
    scope_tool_field_or_refuse scoped_config stylelint config || return 1

    local -a flags=()
    local config_flag
    scope_config_flag_or_refuse config_flag "Stylelint configuration" "${scoped_config}" || return 1
    [[ -n "${config_flag}" ]] && flags+=("${config_flag}")

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
