#!/usr/bin/env bash
# Pull Request tools for gh-tooling MCP server
# Tools: pr_view, pr_diff, pr_list, pr_checks, pr_comments, pr_reviews, pr_files, pr_commits

# View pull request details.
# Maps to: gh pr view [<number>] [--repo owner/repo] [--json <fields>] [--comments]
tool_pr_view() {
    local args="$1"

    local number repo fields comments jq_filter suppress_errors fallback max_lines
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    comments=$(echo "${args}" | jq -r '.comments // false')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')

    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "pr" "view")

    if [[ -n "${number}" ]]; then
        _gh_validate_number "${number}" "number" || return 1
        cmd+=("${number}")
    fi

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    if [[ -n "${fields}" ]]; then
        cmd+=("--json" "${fields}")
    elif [[ "${comments}" == "true" ]]; then
        cmd+=("--comments")
    fi

    log "INFO" "pr_view: ${cmd[*]}"
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

# Get the unified diff for a pull request.
# Maps to: gh pr diff <number> [--repo owner/repo] [--name-only] [-- <file>]
tool_pr_diff() {
    local args="$1"

    local number repo file name_only suppress_errors fallback max_lines tail_lines
    local grep_pattern grep_context_before grep_context_after grep_ignore_case grep_invert
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    file=$(echo "${args}" | jq -r '.file // empty')
    name_only=$(echo "${args}" | jq -r '.name_only // false')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')
    tail_lines=$(echo "${args}" | jq -r '.tail_lines // empty')
    grep_pattern=$(echo "${args}" | jq -r '.grep_pattern // empty')
    grep_context_before=$(echo "${args}" | jq -r '.grep_context_before // 0')
    grep_context_after=$(echo "${args}" | jq -r '.grep_context_after // 0')
    grep_ignore_case=$(echo "${args}" | jq -r '.grep_ignore_case // false')
    grep_invert=$(echo "${args}" | jq -r '.grep_invert // false')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_diff"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "pr" "diff" "${number}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    [[ "${name_only}" == "true" ]] && cmd+=("--name-only")
    [[ -n "${file}" ]] && cmd+=("--" "${file}")

    log "INFO" "pr_diff: ${cmd[*]}"
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
    _gh_post_process "${__raw}" "" "${grep_pattern}" "${grep_context_before}" "${grep_context_after}" "${grep_ignore_case}" "${grep_invert}" "${max_lines}" "${tail_lines}" || return $?
}

# List pull requests with optional filters.
# Maps to: gh pr list [--repo] [--author] [--state] [--search] [--head] [--limit] [--json]
tool_pr_list() {
    local args="$1"

    local repo author state search head limit fields jq_filter suppress_errors fallback
    repo=$(echo "${args}" | jq -r '.repo // empty')
    author=$(echo "${args}" | jq -r '.author // empty')
    state=$(echo "${args}" | jq -r '.state // empty')
    search=$(echo "${args}" | jq -r '.search // empty')
    head=$(echo "${args}" | jq -r '.head // empty')
    limit=$(echo "${args}" | jq -r '.limit // 20')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "pr" "list")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    [[ -n "${author}" ]] && cmd+=("--author" "${author}")
    [[ -n "${state}" ]] && cmd+=("--state" "${state}")
    [[ -n "${search}" ]] && cmd+=("--search" "${search}")
    [[ -n "${head}" ]] && cmd+=("--head" "${head}")
    _gh_validate_number "${limit}" "limit" || return 1
    cmd+=("--limit" "${limit}")
    [[ -n "${fields}" ]] && cmd+=("--json" "${fields}")

    log "INFO" "pr_list: ${cmd[*]}"
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

# View CI status checks for a pull request.
# Maps to: gh pr checks <number> [--repo owner/repo]
tool_pr_checks() {
    local args="$1"

    local number repo suppress_errors fallback max_lines
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_checks"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "pr" "checks" "${number}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "pr_checks: ${cmd[*]}"
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
    _gh_post_process "${__raw}" "" "" 0 0 false false "${max_lines}" "" || return $?
}

# Get inline review comments (code-level) for a pull request.
# Maps to: gh api repos/{repo}/pulls/{number}/comments [--paginate] [--jq <filter>]
tool_pr_comments() {
    local args="$1"

    local number repo paginate jq_filter suppress_errors fallback max_lines
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    paginate=$(echo "${args}" | jq -r '.paginate // true')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_comments"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1
    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local -a cmd=("gh" "api" "repos/${effective_repo}/pulls/${number}/comments")
    [[ "${paginate}" != "false" ]] && cmd+=("--paginate")
    [[ -n "${jq_filter}" ]] && cmd+=("--jq" "${jq_filter}")

    log "INFO" "pr_comments: ${cmd[*]}"
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
    _gh_post_process "${__raw}" "" "" 0 0 false false "${max_lines}" "" || return $?
}

# Get reviews for a pull request (APPROVED, CHANGES_REQUESTED, COMMENTED, DISMISSED).
# Maps to: gh api repos/{repo}/pulls/{number}/reviews [--jq <filter>]
tool_pr_reviews() {
    local args="$1"

    local number repo jq_filter suppress_errors fallback max_lines
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_reviews"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1
    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local -a cmd=("gh" "api" "repos/${effective_repo}/pulls/${number}/reviews")
    [[ -n "${jq_filter}" ]] && cmd+=("--jq" "${jq_filter}")

    log "INFO" "pr_reviews: ${cmd[*]}"
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
    _gh_post_process "${__raw}" "" "" 0 0 false false "${max_lines}" "" || return $?
}

# Get files changed in a pull request with optional patch content.
# Maps to: gh api repos/{repo}/pulls/{number}/files [--jq <filter>]
tool_pr_files() {
    local args="$1"

    local number repo jq_filter suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // ".[] | {filename, status, additions, deletions}"')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_files"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1
    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local -a cmd=("gh" "api" "repos/${effective_repo}/pulls/${number}/files" "--jq" "${jq_filter}")

    log "INFO" "pr_files: ${cmd[*]}"
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

# Get the commit history for a pull request.
# Maps to: gh api repos/{repo}/pulls/{number}/commits [--jq <filter>]
tool_pr_commits() {
    local args="$1"

    local number repo jq_filter suppress_errors fallback
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // ".[] | {sha: .sha[0:10], message: (.commit.message | split(\"\n\")[0])}"')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_commits"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1
    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local -a cmd=("gh" "api" "repos/${effective_repo}/pulls/${number}/commits" "--jq" "${jq_filter}")

    log "INFO" "pr_commits: ${cmd[*]}"
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
