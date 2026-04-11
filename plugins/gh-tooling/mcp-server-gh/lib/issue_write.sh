#!/usr/bin/env bash
# Issue write tools for gh-tooling MCP server (write operations)
# Tools: issue_create, issue_edit, issue_close, issue_reopen, issue_comment

# Create a new issue.
# Maps to: gh issue create --title ... [--body ...] [--label X]... [--assignee X]...
#          [--milestone ...] [--project ...] [--repo ...]
tool_issue_create() {
    local args="$1"

    local title body milestone project repo suppress_errors fallback
    title=$(echo "${args}" | jq -r '.title // empty')
    body=$(echo "${args}" | jq -r '.body // empty')
    milestone=$(echo "${args}" | jq -r '.milestone // empty')
    project=$(echo "${args}" | jq -r '.project // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${title}" ]]; then
        echo "Error: title is required for issue_create"
        return 1
    fi

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "issue" "create" "--title" "${title}")

    [[ -n "${body}" ]] && cmd+=("--body" "${body}")
    [[ -n "${milestone}" ]] && cmd+=("--milestone" "${milestone}")
    [[ -n "${project}" ]] && cmd+=("--project" "${project}")

    local labels_json
    labels_json=$(echo "${args}" | jq -c '.labels // []')
    if [[ "${labels_json}" != "[]" ]]; then
        while IFS= read -r label; do
            cmd+=("--label" "${label}")
        done < <(echo "${labels_json}" | jq -r '.[]')
    fi

    local assignees_json
    assignees_json=$(echo "${args}" | jq -c '.assignees // []')
    if [[ "${assignees_json}" != "[]" ]]; then
        while IFS= read -r assignee; do
            cmd+=("--assignee" "${assignee}")
        done < <(echo "${assignees_json}" | jq -r '.[]')
    fi

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "issue_create: ${cmd[*]}"
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

# Edit an existing issue's metadata: title, body, labels, assignees, milestone.
# Maps to: gh issue edit <number> [--title ...] [--body ...] [--add-label X]...
#          [--add-assignee X]... [--milestone ...] [--repo ...]
tool_issue_edit() {
    local args="$1"

    local number title body milestone repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    title=$(echo "${args}" | jq -r '.title // empty')
    body=$(echo "${args}" | jq -r '.body // empty')
    milestone=$(echo "${args}" | jq -r '.milestone // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for issue_edit"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "issue" "edit" "${number}")

    [[ -n "${title}" ]] && cmd+=("--title" "${title}")
    [[ -n "${body}" ]] && cmd+=("--body" "${body}")
    [[ -n "${milestone}" ]] && cmd+=("--milestone" "${milestone}")

    local labels_json
    labels_json=$(echo "${args}" | jq -c '.labels // []')
    if [[ "${labels_json}" != "[]" ]]; then
        while IFS= read -r label; do
            cmd+=("--add-label" "${label}")
        done < <(echo "${labels_json}" | jq -r '.[]')
    fi

    local assignees_json
    assignees_json=$(echo "${args}" | jq -c '.assignees // []')
    if [[ "${assignees_json}" != "[]" ]]; then
        while IFS= read -r assignee; do
            cmd+=("--add-assignee" "${assignee}")
        done < <(echo "${assignees_json}" | jq -r '.[]')
    fi

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "issue_edit: ${cmd[*]}"
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

# Close an issue.
# Maps to: gh issue close <number> [--reason completed|not_planned] [--comment ...] [--repo ...]
tool_issue_close() {
    local args="$1"

    local number reason comment repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    reason=$(echo "${args}" | jq -r '.reason // empty')
    comment=$(echo "${args}" | jq -r '.comment // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for issue_close"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    if [[ -n "${reason}" && "${reason}" != "completed" && "${reason}" != "not_planned" ]]; then
        echo "Error: reason must be one of: completed, not_planned"
        return 1
    fi

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "issue" "close" "${number}")

    [[ -n "${reason}" ]] && cmd+=("--reason" "${reason}")
    [[ -n "${comment}" ]] && cmd+=("--comment" "${comment}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "issue_close: ${cmd[*]}"
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

# Reopen a closed issue.
# Maps to: gh issue reopen <number> [--repo ...]
tool_issue_reopen() {
    local args="$1"

    local number repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for issue_reopen"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "issue" "reopen" "${number}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "issue_reopen: ${cmd[*]}"
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

# Post a comment on an issue.
# Maps to: gh issue comment <number> --body ... [--repo ...]
tool_issue_comment() {
    local args="$1"

    local number body repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    body=$(echo "${args}" | jq -r '.body // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for issue_comment"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    if [[ -z "${body}" ]]; then
        echo "Error: body is required for issue_comment"
        return 1
    fi

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "issue" "comment" "${number}" "--body" "${body}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "issue_comment: ${cmd[*]}"
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
