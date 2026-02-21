#!/usr/bin/env bash
# GitHub Actions run tools for gh-tooling MCP server
# Tools: run_view, run_list, run_logs

# View the status and summary of a GitHub Actions workflow run.
# Maps to: gh run view <run_id> [--repo] [--json <fields>]
tool_run_view() {
    local args="$1"

    local run_id repo fields
    run_id=$(echo "${args}" | jq -r '.run_id // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    fields=$(echo "${args}" | jq -r '.fields // empty')

    if [[ -z "${run_id}" ]]; then
        echo "Error: run_id is required for run_view"
        return 1
    fi
    _gh_validate_number "${run_id}" "run_id" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "run" "view" "${run_id}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    [[ -n "${fields}" ]] && cmd+=("--json" "${fields}")

    log "INFO" "run_view: ${cmd[*]}"
    "${cmd[@]}" 2>&1
}

# List recent GitHub Actions workflow runs for a repository or branch.
# Maps to: gh run list [--repo] [--branch] [--limit] [--json]
tool_run_list() {
    local args="$1"

    local repo branch limit fields
    repo=$(echo "${args}" | jq -r '.repo // empty')
    branch=$(echo "${args}" | jq -r '.branch // empty')
    limit=$(echo "${args}" | jq -r '.limit // 20')
    fields=$(echo "${args}" | jq -r '.fields // empty')

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "run" "list")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    [[ -n "${branch}" ]] && cmd+=("--branch" "${branch}")
    _gh_validate_number "${limit}" "limit" || return 1
    cmd+=("--limit" "${limit}")
    [[ -n "${fields}" ]] && cmd+=("--json" "${fields}")

    log "INFO" "run_list: ${cmd[*]}"
    "${cmd[@]}" 2>&1
}

# Get logs for a GitHub Actions workflow run. Defaults to failed steps only.
# Maps to: gh run view <run_id> --log-failed | --log [--repo]
# Optional max_lines to truncate very large log output.
tool_run_logs() {
    local args="$1"

    local run_id repo failed_only max_lines
    run_id=$(echo "${args}" | jq -r '.run_id // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    failed_only=$(echo "${args}" | jq -r '.failed_only // true')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')

    if [[ -z "${run_id}" ]]; then
        echo "Error: run_id is required for run_logs"
        return 1
    fi
    _gh_validate_number "${run_id}" "run_id" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "run" "view" "${run_id}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    if [[ "${failed_only}" == "false" ]]; then
        cmd+=("--log")
    else
        cmd+=("--log-failed")
    fi

    log "INFO" "run_logs: ${cmd[*]}"

    if [[ -n "${max_lines}" ]]; then
        _gh_validate_number "${max_lines}" "max_lines" || return 1
        "${cmd[@]}" 2>&1 | head -n "${max_lines}"
    else
        "${cmd[@]}" 2>&1
    fi
}
