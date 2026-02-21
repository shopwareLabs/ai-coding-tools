#!/usr/bin/env bash
# Raw GitHub API tool for gh-tooling MCP server
# Tools: api

# Execute a raw GitHub API call using gh api.
# Use this as an escape hatch when specific tools don't cover your use case.
# Maps to: gh api <endpoint> [-X METHOD] [--jq <filter>] [--paginate]
#
# Common endpoints (relative to https://api.github.com/):
#   repos/{owner}/{repo}/pulls/{number}/files
#   repos/{owner}/{repo}/issues/{number}/timeline
#   repos/{owner}/{repo}/actions/runs/{run_id}/jobs
#   repos/{owner}/{repo}/pulls/comments/{comment_id}
#   search/issues (use -f q="..." for query params)
tool_api() {
    local args="$1"

    local endpoint method jq_filter paginate fields suppress_errors fallback max_lines tail_lines
    endpoint=$(echo "${args}" | jq -r '.endpoint // empty')
    method=$(echo "${args}" | jq -r '.method // "GET"')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    paginate=$(echo "${args}" | jq -r '.paginate // false')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')
    tail_lines=$(echo "${args}" | jq -r '.tail_lines // empty')

    if [[ -z "${endpoint}" ]]; then
        echo "Error: endpoint is required for api"
        return 1
    fi

    # Basic endpoint safety check - must not be empty or start with shell metacharacters.
    # Array-based execution (not eval) makes actual injection impossible, but reject obvious
    # cases for clarity. gh will reject any invalid API paths itself.
    if [[ -z "${endpoint// /}" ]]; then
        echo "Error: endpoint must not be empty or whitespace-only"
        return 1
    fi

    # Validate HTTP method
    case "${method}" in
        GET|POST|PATCH|PUT|DELETE) ;;
        *)
            echo "Error: method must be GET, POST, PATCH, PUT, or DELETE, got: '${method}'"
            return 1
            ;;
    esac

    _gh_validate_jq_filter "${jq_filter}" || return 1

    local -a cmd=("gh" "api" "${endpoint}")

    [[ "${method}" != "GET" ]] && cmd+=("-X" "${method}")
    [[ "${paginate}" == "true" ]] && cmd+=("--paginate")
    [[ -n "${fields}" ]] && cmd+=("--jq" "${fields}")
    [[ -n "${jq_filter}" ]] && cmd+=("--jq" "${jq_filter}")

    log "INFO" "api: ${cmd[*]}"
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
    _gh_post_process "${__raw}" "" "" 0 0 false false "${max_lines}" "${tail_lines}" || return $?
}
