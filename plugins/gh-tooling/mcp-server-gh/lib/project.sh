#!/usr/bin/env bash
# Project tools for gh-tooling MCP server
# Read: project_list, project_view  |  Write: project_item_add, project_status_set

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

# Resolve project name to project number.
# Args: $1=project_name, $2=owner
# On success: prints the project number
# On failure: prints error listing available projects and returns 1
_gh_resolve_project_number() {
    local project_name="$1" owner="$2"

    local projects_json
    projects_json=$(gh project list --owner "${owner}" --format json 2>&1) || {
        printf '%s\n' "Error: could not list projects for '${owner}': ${projects_json}"
        return 1
    }

    local number
    number=$(printf '%s\n' "${projects_json}" | jq -r --arg name "${project_name}" '.projects[] | select(.title == $name) | .number' 2>/dev/null)

    if [[ -z "${number}" ]]; then
        local available
        available=$(printf '%s\n' "${projects_json}" | jq -r '.projects[].title' 2>/dev/null | paste -sd ', ' -)
        printf '%s\n' "Error: project '${project_name}' not found. Available projects: ${available:-<none>}"
        return 1
    fi

    printf '%s\n' "${number}"
}

# Resolve status field name to field ID and option ID.
# Args: $1=project_number, $2=owner, $3=status_name
# On success: prints "field_id<TAB>option_id"
# On failure: prints error listing available options and returns 1
_gh_resolve_status_option() {
    local project_number="$1" owner="$2" status_name="$3"

    local fields_json
    fields_json=$(gh project field-list "${project_number}" --owner "${owner}" --format json 2>&1) || {
        printf '%s\n' "Error: could not list fields for project ${project_number}: ${fields_json}"
        return 1
    }

    # Find the Status single-select field
    local field_id
    field_id=$(printf '%s\n' "${fields_json}" | jq -r '.fields[] | select(.name == "Status" and .type == "ProjectV2SingleSelectField") | .id' 2>/dev/null)

    if [[ -z "${field_id}" ]]; then
        printf '%s\n' "Error: no Status field found in project ${project_number}"
        return 1
    fi

    local option_id
    option_id=$(printf '%s\n' "${fields_json}" | jq -r --arg name "${status_name}" '.fields[] | select(.name == "Status") | .options[] | select(.name == $name) | .id' 2>/dev/null)

    if [[ -z "${option_id}" ]]; then
        local available
        available=$(printf '%s\n' "${fields_json}" | jq -r '.fields[] | select(.name == "Status") | .options[].name' 2>/dev/null | paste -sd ', ' -)
        printf '%s\n' "Error: status '${status_name}' not found in project ${project_number}. Available options: ${available:-<none>}"
        return 1
    fi

    printf '%s\t%s' "${field_id}" "${option_id}"
}

# Add an issue or PR to a GitHub Project by project name.
tool_project_item_add() {
    local args="$1"

    local number type project repo suppress_errors fallback
    number=$(printf '%s\n' "${args}" | jq -r '.number // empty')
    type=$(printf '%s\n' "${args}" | jq -r '.type // empty')
    project=$(printf '%s\n' "${args}" | jq -r '.project // empty')
    repo=$(printf '%s\n' "${args}" | jq -r '.repo // empty')
    suppress_errors=$(printf '%s\n' "${args}" | jq -r '.suppress_errors // false')
    fallback=$(printf '%s\n' "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then printf '%s\n' "Error: number is required for project_item_add"; return 1; fi
    if [[ -z "${type}" ]]; then printf '%s\n' "Error: type is required (pr or issue)"; return 1; fi
    if [[ "${type}" != "pr" && "${type}" != "issue" ]]; then
        printf '%s\n' "Error: type must be 'pr' or 'issue', got: '${type}'"
        return 1
    fi
    if [[ -z "${project}" ]]; then printf '%s\n' "Error: project name is required for project_item_add"; return 1; fi

    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    if [[ -z "${effective_repo}" ]]; then
        printf '%s\n' "Error: repo is required for project_item_add"
        return 1
    fi

    local effective_owner
    effective_owner="${effective_repo%%/*}"

    # Resolve project name to number
    local project_number
    project_number=$(_gh_resolve_project_number "${project}" "${effective_owner}" 2>&1) || {
        [[ -n "${fallback}" ]] && { printf '%s\n' "${fallback}"; return 0; }
        printf '%s\n' "${project_number}"; return 1
    }

    # Build the item URL
    local item_url
    if [[ "${type}" == "pr" ]]; then
        item_url="https://github.com/${effective_repo}/pull/${number}"
    else
        item_url="https://github.com/${effective_repo}/issues/${number}"
    fi

    local -a cmd=("gh" "project" "item-add" "${project_number}" "--owner" "${effective_owner}" "--url" "${item_url}")

    log "INFO" "project_item_add: ${cmd[*]}"
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

# Set the Status field of an issue or PR in a GitHub Project by name.
tool_project_status_set() {
    local args="$1"

    local number type project status repo suppress_errors fallback
    number=$(printf '%s\n' "${args}" | jq -r '.number // empty')
    type=$(printf '%s\n' "${args}" | jq -r '.type // empty')
    project=$(printf '%s\n' "${args}" | jq -r '.project // empty')
    status=$(printf '%s\n' "${args}" | jq -r '.status // empty')
    repo=$(printf '%s\n' "${args}" | jq -r '.repo // empty')
    suppress_errors=$(printf '%s\n' "${args}" | jq -r '.suppress_errors // false')
    fallback=$(printf '%s\n' "${args}" | jq -r '.fallback // empty')

    if [[ -z "${number}" ]]; then printf '%s\n' "Error: number is required for project_status_set"; return 1; fi
    if [[ -z "${type}" ]]; then printf '%s\n' "Error: type is required (pr or issue)"; return 1; fi
    if [[ "${type}" != "pr" && "${type}" != "issue" ]]; then
        printf '%s\n' "Error: type must be 'pr' or 'issue', got: '${type}'"
        return 1
    fi
    if [[ -z "${project}" ]]; then printf '%s\n' "Error: project name is required for project_status_set"; return 1; fi
    if [[ -z "${status}" ]]; then printf '%s\n' "Error: status is required for project_status_set"; return 1; fi

    _gh_validate_number "${number}" "number" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    if [[ -z "${effective_repo}" ]]; then
        printf '%s\n' "Error: repo is required for project_status_set"
        return 1
    fi

    local effective_owner
    effective_owner="${effective_repo%%/*}"

    # Resolve project name to number
    local project_number
    project_number=$(_gh_resolve_project_number "${project}" "${effective_owner}" 2>&1) || {
        [[ -n "${fallback}" ]] && { printf '%s\n' "${fallback}"; return 0; }
        printf '%s\n' "${project_number}"; return 1
    }

    # Resolve status name to field_id + option_id
    local status_ids
    status_ids=$(_gh_resolve_status_option "${project_number}" "${effective_owner}" "${status}" 2>&1) || {
        [[ -n "${fallback}" ]] && { printf '%s\n' "${fallback}"; return 0; }
        printf '%s\n' "${status_ids}"; return 1
    }
    local field_id option_id
    IFS=$'\t' read -r field_id option_id <<< "${status_ids}"

    # Build the item URL to look up the item ID in the project
    local item_url
    if [[ "${type}" == "pr" ]]; then
        item_url="https://github.com/${effective_repo}/pull/${number}"
    else
        item_url="https://github.com/${effective_repo}/issues/${number}"
    fi

    # Find the item ID by listing project items and matching the URL
    local item_id
    item_id=$(gh project item-list "${project_number}" --owner "${effective_owner}" --format json 2>&1 | \
        jq -r --arg url "${item_url}" '.items[] | select(.content.url == $url) | .id' 2>/dev/null) || true

    if [[ -z "${item_id}" ]]; then
        [[ -n "${fallback}" ]] && { printf '%s\n' "${fallback}"; return 0; }
        printf '%s\n' "Error: ${type} #${number} not found in project '${project}'. Add it first with project_item_add."
        return 1
    fi

    local -a cmd=("gh" "project" "item-edit"
        "--id" "${item_id}"
        "--field-id" "${field_id}"
        "--project-id" "${project_number}"
        "--single-select-option-id" "${option_id}"
    )

    log "INFO" "project_status_set: ${cmd[*]}"
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
