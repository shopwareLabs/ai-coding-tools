#!/usr/bin/env bash
# Project tools for gh-tooling MCP server
# Read: project_list, project_view  |  Write: project_item_add, project_status_set (added later)

# Helper: derive owner from GH_DEFAULT_REPO (takes "owner/repo", returns "owner")
_gh_resolve_owner() {
    local owner="$1"
    if [[ -n "${owner}" ]]; then
        echo "${owner}"
        return
    fi
    if [[ -n "${GH_DEFAULT_REPO}" ]]; then
        echo "${GH_DEFAULT_REPO%%/*}"
        return
    fi
    echo ""
}

# List GitHub Projects (v2) for a user or organization.
# Maps to: gh project list --owner <owner> --format json
tool_project_list() {
    local args="$1"

    local owner jq_filter suppress_errors fallback max_lines
    owner=$(echo "${args}" | jq -r '.owner // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')

    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_owner
    effective_owner=$(_gh_resolve_owner "${owner}")

    local -a cmd=("gh" "project" "list" "--format" "json")

    if [[ -n "${effective_owner}" ]]; then
        cmd+=("--owner" "${effective_owner}")
    fi

    log "INFO" "project_list: ${cmd[*]}"
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

# View details of a GitHub Project (v2).
# Maps to: gh project view <number> --owner <owner> --format json
tool_project_view() {
    local args="$1"

    local number owner jq_filter suppress_errors fallback max_lines
    number=$(echo "${args}" | jq -r '.number // empty')
    owner=$(echo "${args}" | jq -r '.owner // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')

    if [[ -z "${number}" ]]; then
        echo "Error: number is required for project_view"
        return 1
    fi

    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_owner
    effective_owner=$(_gh_resolve_owner "${owner}")

    local -a cmd=("gh" "project" "view" "${number}" "--format" "json")

    if [[ -n "${effective_owner}" ]]; then
        cmd+=("--owner" "${effective_owner}")
    fi

    log "INFO" "project_view: ${cmd[*]}"
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
