#!/usr/bin/env bash
# Pull Request tools for gh-tooling MCP server
# Tools: pr_view, pr_diff, pr_list, pr_checks, pr_comments, pr_reviews, pr_files, pr_commits

# View pull request details.
# Maps to: gh pr view [<number>] [--repo owner/repo] [--json <fields>] [--comments]
tool_pr_view() {
    local args="$1"

    local number repo fields comments
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    comments=$(echo "${args}" | jq -r '.comments // false')

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
    "${cmd[@]}" 2>&1
}

# Get the unified diff for a pull request.
# Maps to: gh pr diff <number> [--repo owner/repo] [--name-only] [-- <file>]
tool_pr_diff() {
    local args="$1"

    local number repo file name_only
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    file=$(echo "${args}" | jq -r '.file // empty')
    name_only=$(echo "${args}" | jq -r '.name_only // false')

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
    "${cmd[@]}" 2>&1
}

# List pull requests with optional filters.
# Maps to: gh pr list [--repo] [--author] [--state] [--search] [--head] [--limit] [--json]
tool_pr_list() {
    local args="$1"

    local repo author state search head limit fields
    repo=$(echo "${args}" | jq -r '.repo // empty')
    author=$(echo "${args}" | jq -r '.author // empty')
    state=$(echo "${args}" | jq -r '.state // empty')
    search=$(echo "${args}" | jq -r '.search // empty')
    head=$(echo "${args}" | jq -r '.head // empty')
    limit=$(echo "${args}" | jq -r '.limit // 20')
    fields=$(echo "${args}" | jq -r '.fields // empty')

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
    "${cmd[@]}" 2>&1
}

# View CI status checks for a pull request.
# Maps to: gh pr checks <number> [--repo owner/repo]
tool_pr_checks() {
    local args="$1"

    local number repo
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')

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
    "${cmd[@]}" 2>&1
}

# Get inline review comments (code-level) for a pull request.
# Maps to: gh api repos/{repo}/pulls/{number}/comments [--paginate] [--jq <filter>]
tool_pr_comments() {
    local args="$1"

    local number repo paginate jq_filter
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    paginate=$(echo "${args}" | jq -r '.paginate // true')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_comments"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local -a cmd=("gh" "api" "repos/${effective_repo}/pulls/${number}/comments")
    [[ "${paginate}" != "false" ]] && cmd+=("--paginate")
    [[ -n "${jq_filter}" ]] && cmd+=("--jq" "${jq_filter}")

    log "INFO" "pr_comments: ${cmd[*]}"
    "${cmd[@]}" 2>&1
}

# Get reviews for a pull request (APPROVED, CHANGES_REQUESTED, COMMENTED, DISMISSED).
# Maps to: gh api repos/{repo}/pulls/{number}/reviews [--jq <filter>]
tool_pr_reviews() {
    local args="$1"

    local number repo jq_filter
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_reviews"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local -a cmd=("gh" "api" "repos/${effective_repo}/pulls/${number}/reviews")
    [[ -n "${jq_filter}" ]] && cmd+=("--jq" "${jq_filter}")

    log "INFO" "pr_reviews: ${cmd[*]}"
    "${cmd[@]}" 2>&1
}

# Get files changed in a pull request with optional patch content.
# Maps to: gh api repos/{repo}/pulls/{number}/files [--jq <filter>]
tool_pr_files() {
    local args="$1"

    local number repo jq_filter
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // ".[] | {filename, status, additions, deletions}"')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_files"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local -a cmd=("gh" "api" "repos/${effective_repo}/pulls/${number}/files" "--jq" "${jq_filter}")

    log "INFO" "pr_files: ${cmd[*]}"
    "${cmd[@]}" 2>&1
}

# Get the commit history for a pull request.
# Maps to: gh api repos/{repo}/pulls/{number}/commits [--jq <filter>]
tool_pr_commits() {
    local args="$1"

    local number repo jq_filter
    number=$(echo "${args}" | jq -r '.number // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // ".[] | {sha: .sha[0:10], message: (.commit.message | split(\"\n\")[0])}"')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for pr_commits"
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    local -a cmd=("gh" "api" "repos/${effective_repo}/pulls/${number}/commits" "--jq" "${jq_filter}")

    log "INFO" "pr_commits: ${cmd[*]}"
    "${cmd[@]}" 2>&1
}
