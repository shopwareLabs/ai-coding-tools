#!/usr/bin/env bash
# GitHub Actions job tools for gh-tooling MCP server
# Tools: job_view, job_logs, job_annotations

# Get details for a specific GitHub Actions job including steps and their status.
# Maps to: gh api repos/{repo}/actions/jobs/{job_id}
tool_job_view() {
    local args="$1"

    local job_id repo jq_filter suppress_errors fallback
    job_id=$(echo "${args}" | jq -r '.job_id // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${job_id}" ]]; then
        echo "Error: job_id is required for job_view"
        return 1
    fi
    _gh_validate_number "${job_id}" "job_id" || return 1
    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local -a cmd=("gh" "api" "repos/${effective_repo}/actions/jobs/${job_id}")
    [[ -n "${jq_filter}" ]] && cmd+=("--jq" "${jq_filter}")

    log "INFO" "job_view: ${cmd[*]}"
    local __raw __exit=0
    if [[ "${suppress_errors}" == "true" ]]; then
        __raw=$("${cmd[@]}" 2>/dev/null) || __exit=$?
    else
        __raw=$("${cmd[@]}" 2>&1) || __exit=$?
    fi
    if [[ ${__exit} -ne 0 ]]; then
        [[ -n "${fallback}" ]] && { echo "${fallback}"; return 0; }
        echo "${__raw}"; return ${__exit}
    fi
    echo "${__raw}"
}

# Get the raw log output for a specific GitHub Actions job.
# Maps to: gh api repos/{repo}/actions/jobs/{job_id}/logs
# Optional max_lines/tail_lines/grep to filter very large log output.
tool_job_logs() {
    local args="$1"

    local job_id repo max_lines tail_lines suppress_errors fallback
    local grep_pattern grep_context_before grep_context_after grep_ignore_case grep_invert
    job_id=$(echo "${args}" | jq -r '.job_id // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')
    tail_lines=$(echo "${args}" | jq -r '.tail_lines // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    grep_pattern=$(echo "${args}" | jq -r '.grep_pattern // empty')
    grep_context_before=$(echo "${args}" | jq -r '.grep_context_before // 0')
    grep_context_after=$(echo "${args}" | jq -r '.grep_context_after // 0')
    grep_ignore_case=$(echo "${args}" | jq -r '.grep_ignore_case // false')
    grep_invert=$(echo "${args}" | jq -r '.grep_invert // false')

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
    local __raw __exit=0
    if [[ "${suppress_errors}" == "true" ]]; then
        __raw=$("${cmd[@]}" 2>/dev/null) || __exit=$?
    else
        __raw=$("${cmd[@]}" 2>&1) || __exit=$?
    fi
    if [[ ${__exit} -ne 0 ]]; then
        [[ -n "${fallback}" ]] && { echo "${fallback}"; return 0; }
        echo "${__raw}"; return ${__exit}
    fi
    _gh_post_process "${__raw}" "" "${grep_pattern}" "${grep_context_before}" "${grep_context_after}" "${grep_ignore_case}" "${grep_invert}" "${max_lines}" "${tail_lines}" || return $?
}

# Get check annotations (inline error/warning messages) for a check run.
# Maps to: gh api repos/{repo}/check-runs/{check_run_id}/annotations
# Useful for getting PHPStan, ESLint, or test failure details from CI.
tool_job_annotations() {
    local args="$1"

    local check_run_id repo jq_filter suppress_errors fallback
    check_run_id=$(echo "${args}" | jq -r '.check_run_id // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${check_run_id}" ]]; then
        echo "Error: check_run_id is required for job_annotations"
        return 1
    fi
    _gh_validate_number "${check_run_id}" "check_run_id" || return 1
    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local -a cmd=("gh" "api" "repos/${effective_repo}/check-runs/${check_run_id}/annotations")
    [[ -n "${jq_filter}" ]] && cmd+=("--jq" "${jq_filter}")

    log "INFO" "job_annotations: ${cmd[*]}"
    local __raw __exit=0
    if [[ "${suppress_errors}" == "true" ]]; then
        __raw=$("${cmd[@]}" 2>/dev/null) || __exit=$?
    else
        __raw=$("${cmd[@]}" 2>&1) || __exit=$?
    fi
    if [[ ${__exit} -ne 0 ]]; then
        [[ -n "${fallback}" ]] && { echo "${fallback}"; return 0; }
        echo "${__raw}"; return ${__exit}
    fi
    echo "${__raw}"
}
