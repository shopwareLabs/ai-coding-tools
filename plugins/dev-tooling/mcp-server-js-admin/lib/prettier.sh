#!/usr/bin/env bash
# Prettier tool implementation for Admin Tooling MCP Server
# Provides prettier_check and prettier_fix MCP tools
#
# Two routes, selected by whether the caller supplied paths:
#   paths supplied -> the package's own Prettier binary through
#                     `npm exec --no -- prettier`, with the flags of the
#                     aggregate body ("--check", or "--write --cache") but none
#                     of its globs, so the caller's paths are the ONLY targets.
#                     A directory path is narrowed to its .js, .ts and .mjs
#                     files, the extensions those globs name.
#   paths omitted  -> the aggregate script ("format" / "format:fix"), whose
#                     body carries both the mode flag and its own glob
#                     targets, which stay authoritative.
# Why the aggregate never serves a path-scoped run: shared/js_paths.sh.

ADMIN_PRETTIER_BINARY="prettier"
# The extensions the `format` and `format:fix` globs name: `{js,ts}` and `ts`
# under src, test, scripts and build, `extension-tooling/**/*.mjs`,
# build/plugins.vite.ts and build.ts. A path that resolves to no file with one
# of them formats nothing and still exits 0.
ADMIN_PRETTIER_EXTENSIONS="js ts mjs"
ADMIN_PRETTIER_DIRECTORY_GLOB="**/*.{js,ts,mjs}"

# Run one Prettier invocation for this tool.
# Args: $1 = aggregate npm script used when no paths are supplied,
#       $2 = tool name, for the refusal message,
#       $3 = flags for the path-scoped route: the aggregate body's flags
#            without its globs ("--check", or "--write --cache"),
#       $4 = tool arguments JSON
# Stdout: Prettier output, or the failure message
_prettier_dispatch_admin() {
    local aggregate="$1"
    local tool_name="$2"
    local mode_flags="$3"
    local args="$4"

    local scoped_config
    if ! scoped_config=$(scope_get_tool_field prettier config 2>&1); then
        printf '%s\n' "${scoped_config}"
        return 1
    fi

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

    local targets
    if ! targets=$(js_path_scoped_targets "${tool_name}" "${ADMIN_PRETTIER_BINARY}" "${aggregate}" \
        "${ADMIN_PRETTIER_EXTENSIONS}" "${ADMIN_PRETTIER_DIRECTORY_GLOB}" "Prettier" "${paths_json}"); then
        printf '%s\n' "${targets}"
        return 1
    fi

    local cmd="npm exec --no -- ${ADMIN_PRETTIER_BINARY} ${mode_flags}"
    if [[ -n "${scoped_config}" ]]; then
        cmd="${cmd} --config ${scoped_config}"
    fi
    cmd="${cmd} ${targets}"

    log "INFO" "Running Prettier (admin, npm exec): ${cmd}"

    exec_npm_command "${cmd}"
}

# Prettier check (dry-run)
# Args: JSON with paths (optional), scope (optional)
tool_prettier_check() {
    local args="${1:-}"

    worktree_enter "${args}" || return 1

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    worktree_assert_dependencies || return 1

    _prettier_dispatch_admin "format" "prettier_check" "--check" "${args}"
}

# Prettier fix (auto-format files)
# Args: JSON with paths (optional), scope (optional)
tool_prettier_fix() {
    local args="${1:-}"

    worktree_enter "${args}" || return 1

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    worktree_assert_dependencies || return 1

    # "--cache" is in the "format:fix" body; the "format" body has none.
    _prettier_dispatch_admin "format:fix" "prettier_fix" "--write --cache" "${args}"
}
