#!/usr/bin/env bash
# Commit tools for gh-tooling MCP server
# Tools: commit_info

# Get details for a specific commit including changed files and commit message.
# Maps to: gh api repos/{repo}/commits/{sha} [--jq <filter>]
# Common use: get the list of files changed in a commit, or look up which PRs
# are associated with a commit via repos/{repo}/commits/{sha}/pulls.
tool_commit_info() {
    local args="$1"

    local sha repo fields jq_filter include_pulls suppress_errors fallback
    sha=$(echo "${args}" | jq -r '.sha // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    fields=$(echo "${args}" | jq -r '.fields // "files_and_message"')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    include_pulls=$(echo "${args}" | jq -r '.include_pulls // false')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${sha}" ]]; then
        echo "Error: sha is required for commit_info"
        return 1
    fi
    _gh_validate_sha "${sha}" || return 1
    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local effective_jq
    if [[ -n "${jq_filter}" ]]; then
        effective_jq="${jq_filter}"
    else
        case "${fields}" in
            files)
                effective_jq='{files: [.files[].filename]}'
                ;;
            message)
                effective_jq='.commit.message'
                ;;
            files_and_message|*)
                effective_jq='{files: [.files[].filename], message: .commit.message}'
                ;;
        esac
    fi

    local -a cmd=("gh" "api" "repos/${effective_repo}/commits/${sha}" "--jq" "${effective_jq}")

    log "INFO" "commit_info: ${cmd[*]}"
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

    if [[ "${include_pulls}" == "true" ]]; then
        echo ""
        echo "--- Associated Pull Requests ---"
        local -a pulls_cmd=("gh" "api" "repos/${effective_repo}/commits/${sha}/pulls" "--jq" '.[].html_url')
        log "INFO" "commit_info (pulls): ${pulls_cmd[*]}"
        "${pulls_cmd[@]}" 2>&1 || echo "(no associated PRs found)"
    fi
}
