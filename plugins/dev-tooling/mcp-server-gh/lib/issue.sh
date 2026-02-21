#!/usr/bin/env bash
# Issue tools for gh-tooling MCP server
# Tools: issue_view, issue_list

# View a GitHub issue with optional comments.
# Maps to: gh issue view <number> [--repo owner/repo] [--json <fields>] [--comments]
tool_issue_view() {
    local args="$1"

    local number repo fields with_comments jq_filter suppress_errors fallback max_lines
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    with_comments=$(echo "${args}" | jq -r '.with_comments // false')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for issue_view"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1
    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "issue" "view" "${number}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    if [[ -n "${fields}" ]]; then
        cmd+=("--json" "${fields}")
    elif [[ "${with_comments}" == "true" ]]; then
        cmd+=("--comments")
    fi

    log "INFO" "issue_view: ${cmd[*]}"
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
    _gh_post_process "${__raw}" "${jq_filter}" "" 0 0 false false "${max_lines}" "" || return $?
}

# List issues with optional filters.
# Maps to: gh issue list [--repo] [--search] [--state] [--label] [--limit] [--json]
tool_issue_list() {
    local args="$1"

    local repo search state label limit fields jq_filter suppress_errors fallback
    repo=$(echo "${args}" | jq -r '.repo // empty')
    search=$(echo "${args}" | jq -r '.search // empty')
    state=$(echo "${args}" | jq -r '.state // empty')
    label=$(echo "${args}" | jq -r '.label // empty')
    limit=$(echo "${args}" | jq -r '.limit // 20')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "issue" "list")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    [[ -n "${search}" ]] && cmd+=("--search" "${search}")
    [[ -n "${state}" ]] && cmd+=("--state" "${state}")
    [[ -n "${label}" ]] && cmd+=("--label" "${label}")
    _gh_validate_number "${limit}" "limit" || return 1
    cmd+=("--limit" "${limit}")
    [[ -n "${fields}" ]] && cmd+=("--json" "${fields}")

    log "INFO" "issue_list: ${cmd[*]}"
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
