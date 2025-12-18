#!/usr/bin/env bash
# Jest tool implementation for Storefront Tooling MCP Server
# Provides jest_run MCP tool
# Note: watch mode is not supported - long-running processes hang MCP servers

# Jest test runner
# Args: JSON with testPathPattern (optional), testNamePattern (optional),
#       coverage (optional), updateSnapshots (optional)
tool_jest_run() {
    local args="$1"

    local test_path_pattern
    test_path_pattern=$(echo "${args}" | jq -r '.testPathPattern // empty')

    local test_name_pattern
    test_name_pattern=$(echo "${args}" | jq -r '.testNamePattern // empty')

    local coverage
    coverage=$(echo "${args}" | jq -r '.coverage // false')

    local update_snapshots
    update_snapshots=$(echo "${args}" | jq -r '.updateSnapshots // false')

    local -a flags=()

    [[ -n "${test_path_pattern}" ]] && flags+=("--testPathPattern='${test_path_pattern}'")
    [[ -n "${test_name_pattern}" ]] && flags+=("--testNamePattern='${test_name_pattern}'")
    [[ "${coverage}" == "true" ]] && flags+=("--coverage")
    [[ "${update_snapshots}" == "true" ]] && flags+=("--updateSnapshot")

    local cmd="npm run unit"
    if [[ ${#flags[@]} -gt 0 ]]; then
        cmd="${cmd} -- ${flags[*]}"
    fi

    log "INFO" "Running Jest tests (storefront): ${cmd}"

    exec_npm_command "${cmd}"
}
