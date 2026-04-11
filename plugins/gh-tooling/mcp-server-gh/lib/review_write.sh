#!/usr/bin/env bash
# Review write tools for gh-tooling MCP server (write operations)
# Tools: pr_review, pr_comment, pr_review_comment

# Submit a review on a pull request.
# Maps to: gh pr review <number> --approve|--request-changes|--comment [--body ...] [--repo ...]
tool_pr_review() {
    local args="$1"

    local number event body repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    event=$(echo "${args}" | jq -r '.event // "comment"')
    body=$(echo "${args}" | jq -r '.body // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_review"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    if [[ "${event}" != "approve" && "${event}" != "request_changes" && "${event}" != "comment" ]]; then
        echo "Error: event must be one of: approve, request_changes, comment"
        return 1
    fi

    if [[ "${event}" == "request_changes" && -z "${body}" ]]; then
        echo "Error: body is required when event is request_changes"
        return 1
    fi

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "pr" "review" "${number}")

    case "${event}" in
        approve)          cmd+=("--approve") ;;
        request_changes)  cmd+=("--request-changes") ;;
        comment)          cmd+=("--comment") ;;
    esac

    [[ -n "${body}" ]] && cmd+=("--body" "${body}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "pr_review: ${cmd[*]}"
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

# Add a general comment to a pull request.
# Maps to: gh pr comment <number> --body ... [--repo ...]
tool_pr_comment() {
    local args="$1"

    local number body repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    body=$(echo "${args}" | jq -r '.body // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_comment"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    if [[ -z "${body}" ]]; then
        echo "Error: body is required for pr_comment"
        return 1
    fi

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "pr" "comment" "${number}" "--body" "${body}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "pr_comment: ${cmd[*]}"
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

# Add an inline review comment on a specific file and line in a pull request diff.
# Uses the REST API: gh api repos/{owner}/{repo}/pulls/{number}/comments -X POST
tool_pr_review_comment() {
    local args="$1"

    local number body path line side start_line repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    body=$(echo "${args}" | jq -r '.body // empty')
    path=$(echo "${args}" | jq -r '.path // empty')
    line=$(echo "${args}" | jq -r '.line // empty')
    side=$(echo "${args}" | jq -r '.side // "RIGHT"')
    start_line=$(echo "${args}" | jq -r '.start_line // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_review_comment"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    if [[ -z "${body}" ]]; then
        echo "Error: body is required for pr_review_comment"
        return 1
    fi

    if [[ -z "${path}" ]]; then
        echo "Error: path is required for pr_review_comment"
        return 1
    fi

    if [[ -z "${line}" ]]; then
        echo "Error: line is required for pr_review_comment"
        return 1
    fi
    _gh_validate_number "${line}" "line" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local endpoint="repos/${effective_repo}/pulls/${number}/comments"

    local -a cmd=("gh" "api" "${endpoint}" "-X" "POST"
        "-f" "body=${body}"
        "-f" "path=${path}"
        "-F" "line=${line}"
        "-f" "side=${side}"
    )

    [[ -n "${start_line}" ]] && cmd+=("-F" "start_line=${start_line}")

    log "INFO" "pr_review_comment: ${cmd[*]}"
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
