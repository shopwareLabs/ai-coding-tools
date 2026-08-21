#!/usr/bin/env bash
# Vitest tool implementation for Storefront Tooling MCP Server
# Provides vitest_run MCP tool
#
# Storefront component tests live under
# src/Storefront/Resources/views/components/**/*.test.{js,ts} and are collected
# by Vitest only; Jest never sees them. Note: watch mode is not supported -
# long-running processes hang MCP servers.

VITEST_COMPONENTS_BASE="../.."

# Rebase a components-tree path onto src/Storefront/Resources.
# Accepts the repo-root-relative form, the tree-relative form, and a path that
# already carries a package prefix.
# Args: $1 = caller-supplied path
_vitest_rebase_component_path() {
    local path="$1"
    if [[ "${path}" == *"views/components/"* || "${path}" == *"views/components" ]]; then
        printf '%s\n' "views/components${path#*views/components}"
        return
    fi
    printf '%s\n' "${path}"
}

# Vitest test runner for Storefront components
# Args: JSON with paths (optional), testNamePattern (optional),
#       coverage (optional), updateSnapshots (optional), scope (optional)
tool_vitest_run() {
    local args="$1"

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi

    SCOPE_JS_SUBDIR=""
    if [[ "${SCOPE_NAME}" != "shopware" ]]; then
        # shellcheck disable=SC2034  # consumed by shared/environment.sh (get_js_workdir) via dynamic scope
        SCOPE_JS_SUBDIR=$(scope_get_tool_field jest cwd)
    fi

    local coverage
    coverage=$(echo "${args}" | jq -r '.coverage // false')

    local script="unit:components"
    if [[ "${coverage}" == "true" ]]; then
        script="unit:components:coverage"
    fi

    local test_name_pattern
    test_name_pattern=$(echo "${args}" | jq -r '.testNamePattern // empty')

    local update_snapshots
    update_snapshots=$(echo "${args}" | jq -r '.updateSnapshots // false')

    local guard
    if [[ -n "${test_name_pattern}" ]] && ! guard=$(assert_no_shell_hostile_chars "test name pattern" "${test_name_pattern}"); then
        printf '%s\n' "${guard}"
        return 1
    fi

    local -a flags=()
    [[ -n "${test_name_pattern}" ]] && flags+=("-t" "$(shell_quote_arg "${test_name_pattern}")")
    [[ "${update_snapshots}" == "true" ]] && flags+=("-u")

    local paths_json paths
    paths_json=$(echo "${args}" | jq -c '.paths // []')
    if ! paths=$(parse_paths_json "${paths_json}" ""); then
        printf '%s\n' "${paths}"
        return 1
    fi

    if [[ ${#flags[@]} -eq 0 && -z "${paths}" ]]; then
        local bare_cmd="npm run ${script}"
        log "INFO" "Running Vitest (storefront components): ${bare_cmd}"
        exec_npm_command "${bare_cmd}"
        return
    fi

    local body
    local gate_code=0
    body=$(npm_script_append_gate "${script}") || gate_code=$?
    if [[ "${gate_code}" -ne 0 ]]; then
        printf '%s\n' "${body}"
        return 1
    fi

    local -a filters=()
    if [[ -n "${paths}" ]]; then
        local p
        while IFS= read -r p; do
            [[ -z "${p}" ]] && continue
            filters+=("$(_vitest_rebase_component_path "${p}")")
        done < <(printf '%s\n' "${paths_json}" | jq -r '.[]')

        local missing_report
        if ! missing_report=$(assert_paths_exist "${VITEST_COMPONENTS_BASE}" "${filters[@]}"); then
            printf '%s\n' "${missing_report}"
            return 1
        fi
    fi

    local cmd="npm run ${script} --"
    if [[ ${#flags[@]} -gt 0 ]]; then
        cmd="${cmd} ${flags[*]}"
    fi

    local f
    for f in "${filters[@]+"${filters[@]}"}"; do
        cmd="${cmd} $(shell_quote_arg "${f}")"
    done

    log "INFO" "Running Vitest (storefront components): ${cmd}"

    exec_npm_command "${cmd}"
}
