#!/usr/bin/env bash
# Commit tools for gh-tooling MCP server
# Tools: commit_pulls

# List GitHub pull requests associated with a pushed commit SHA.
# GitHub-only — no local git equivalent.
# Maps to: gh api repos/{repo}/commits/{sha}/pulls [--jq <filter>]
tool_commit_pulls() {
    local args="$1"

    local sha repo jq_filter suppress_errors fallback
    sha=$(echo "${args}" | jq -r '.sha // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${sha}" ]]; then
        echo "Error: sha is required for commit_pulls"
        return 1
    fi
    _gh_validate_sha "${sha}" || return 1
    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local effective_jq="${jq_filter:-[.[] | {number: .number, title: .title, url: .html_url, state: .state}]}"

    local -a cmd=("gh" "api" "repos/${effective_repo}/commits/${sha}/pulls" "--jq" "${effective_jq}")

    log "INFO" "commit_pulls: ${cmd[*]}"
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
    _gh_post_process "${__raw}" "${jq_filter}" "" "" "" "" ""
}
