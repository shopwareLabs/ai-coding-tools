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

# Shared helper for add/remove list operations on PRs/issues.
# Args: $1=args_json, $2=param_name (labels/assignees), $3=gh_flag (--add-label/--remove-label/etc)
_gh_edit_list_param() {
    local args="$1" param_name="$2" gh_flag="$3"

    local number type values_json repo suppress_errors fallback
    number=$(printf '%s' "${args}" | jq -r '.number // empty')
    type=$(printf '%s' "${args}" | jq -r '.type // empty')
    values_json=$(printf '%s' "${args}" | jq -c ".${param_name} // []")
    repo=$(printf '%s' "${args}" | jq -r '.repo // empty')
    suppress_errors=$(printf '%s' "${args}" | jq -r '.suppress_errors // false')
    fallback=$(printf '%s' "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then
        printf 'Error: number is required\n'
        return 1
    fi
    _gh_validate_number "${number}" "number" || return 1

    if [[ -z "${type}" ]]; then
        printf 'Error: type is required (pr or issue)\n'
        return 1
    fi
    if [[ "${type}" != "pr" && "${type}" != "issue" ]]; then
        printf 'Error: type must be '\''pr'\'' or '\''issue'\'', got: '\''%s'\''\n' "${type}"
        return 1
    fi

    if [[ "${values_json}" == "[]" ]]; then
        printf 'Error: %s array is required and must not be empty\n' "${param_name}"
        return 1
    fi

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "${type}" "edit" "${number}")

    while IFS= read -r val; do
        cmd+=("${gh_flag}" "${val}")
    done < <(printf '%s' "${values_json}" | jq -r '.[]')

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    log "INFO" "${param_name}: ${cmd[*]}"
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
    [[ -n "${__raw}" ]] && printf '%s\n' "${__raw}"
    return 0
}

tool_label_add() { _gh_edit_list_param "$1" "labels" "--add-label"; }
tool_label_remove() { _gh_edit_list_param "$1" "labels" "--remove-label"; }
