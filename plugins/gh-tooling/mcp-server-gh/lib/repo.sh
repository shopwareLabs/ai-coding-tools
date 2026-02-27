#!/usr/bin/env bash
# Repository content tools for gh-tooling MCP server
# Tools: repo_tree, repo_file

# Browse repository directory contents or get the full file tree.
# Supports GitHub URLs, explicit owner/repo, repository string, or default repo.
# Non-recursive: gh api repos/{owner}/{repo}/contents/{path}?ref={ref}
# Recursive: gh api repos/{owner}/{repo}/git/trees/{ref}?recursive=1
tool_repo_tree() {
    local args="$1"

    local recursive jq_filter suppress_errors fallback
    recursive=$(echo "${args}" | jq -r '.recursive // false')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    _gh_validate_jq_filter "${jq_filter}" || return 1

    _gh_resolve_owner_repo "${args}" || return 1
    local owner="${_GH_OWNER}" repo="${_GH_REPO}" ref="${_GH_REF}" path="${_GH_PATH}"

    _gh_validate_path "${path}" || return 1

    local -a cmd __raw __exit=0

    if [[ "${recursive}" == "true" ]]; then
        local tree_ref="${ref:-HEAD}"
        cmd=("gh" "api" "repos/${owner}/${repo}/git/trees/${tree_ref}?recursive=1")

        log "INFO" "repo_tree (recursive): ${cmd[*]}"
        if [[ "${suppress_errors}" == "true" ]]; then
            __raw=$("${cmd[@]}" 2>/dev/null) || __exit=$?
        else
            __raw=$("${cmd[@]}" 2>&1) || __exit=$?
        fi
        if [[ ${__exit} -ne 0 ]]; then
            [[ -n "${fallback}" ]] && { echo "${fallback}"; return 0; }
            echo "${__raw}"; return ${__exit}
        fi

        # Filter by path prefix if provided, then apply default or custom jq
        local default_jq
        if [[ -n "${path}" ]]; then
            # Strip trailing slash for consistent matching
            local clean_path="${path%/}"
            # Escape backslashes and double quotes for safe jq interpolation
            clean_path="${clean_path//\\/\\\\}"
            clean_path="${clean_path//\"/\\\"}"
            default_jq="[.tree[] | select(.path | startswith(\"${clean_path}/\")) | {path, type, size}]"
        else
            default_jq='[.tree[] | {path, type, size}]'
        fi
        local effective_jq="${jq_filter:-${default_jq}}"
        __raw=$(echo "${__raw}" | jq "${effective_jq}") || {
            echo "Error: jq filter failed on output: ${effective_jq}"
            return 1
        }
    else
        local endpoint="repos/${owner}/${repo}/contents/${path}"
        [[ -n "${ref}" ]] && endpoint="${endpoint}?ref=${ref}"
        cmd=("gh" "api" "${endpoint}")

        log "INFO" "repo_tree: ${cmd[*]}"
        if [[ "${suppress_errors}" == "true" ]]; then
            __raw=$("${cmd[@]}" 2>/dev/null) || __exit=$?
        else
            __raw=$("${cmd[@]}" 2>&1) || __exit=$?
        fi
        if [[ ${__exit} -ne 0 ]]; then
            [[ -n "${fallback}" ]] && { echo "${fallback}"; return 0; }
            echo "${__raw}"; return ${__exit}
        fi

        local default_jq='[.[] | {name, type, size, path}]'
        local effective_jq="${jq_filter:-${default_jq}}"
        __raw=$(echo "${__raw}" | jq "${effective_jq}") || {
            echo "Error: jq filter failed on output: ${effective_jq}"
            return 1
        }
    fi

    echo "${__raw}"
}

# Fetch a single file from a GitHub repository with optional line range and grep filtering.
# Supports GitHub URLs, explicit owner/repo, repository string, or default repo.
# Maps to: gh api repos/{owner}/{repo}/contents/{path}?ref={ref} -H "Accept: application/vnd.github.raw+json"
tool_repo_file() {
    local args="$1"

    local line_start line_end download_to
    local jq_filter grep_pattern grep_before grep_after grep_ignore_case grep_invert
    local max_lines tail_lines suppress_errors fallback
    line_start=$(echo "${args}" | jq -r '.line_start // empty')
    line_end=$(echo "${args}" | jq -r '.line_end // empty')
    download_to=$(echo "${args}" | jq -r '.download_to // empty')
    grep_pattern=$(echo "${args}" | jq -r '.grep_pattern // empty')
    grep_before=$(echo "${args}" | jq -r '.grep_context_before // 0')
    grep_after=$(echo "${args}" | jq -r '.grep_context_after // 0')
    grep_ignore_case=$(echo "${args}" | jq -r '.grep_ignore_case // false')
    grep_invert=$(echo "${args}" | jq -r '.grep_invert // false')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')
    tail_lines=$(echo "${args}" | jq -r '.tail_lines // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    _gh_resolve_owner_repo "${args}" || return 1
    local owner="${_GH_OWNER}" repo="${_GH_REPO}" ref="${_GH_REF}" path="${_GH_PATH}"

    if [[ -z "${path}" ]]; then
        echo "Error: path is required for repo_file (provide via 'path' parameter or GitHub URL)"
        return 1
    fi

    _gh_validate_path "${path}" || return 1

    local endpoint="repos/${owner}/${repo}/contents/${path}"
    [[ -n "${ref}" ]] && endpoint="${endpoint}?ref=${ref}"
    local -a cmd=("gh" "api" "${endpoint}" "-H" "Accept: application/vnd.github.raw+json")

    # download_to mode: save raw file locally
    if [[ -n "${download_to}" ]]; then
        log "INFO" "repo_file (download): ${cmd[*]} → ${download_to}"
        local parent_dir
        parent_dir=$(dirname "${download_to}")
        mkdir -p "${parent_dir}" 2>/dev/null || {
            echo "Error: cannot create directory ${parent_dir}"
            return 1
        }
        local __exit=0 __dl_err=""
        if [[ "${suppress_errors}" == "true" ]]; then
            "${cmd[@]}" > "${download_to}" 2>/dev/null || __exit=$?
        else
            # Capture stderr separately — don't write API errors into the download file
            __dl_err=$({ "${cmd[@]}" > "${download_to}"; } 2>&1) || __exit=$?
        fi
        if [[ ${__exit} -ne 0 ]]; then
            rm -f "${download_to}" 2>/dev/null
            [[ -n "${fallback}" ]] && { echo "${fallback}"; return 0; }
            [[ -n "${__dl_err}" ]] && { echo "${__dl_err}"; return ${__exit}; }
            echo "Error: failed to download ${owner}/${repo}/${path}"
            return ${__exit}
        fi
        echo "Downloaded ${owner}/${repo}/${path} to ${download_to}"
        return 0
    fi

    log "INFO" "repo_file: ${cmd[*]}"
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

    # Apply line range via sed if specified (validate as integers first)
    if [[ -n "${line_start}" || -n "${line_end}" ]]; then
        [[ -n "${line_start}" ]] && { _gh_validate_number "${line_start}" "line_start" || return 1; }
        [[ -n "${line_end}" ]] && { _gh_validate_number "${line_end}" "line_end" || return 1; }
        local start="${line_start:-1}"
        local end="${line_end:-\$}"
        __raw=$(echo "${__raw}" | sed -n "${start},${end}p")
    fi

    _gh_post_process "${__raw}" "" "${grep_pattern}" "${grep_before}" \
        "${grep_after}" "${grep_ignore_case}" "${grep_invert}" "${max_lines}" "${tail_lines}" || return $?
}
