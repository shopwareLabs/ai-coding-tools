#!/usr/bin/env bash
# Pull Request write tools for gh-tooling MCP server (write operations)
# Tools: pr_create, pr_edit, pr_ready, pr_merge, pr_close, pr_reopen

# Create a new pull request.
# Maps to: gh pr create --title ... [--body ...] [--base ...] [--head ...] [--draft]
#          [--label X]... [--assignee X]... [--reviewer X]... [--milestone ...] [--repo ...]
tool_pr_create() {
    local args="$1"

    local title body base head draft milestone repo suppress_errors fallback
    title=$(echo "${args}" | jq -r '.title // empty')
    body=$(echo "${args}" | jq -r '.body // empty')
    base=$(echo "${args}" | jq -r '.base // empty')
    head=$(echo "${args}" | jq -r '.head // empty')
    draft=$(echo "${args}" | jq -r '.draft // false')
    milestone=$(echo "${args}" | jq -r '.milestone // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${title}" ]]; then
        echo "Error: title is required for pr_create"
        return 1
    fi

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "pr" "create" "--title" "${title}" "--body" "${body}")
    [[ -n "${base}" ]] && cmd+=("--base" "${base}")
    [[ -n "${head}" ]] && cmd+=("--head" "${head}")
    [[ "${draft}" == "true" ]] && cmd+=("--draft")
    [[ -n "${milestone}" ]] && cmd+=("--milestone" "${milestone}")

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

    local reviewers_json
    reviewers_json=$(echo "${args}" | jq -c '.reviewers // []')
    if [[ "${reviewers_json}" != "[]" ]]; then
        while IFS= read -r reviewer; do
            cmd+=("--reviewer" "${reviewer}")
        done < <(echo "${reviewers_json}" | jq -r '.[]')
    fi

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "pr_create: ${cmd[*]}"
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

# Edit a pull request (title, body, base, labels, assignees, milestone).
# Maps to: gh pr edit <number> [--title ...] [--body ...] [--base ...]
#          [--add-label X]... [--add-assignee X]... [--milestone ...] [--repo ...]
tool_pr_edit() {
    local args="$1"

    local number title body base milestone repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    title=$(echo "${args}" | jq -r '.title // empty')
    body=$(echo "${args}" | jq -r '.body // empty')
    base=$(echo "${args}" | jq -r '.base // empty')
    milestone=$(echo "${args}" | jq -r '.milestone // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_edit"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "pr" "edit" "${number}")

    [[ -n "${title}" ]] && cmd+=("--title" "${title}")
    [[ -n "${body}" ]] && cmd+=("--body" "${body}")
    [[ -n "${base}" ]] && cmd+=("--base" "${base}")
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

    log "INFO" "pr_edit: ${cmd[*]}"
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

# Mark a draft pull request as ready for review.
# Maps to: gh pr ready <number> [--repo ...]
tool_pr_ready() {
    local args="$1"

    local number repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_ready"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "pr" "ready" "${number}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "pr_ready: ${cmd[*]}"
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

# Merge a pull request immediately.
# Maps to: gh pr merge <number> --merge|--squash|--rebase [--delete-branch]
#          [--subject ...] [--body ...] [--repo ...]
tool_pr_merge() {
    local args="$1"

    local number method delete_branch subject body repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    method=$(echo "${args}" | jq -r '.method // "merge"')
    delete_branch=$(echo "${args}" | jq -r '.delete_branch // false')
    subject=$(echo "${args}" | jq -r '.subject // empty')
    body=$(echo "${args}" | jq -r '.body // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_merge"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    if [[ "${method}" != "merge" && "${method}" != "squash" && "${method}" != "rebase" ]]; then
        echo "Error: method must be one of: merge, squash, rebase"
        return 1
    fi

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "pr" "merge" "${number}")

    case "${method}" in
        squash) cmd+=("--squash") ;;
        rebase) cmd+=("--rebase") ;;
        *)      cmd+=("--merge") ;;
    esac

    [[ "${delete_branch}" == "true" ]] && cmd+=("--delete-branch")
    [[ -n "${subject}" ]] && cmd+=("--subject" "${subject}")
    [[ -n "${body}" ]] && cmd+=("--body" "${body}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "pr_merge: ${cmd[*]}"
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

# Close a pull request without merging.
# Maps to: gh pr close <number> [--comment ...] [--repo ...]
tool_pr_close() {
    local args="$1"

    local number comment repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    comment=$(echo "${args}" | jq -r '.comment // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_close"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "pr" "close" "${number}")

    [[ -n "${comment}" ]] && cmd+=("--comment" "${comment}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "pr_close: ${cmd[*]}"
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

# Reopen a closed pull request.
# Maps to: gh pr reopen <number> [--repo ...]
tool_pr_reopen() {
    local args="$1"

    local number repo suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_reopen"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "pr" "reopen" "${number}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "pr_reopen: ${cmd[*]}"
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
