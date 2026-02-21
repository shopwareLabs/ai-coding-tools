#!/usr/bin/env bash
# GitHub Actions job tools for gh-tooling MCP server
# Tools: job_view, job_logs, job_annotations

# Get details for a specific GitHub Actions job including steps and their status.
# Maps to: gh api repos/{repo}/actions/jobs/{job_id}
tool_job_view() {
    local args="$1"

    local job_id repo jq_filter
    job_id=$(echo "${args}" | jq -r '.job_id // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')

    if [[ -z "${job_id}" ]]; then
        echo "Error: job_id is required for job_view"
        return 1
    fi
    _gh_validate_number "${job_id}" "job_id" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local -a cmd=("gh" "api" "repos/${effective_repo}/actions/jobs/${job_id}")
    [[ -n "${jq_filter}" ]] && cmd+=("--jq" "${jq_filter}")

    log "INFO" "job_view: ${cmd[*]}"
    "${cmd[@]}" 2>&1
}

# Get the raw log output for a specific GitHub Actions job.
# Maps to: gh api repos/{repo}/actions/jobs/{job_id}/logs
# Optional max_lines to truncate very large log output.
tool_job_logs() {
    local args="$1"

    local job_id repo max_lines
    job_id=$(echo "${args}" | jq -r '.job_id // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')

    if [[ -z "${job_id}" ]]; then
        echo "Error: job_id is required for job_logs"
        return 1
    fi
    _gh_validate_number "${job_id}" "job_id" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local -a cmd=("gh" "api" "repos/${effective_repo}/actions/jobs/${job_id}/logs")

    log "INFO" "job_logs: ${cmd[*]}"

    if [[ -n "${max_lines}" ]]; then
        _gh_validate_number "${max_lines}" "max_lines" || return 1
        "${cmd[@]}" 2>&1 | head -n "${max_lines}"
    else
        "${cmd[@]}" 2>&1
    fi
}

# Get check annotations (inline error/warning messages) for a check run.
# Maps to: gh api repos/{repo}/check-runs/{check_run_id}/annotations
# Useful for getting PHPStan, ESLint, or test failure details from CI.
tool_job_annotations() {
    local args="$1"

    local check_run_id repo jq_filter
    check_run_id=$(echo "${args}" | jq -r '.check_run_id // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')

    if [[ -z "${check_run_id}" ]]; then
        echo "Error: check_run_id is required for job_annotations"
        return 1
    fi
    _gh_validate_number "${check_run_id}" "check_run_id" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local -a cmd=("gh" "api" "repos/${effective_repo}/check-runs/${check_run_id}/annotations")
    [[ -n "${jq_filter}" ]] && cmd+=("--jq" "${jq_filter}")

    log "INFO" "job_annotations: ${cmd[*]}"
    "${cmd[@]}" 2>&1
}
