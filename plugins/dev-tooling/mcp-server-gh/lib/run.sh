#!/usr/bin/env bash
# GitHub Actions run tools for gh-tooling MCP server
# Tools: run_view, run_list, run_logs

# View the status and summary of a GitHub Actions workflow run.
# Maps to: gh run view <run_id> [--repo] [--json <fields>]
tool_run_view() {
    local args="$1"

    local run_id repo fields jq_filter suppress_errors fallback
    run_id=$(echo "${args}" | jq -r '.run_id // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${run_id}" ]]; then
        echo "Error: run_id is required for run_view"
        return 1
    fi
    _gh_validate_number "${run_id}" "run_id" || return 1
    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "run" "view" "${run_id}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    [[ -n "${fields}" ]] && cmd+=("--json" "${fields}")

    log "INFO" "run_view: ${cmd[*]}"
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
    _gh_post_process "${__raw}" "${jq_filter}" "" 0 0 false false "" "" || return $?
}

# List recent GitHub Actions workflow runs for a repository or branch.
# Maps to: gh run list [--repo] [--branch] [--limit] [--json]
tool_run_list() {
    local args="$1"

    local repo branch limit fields jq_filter suppress_errors fallback
    repo=$(echo "${args}" | jq -r '.repo // empty')
    branch=$(echo "${args}" | jq -r '.branch // empty')
    limit=$(echo "${args}" | jq -r '.limit // 20')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    _gh_validate_jq_filter "${jq_filter}" || return 1

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
    _gh_post_process "${__raw}" "${jq_filter}" "" 0 0 false false "" "" || return $?
}

# Get logs for a GitHub Actions workflow run. Defaults to failed steps only.
# Maps to: gh run view <run_id> --log-failed | --log [--repo]
# Optional max_lines/tail_lines/grep to filter very large log output.
tool_run_logs() {
    local args="$1"

    local run_id repo failed_only max_lines tail_lines suppress_errors fallback
    local grep_pattern grep_context_before grep_context_after grep_ignore_case grep_invert
    run_id=$(echo "${args}" | jq -r '.run_id // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    failed_only=$(echo "${args}" | jq -r '.failed_only // true')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')
    tail_lines=$(echo "${args}" | jq -r '.tail_lines // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    grep_pattern=$(echo "${args}" | jq -r '.grep_pattern // empty')
    grep_context_before=$(echo "${args}" | jq -r '.grep_context_before // 0')
    grep_context_after=$(echo "${args}" | jq -r '.grep_context_after // 0')
    grep_ignore_case=$(echo "${args}" | jq -r '.grep_ignore_case // false')
    grep_invert=$(echo "${args}" | jq -r '.grep_invert // false')

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
