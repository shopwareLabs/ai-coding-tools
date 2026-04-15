#!/usr/bin/env bash
# Review write tools for gh-tooling MCP server (write operations)
# Tools: pr_review_submit, pr_comment, pr_review_reply

# Submit a review on a pull request, optionally with inline comments.
#
# Two execution paths:
#   A. No comments          → `gh pr review <num> --approve|--request-changes|--comment [--body ...]`
#   B. With inline comments → `gh api repos/.../pulls/<num>/reviews -X POST --input -`
#      (commit_id auto-fetched from PR head if not provided)
tool_pr_review_submit() {
    local args="$1"

    local number event body commit_id comments_json repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    event=$(echo "${args}" | jq -r '.event // "comment"')
    body=$(echo "${args}" | jq -r '.body // empty')
    commit_id=$(echo "${args}" | jq -r '.commit_id // empty')
    comments_json=$(echo "${args}" | jq -c '.comments // []')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_review_submit"
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

    local comments_count
    comments_count=$(echo "${comments_json}" | jq 'length')

    # Path A: no inline comments → plain `gh pr review` submit.
    if [[ "${comments_count}" -eq 0 ]]; then
        local -a cmd=("gh" "pr" "review" "${number}")
        case "${event}" in
            approve)         cmd+=("--approve") ;;
            request_changes) cmd+=("--request-changes") ;;
            comment)         cmd+=("--comment") ;;
        esac
        [[ -n "${body}" ]] && cmd+=("--body" "${body}")
        if [[ -n "${effective_repo}" ]]; then
            _gh_validate_repo "${effective_repo}" || return 1
            cmd+=("--repo" "${effective_repo}")
        fi

        log "INFO" "pr_review_submit (simple): ${cmd[*]}"
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
        return 0
    fi

    # Path B: inline comments → REST reviews endpoint with JSON body on stdin.
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    # Validate each comment item has path, line, body.
    local invalid
    invalid=$(echo "${comments_json}" | jq -r '
        [.[] | select((.path // "") == "" or (.line // null) == null or (.body // "") == "")] | length
    ')
    if [[ "${invalid}" -gt 0 ]]; then
        echo "Error: each item in comments requires path, line, and body"
        return 1
    fi

    # Auto-fetch head SHA if commit_id not provided.
    if [[ -z "${commit_id}" ]]; then
        local fetch_raw fetch_exit=0
        fetch_raw=$(gh api "repos/${effective_repo}/pulls/${number}" --jq '.head.sha' 2>&1) || fetch_exit=$?
        if [[ ${fetch_exit} -ne 0 ]]; then
            [[ -n "${fallback}" ]] && { echo "${fallback}"; return 0; }
            echo "Error: failed to fetch commit_id for PR ${number}: ${fetch_raw}"
            return 1
        fi
        commit_id="${fetch_raw}"
    fi
    _gh_validate_sha "${commit_id}" || return 1

    local event_upper
    case "${event}" in
        approve)         event_upper="APPROVE" ;;
        request_changes) event_upper="REQUEST_CHANGES" ;;
        comment)         event_upper="COMMENT" ;;
    esac

    local review_body
    review_body=$(jq -n \
        --arg commit_id "${commit_id}" \
        --arg event "${event_upper}" \
        --arg body "${body}" \
        --argjson comments "${comments_json}" \
        '{commit_id: $commit_id, event: $event, body: $body, comments: $comments}
         | if .body == "" then del(.body) else . end')

    local -a cmd=("gh" "api" "repos/${effective_repo}/pulls/${number}/reviews" "-X" "POST" "--input" "-")

    log "INFO" "pr_review_submit (batched): ${cmd[*]}"
    local __raw __exit=0
    if [[ "${suppress_errors}" == "true" ]]; then
        __raw=$(printf '%s' "${review_body}" | "${cmd[@]}" 2>/dev/null) || __exit=$?
    else
        __raw=$(printf '%s' "${review_body}" | "${cmd[@]}" 2>&1) || __exit=$?
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

# Reply to an existing review comment thread.
# Maps to: POST /repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies
tool_pr_review_reply() {
    local args="$1"

    local number comment_id body repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    comment_id=$(echo "${args}" | jq -r '.comment_id // empty')
    body=$(echo "${args}" | jq -r '.body // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_review_reply"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    if [[ -z "${comment_id}" ]]; then
        echo "Error: comment_id is required for pr_review_reply"
        return 1
    fi
    _gh_validate_number "${comment_id}" "comment_id" || return 1

    if [[ -z "${body}" ]]; then
        echo "Error: body is required for pr_review_reply"
        return 1
    fi

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local endpoint="repos/${effective_repo}/pulls/${number}/comments/${comment_id}/replies"
    local -a cmd=("gh" "api" "${endpoint}" "-X" "POST" "-f" "body=${body}")

    log "INFO" "pr_review_reply: ${cmd[*]}"
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
