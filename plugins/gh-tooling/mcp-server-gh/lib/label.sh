#!/usr/bin/env bash
# Label tools for gh-tooling MCP server
# Read: label_list  |  Write: label_add, label_remove (added later)

# List labels for a repository.
# Maps to: gh label list [--repo owner/repo] [--search filter] --json name,description,color
tool_label_list() {
    local args="$1"

    local repo filter jq_filter suppress_errors fallback max_lines
    repo=$(echo "${args}" | jq -r '.repo // empty')
    filter=$(echo "${args}" | jq -r '.filter // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')

    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "label" "list" "--json" "name,description,color")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    if [[ -n "${filter}" ]]; then
        cmd+=("--search" "${filter}")
    fi

    log "INFO" "label_list: ${cmd[*]}"
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
    _gh_post_process "${__raw}" "" "${jq_filter}" 0 0 false false "${max_lines}" "" || return $?
}
