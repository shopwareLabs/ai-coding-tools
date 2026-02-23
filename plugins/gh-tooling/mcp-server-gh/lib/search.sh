#!/usr/bin/env bash
# Search tools for gh-tooling MCP server
# Tools: search

# Search for GitHub issues or pull requests using a query string.
# Maps to: gh search issues|prs <query> [--repo] [--state] [--limit] [--json]
# Also supports the low-level: gh api search/issues -X GET -f q="..." -f per_page=N
tool_search() {
    local args="$1"

    local query type repo state limit fields jq_filter suppress_errors fallback
    query=$(echo "${args}" | jq -r '.query // empty')
    type=$(echo "${args}" | jq -r '.type // "prs"')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    state=$(echo "${args}" | jq -r '.state // empty')
    limit=$(echo "${args}" | jq -r '.limit // 20')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${query}" ]]; then
        echo "Error: query is required for search"
        return 1
    fi

    if [[ "${type}" != "issues" && "${type}" != "prs" ]]; then
        echo "Error: type must be 'issues' or 'prs', got: '${type}'"
        return 1
    fi

    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    _gh_validate_number "${limit}" "limit" || return 1

    local -a cmd=("gh" "search" "${type}" "${query}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    [[ -n "${state}" ]] && cmd+=("--state" "${state}")
    cmd+=("--limit" "${limit}")
    [[ -n "${fields}" ]] && cmd+=("--json" "${fields}")

    log "INFO" "search: ${cmd[*]}"
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
