#!/usr/bin/env bash
# Sub-issue tools for gh-tooling MCP server (GraphQL)
# Write: sub_issue_add, sub_issue_remove

# Helper: resolve an issue number to its GraphQL node ID.
# Args: $1=repo (owner/repo format), $2=issue_number
# Outputs: node ID string (e.g., "I_kwDOA...")
_gh_resolve_issue_node_id() {
    local repo="$1" issue_number="$2"
    local owner="${repo%%/*}"
    local repo_name="${repo##*/}"

    # shellcheck disable=SC2016  # GraphQL query variables ($owner, $repo, $number), not shell vars
    gh api graphql \
        -f query='query($owner: String!, $repo: String!, $number: Int!) {
            repository(owner: $owner, name: $repo) {
                issue(number: $number) { id }
            }
        }' \
        -f owner="${owner}" -f repo="${repo_name}" -F number="${issue_number}" \
        --jq '.data.repository.issue.id'
}

# Add a sub-issue to a parent issue.
tool_sub_issue_add() {
    local args="$1"

    local issue_number sub_issue_number repo suppress_errors fallback
    issue_number=$(printf '%s' "${args}" | jq -r '.issue_number // empty')
    sub_issue_number=$(printf '%s' "${args}" | jq -r '.sub_issue_number // empty')
    repo=$(printf '%s' "${args}" | jq -r '.repo // empty')
    suppress_errors=$(printf '%s' "${args}" | jq -r '.suppress_errors // false')
    fallback=$(printf '%s' "${args}" | jq -r '.fallback // empty')

    if [[ -z "${issue_number}" ]]; then
        printf '%s\n' "Error: issue_number is required for sub_issue_add"
        return 1
    fi
    if [[ -z "${sub_issue_number}" ]]; then
        printf '%s\n' "Error: sub_issue_number is required for sub_issue_add"
        return 1
    fi

    _gh_validate_number "${issue_number}" "issue_number" || return 1
    _gh_validate_number "${sub_issue_number}" "sub_issue_number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    if [[ -z "${effective_repo}" ]]; then
        printf '%s\n' "Error: repo is required for sub_issue_add (no default repo configured)"
        return 1
    fi

    # Resolve both issue numbers to node IDs
    local parent_id sub_id
    parent_id=$(_gh_resolve_issue_node_id "${effective_repo}" "${issue_number}" 2>&1) || {
        [[ -n "${fallback}" ]] && { printf '%s\n' "${fallback}"; return 0; }
        printf '%s\n' "Error: could not resolve issue #${issue_number}: ${parent_id}"
        return 1
    }
    sub_id=$(_gh_resolve_issue_node_id "${effective_repo}" "${sub_issue_number}" 2>&1) || {
        [[ -n "${fallback}" ]] && { printf '%s\n' "${fallback}"; return 0; }
        printf '%s\n' "Error: could not resolve issue #${sub_issue_number}: ${sub_id}"
        return 1
    }

    log "INFO" "sub_issue_add: parent=${parent_id} sub=${sub_id}"

    local -a cmd=("gh" "api" "graphql"
        "-H" "GraphQL-Features: sub_issues"
        "-f" "query=mutation(\$issueId: ID!, \$subIssueId: ID!) { addSubIssue(input: {issueId: \$issueId, subIssueId: \$subIssueId}) { issue { number title } subIssue { number title } } }"
        "-f" "issueId=${parent_id}"
        "-f" "subIssueId=${sub_id}"
    )

    local __raw __exit=0
    if [[ "${suppress_errors}" == "true" ]]; then
        __raw=$("${cmd[@]}" 2>/dev/null) || __exit=$?
    else
        __raw=$("${cmd[@]}" 2>&1) || __exit=$?
    fi
    if [[ ${__exit} -ne 0 ]]; then
        [[ -n "${fallback}" ]] && { printf '%s\n' "${fallback}"; return 0; }
        printf '%s\n' "${__raw}"; return ${__exit}
    fi
    printf '%s\n' "${__raw}"
}

# Remove a sub-issue from a parent issue.
tool_sub_issue_remove() {
    local args="$1"

    local issue_number sub_issue_number repo suppress_errors fallback
    issue_number=$(printf '%s' "${args}" | jq -r '.issue_number // empty')
    sub_issue_number=$(printf '%s' "${args}" | jq -r '.sub_issue_number // empty')
    repo=$(printf '%s' "${args}" | jq -r '.repo // empty')
    suppress_errors=$(printf '%s' "${args}" | jq -r '.suppress_errors // false')
    fallback=$(printf '%s' "${args}" | jq -r '.fallback // empty')

    if [[ -z "${issue_number}" ]]; then
        printf '%s\n' "Error: issue_number is required for sub_issue_remove"
        return 1
    fi
    if [[ -z "${sub_issue_number}" ]]; then
        printf '%s\n' "Error: sub_issue_number is required for sub_issue_remove"
        return 1
    fi

    _gh_validate_number "${issue_number}" "issue_number" || return 1
    _gh_validate_number "${sub_issue_number}" "sub_issue_number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    if [[ -z "${effective_repo}" ]]; then
        printf '%s\n' "Error: repo is required for sub_issue_remove (no default repo configured)"
        return 1
    fi

    local parent_id sub_id
    parent_id=$(_gh_resolve_issue_node_id "${effective_repo}" "${issue_number}" 2>&1) || {
        [[ -n "${fallback}" ]] && { printf '%s\n' "${fallback}"; return 0; }
        printf '%s\n' "Error: could not resolve issue #${issue_number}: ${parent_id}"
        return 1
    }
    sub_id=$(_gh_resolve_issue_node_id "${effective_repo}" "${sub_issue_number}" 2>&1) || {
        [[ -n "${fallback}" ]] && { printf '%s\n' "${fallback}"; return 0; }
        printf '%s\n' "Error: could not resolve issue #${sub_issue_number}: ${sub_id}"
        return 1
    }

    log "INFO" "sub_issue_remove: parent=${parent_id} sub=${sub_id}"

    local -a cmd=("gh" "api" "graphql"
        "-H" "GraphQL-Features: sub_issues"
        "-f" "query=mutation(\$issueId: ID!, \$subIssueId: ID!) { removeSubIssue(input: {issueId: \$issueId, subIssueId: \$subIssueId}) { issue { number title } subIssue { number title } } }"
        "-f" "issueId=${parent_id}"
        "-f" "subIssueId=${sub_id}"
    )

    local __raw __exit=0
    if [[ "${suppress_errors}" == "true" ]]; then
        __raw=$("${cmd[@]}" 2>/dev/null) || __exit=$?
    else
        __raw=$("${cmd[@]}" 2>&1) || __exit=$?
    fi
    if [[ ${__exit} -ne 0 ]]; then
        [[ -n "${fallback}" ]] && { printf '%s\n' "${fallback}"; return 0; }
        printf '%s\n' "${__raw}"; return ${__exit}
    fi
    printf '%s\n' "${__raw}"
}
