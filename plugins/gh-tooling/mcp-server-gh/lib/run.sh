#!/usr/bin/env bash
# GitHub Actions run tools for gh-tooling MCP server
# Tools: run_view, run_list, run_logs

# View the status and summary of a GitHub Actions workflow run.
# Maps to: gh run view <run_id> [--repo] [--json <fields>]
tool_run_view() {
    local args="$1"

    local run_id repo fields jq_filter suppress_errors fallback
    run_id=$(echo "${args}" | jq -r '.run_id // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${run_id}" ]]; then
        echo "Error: run_id is required for run_view"
        return 1
    fi
    _gh_validate_number "${run_id}" "run_id" || return 1
    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "run" "view" "${run_id}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    [[ -n "${fields}" ]] && cmd+=("--json" "${fields}")

    log "INFO" "run_view: ${cmd[*]}"
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

# List recent GitHub Actions workflow runs for a repository or branch.
# Maps to: gh run list [--repo] [--branch] [--workflow] [--status] [--event] [--user] [--created] [--commit] [--limit] [--json]
tool_run_list() {
    local args="$1"

    local repo branch workflow status event user created commit limit fields jq_filter suppress_errors fallback
    repo=$(echo "${args}" | jq -r '.repo // empty')
    branch=$(echo "${args}" | jq -r '.branch // empty')
    workflow=$(echo "${args}" | jq -r '.workflow // empty')
    status=$(echo "${args}" | jq -r '.status // empty')
    event=$(echo "${args}" | jq -r '.event // empty')
    user=$(echo "${args}" | jq -r '.user // empty')
    created=$(echo "${args}" | jq -r '.created // empty')
    commit=$(echo "${args}" | jq -r '.commit // empty')
    limit=$(echo "${args}" | jq -r '.limit // 20')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "run" "list")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    [[ -n "${branch}" ]] && cmd+=("--branch" "${branch}")
    [[ -n "${workflow}" ]] && cmd+=("--workflow" "${workflow}")
    [[ -n "${status}" ]] && cmd+=("--status" "${status}")
    [[ -n "${event}" ]] && cmd+=("--event" "${event}")
    [[ -n "${user}" ]] && cmd+=("--user" "${user}")
    [[ -n "${created}" ]] && cmd+=("--created" "${created}")
    [[ -n "${commit}" ]] && cmd+=("--commit" "${commit}")
    _gh_validate_number "${limit}" "limit" || return 1
    cmd+=("--limit" "${limit}")
    [[ -n "${fields}" ]] && cmd+=("--json" "${fields}")

    log "INFO" "run_list: ${cmd[*]}"
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

# Get logs for a GitHub Actions workflow run. Defaults to failed steps only.
# Maps to: gh run view <run_id> --log-failed | --log [--repo]
# Optional max_lines/tail_lines/grep to filter very large log output.
tool_run_logs() {
    local args="$1"

    local run_id repo failed_only max_lines tail_lines suppress_errors fallback
    local grep_pattern grep_context_before grep_context_after grep_ignore_case grep_invert
    run_id=$(echo "${args}" | jq -r '.run_id // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    failed_only=$(echo "${args}" | jq -r '.failed_only // true')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')
    tail_lines=$(echo "${args}" | jq -r '.tail_lines // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    grep_pattern=$(echo "${args}" | jq -r '.grep_pattern // empty')
    grep_context_before=$(echo "${args}" | jq -r '.grep_context_before // 0')
    grep_context_after=$(echo "${args}" | jq -r '.grep_context_after // 0')
    grep_ignore_case=$(echo "${args}" | jq -r '.grep_ignore_case // false')
    grep_invert=$(echo "${args}" | jq -r '.grep_invert // false')

    if [[ -z "${run_id}" ]]; then
        echo "Error: run_id is required for run_logs"
        return 1
    fi
    _gh_validate_number "${run_id}" "run_id" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    local -a cmd=("gh" "run" "view" "${run_id}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    if [[ "${failed_only}" == "false" ]]; then
        cmd+=("--log")
    else
        cmd+=("--log-failed")
    fi

    log "INFO" "run_logs: ${cmd[*]}"
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

# Aggregate jobs across workflow runs in a single call.
# Reduces N+1 tool calls (run_list + N×job_view) to a single invocation.
# Maps to: gh run list --workflow X --json databaseId + gh api repos/{repo}/actions/runs/{id}/jobs
tool_workflow_jobs() {
    local args="$1"

    local repo workflow job conclusion step limit run_status branch event
    local jq_filter max_lines suppress_errors fallback
    repo=$(echo "${args}" | jq -r '.repo // empty')
    workflow=$(echo "${args}" | jq -r '.workflow // empty')
    job=$(echo "${args}" | jq -r '.job // empty')
    conclusion=$(echo "${args}" | jq -r '.conclusion // empty')
    step=$(echo "${args}" | jq -r '.step // empty')
    limit=$(echo "${args}" | jq -r '.limit // 5')
    run_status=$(echo "${args}" | jq -r '.run_status // empty')
    branch=$(echo "${args}" | jq -r '.branch // empty')
    event=$(echo "${args}" | jq -r '.event // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${workflow}" ]]; then
        echo "Error: workflow is required for workflow_jobs"
        return 1
    fi
    _gh_validate_jq_filter "${jq_filter}" || return 1
    _gh_validate_number "${limit}" "limit" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")
    _gh_require_repo "${effective_repo}" || return 1
    _gh_validate_repo "${effective_repo}" || return 1

    # Step 1: List workflow runs
    local -a list_cmd=("gh" "run" "list" "--repo" "${effective_repo}" "--workflow" "${workflow}" "--limit" "${limit}" "--json" "databaseId,displayTitle,headBranch,status,conclusion,createdAt")
    [[ -n "${run_status}" ]] && list_cmd+=("--status" "${run_status}")
    [[ -n "${branch}" ]] && list_cmd+=("--branch" "${branch}")
    [[ -n "${event}" ]] && list_cmd+=("--event" "${event}")

    log "INFO" "workflow_jobs: ${list_cmd[*]}"
    local runs_json __exit=0
    if [[ "${suppress_errors}" == "true" ]]; then
        runs_json=$("${list_cmd[@]}" 2>/dev/null) || __exit=$?
    else
        runs_json=$("${list_cmd[@]}" 2>&1) || __exit=$?
    fi
    if [[ ${__exit} -ne 0 ]]; then
        [[ -n "${fallback}" ]] && { echo "${fallback}"; return 0; }
        echo "${runs_json}"; return ${__exit}
    fi

    # Extract run IDs
    local run_ids
    run_ids=$(echo "${runs_json}" | jq -r '.[].databaseId // empty' 2>/dev/null)
    if [[ -z "${run_ids}" ]]; then
        local result="[]"
        _gh_post_process "${result}" "${jq_filter}" "" 0 0 false false "${max_lines}" "" || return $?
        return 0
    fi

    # Step 2: Fetch jobs for each run via API
    local all_jobs="[]"
    local run_id
    while IFS= read -r run_id; do
        [[ -z "${run_id}" ]] && continue
        log "INFO" "workflow_jobs: fetching jobs for run ${run_id}"

        local api_out api_exit=0
        api_out=$(gh api "repos/${effective_repo}/actions/runs/${run_id}/jobs" --paginate 2>&1) || api_exit=$?
        if [[ ${api_exit} -ne 0 ]]; then
            log "WARN" "workflow_jobs: failed to fetch jobs for run ${run_id}: ${api_out}"
            continue
        fi

        # Extract jobs and attach run context via jq -s (slurp) to avoid --argjson quoting issues
        local run_jobs
        run_jobs=$(jq -c -n --arg rid "${run_id}" \
            --slurpfile runs <(echo "${runs_json}") \
            --slurpfile api <(echo "${api_out}") \
            '($runs[0][] | select(.databaseId == ($rid | tonumber))) as $ctx | [$api[0].jobs[] | . + {run: $ctx}]' 2>/dev/null) || run_jobs="[]"

        all_jobs=$(printf '%s\n%s' "${all_jobs}" "${run_jobs}" | jq -s '.[0] + .[1]' 2>/dev/null) || true
    done <<< "${run_ids}"

    # Step 3: Filter jobs by name (case-insensitive substring)
    if [[ -n "${job}" ]]; then
        all_jobs=$(echo "${all_jobs}" | jq -c --arg name "${job}" \
            '[.[] | select((.name | ascii_downcase) | contains($name | ascii_downcase))]' 2>/dev/null) || all_jobs="[]"
    fi

    # Step 4: Filter by conclusion
    if [[ -n "${conclusion}" ]]; then
        all_jobs=$(echo "${all_jobs}" | jq -c --arg conc "${conclusion}" \
            '[.[] | select((.conclusion // "" | ascii_downcase) == ($conc | ascii_downcase))]' 2>/dev/null) || all_jobs="[]"
    fi

    # Step 5: Filter and include steps (only when step filter is set)
    if [[ -n "${step}" ]]; then
        all_jobs=$(echo "${all_jobs}" | jq -c --arg sname "${step}" \
            '[.[] | .steps = [.steps[]? | select((.name | ascii_downcase) | contains($sname | ascii_downcase))]]' 2>/dev/null) || all_jobs="[]"
    else
        # Exclude steps by default to reduce output size
        all_jobs=$(echo "${all_jobs}" | jq -c '[.[] | del(.steps)]' 2>/dev/null) || true
    fi

    # Step 6: Slim down output — keep essential fields only
    all_jobs=$(echo "${all_jobs}" | jq -c '[.[] | {id, name, status, conclusion, html_url, started_at, completed_at, run, steps}]' 2>/dev/null) || true

    _gh_post_process "${all_jobs}" "${jq_filter}" "" 0 0 false false "${max_lines}" "" || return $?
}
