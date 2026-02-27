#!/usr/bin/env bash
# Search tools for gh-tooling MCP server
# Tools: search, search_code, search_repos, search_commits, search_discussions

# Search for GitHub issues or pull requests using a query string.
# Maps to: gh search issues|prs <query> [--repo] [--state] [--limit] [--json]
# Also supports the low-level: gh api search/issues -X GET -f q="..." -f per_page=N
tool_search() {
    local args="$1"

    local query type repo state limit fields jq_filter suppress_errors fallback
    query=$(echo "${args}" | jq -r '.query // empty')
    type=$(echo "${args}" | jq -r '.type // "prs"')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    state=$(echo "${args}" | jq -r '.state // empty')
    limit=$(echo "${args}" | jq -r '.limit // 20')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${query}" ]]; then
        echo "Error: query is required for search"
        return 1
    fi

    if [[ "${type}" != "issues" && "${type}" != "prs" ]]; then
        echo "Error: type must be 'issues' or 'prs', got: '${type}'"
        return 1
    fi

    _gh_validate_jq_filter "${jq_filter}" || return 1

    local effective_repo
    effective_repo=$(_gh_resolve_repo "${repo}")

    _gh_validate_number "${limit}" "limit" || return 1

    local -a cmd=("gh" "search" "${type}" "${query}")

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    fi

    [[ -n "${state}" ]] && cmd+=("--state" "${state}")
    cmd+=("--limit" "${limit}")
    [[ -n "${fields}" ]] && cmd+=("--json" "${fields}")

    log "INFO" "search: ${cmd[*]}"
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

# Search for code across GitHub repositories.
# Uses the legacy code search engine (no regex, no symbol search, no path globs).
# Rate limit: 10 requests/minute (separate bucket from other search endpoints).
# Maps to: gh search code <query> [--repo] [--language] [--extension] [--filename] [--match] [--limit] [--json]
tool_search_code() {
    local args="$1"

    local query owner repo language extension filename match limit fields
    local jq_filter grep_pattern grep_before grep_after grep_ignore_case grep_invert
    local max_lines tail_lines suppress_errors fallback download_to
    query=$(echo "${args}" | jq -r '.query // empty')
    owner=$(echo "${args}" | jq -r '.owner // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    language=$(echo "${args}" | jq -r '.language // empty')
    extension=$(echo "${args}" | jq -r '.extension // empty')
    filename=$(echo "${args}" | jq -r '.filename // empty')
    match=$(echo "${args}" | jq -r '.match // empty')
    limit=$(echo "${args}" | jq -r '.limit // 30')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    grep_pattern=$(echo "${args}" | jq -r '.grep_pattern // empty')
    grep_before=$(echo "${args}" | jq -r '.grep_context_before // 0')
    grep_after=$(echo "${args}" | jq -r '.grep_context_after // 0')
    grep_ignore_case=$(echo "${args}" | jq -r '.grep_ignore_case // false')
    grep_invert=$(echo "${args}" | jq -r '.grep_invert // false')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')
    tail_lines=$(echo "${args}" | jq -r '.tail_lines // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')
    download_to=$(echo "${args}" | jq -r '.download_to // empty')

    if [[ -z "${query}" ]]; then
        echo "Error: query is required for search_code"
        return 1
    fi

    if [[ -n "${match}" && "${match}" != "file" && "${match}" != "path" ]]; then
        echo "Error: match must be 'file' or 'path', got: '${match}'"
        return 1
    fi

    _gh_validate_jq_filter "${jq_filter}" || return 1
    _gh_validate_number "${limit}" "limit" || return 1

    local -a cmd=("gh" "search" "code" "${query}")

    # Resolve repo: explicit param > GH_DEFAULT_REPO (consistent with tool_search)
    local effective_repo
    if [[ -n "${repo}" ]]; then
        effective_repo="${repo}"
    else
        effective_repo="${GH_DEFAULT_REPO:-}"
    fi

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    elif [[ -n "${owner}" ]]; then
        cmd+=("--owner" "${owner}")
    fi

    [[ -n "${language}" ]]  && cmd+=("--language" "${language}")
    [[ -n "${extension}" ]] && cmd+=("--extension" "${extension}")
    [[ -n "${filename}" ]]  && cmd+=("--filename" "${filename}")
    [[ -n "${match}" ]]     && cmd+=("--match" "${match}")
    cmd+=("--limit" "${limit}")

    local default_fields="repository,path,textMatch"
    [[ -n "${fields}" ]] && cmd+=("--json" "${fields}") || cmd+=("--json" "${default_fields}")

    log "INFO" "search_code: ${cmd[*]}"
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

    # download_to mode: save matching files locally
    if [[ -n "${download_to}" ]]; then
        local count=0 errors=0
        local entries
        entries=$(echo "${__raw}" | jq -r '.[] | "\(.repository.nameWithOwner)\t\(.path)"' 2>/dev/null) || {
            echo "Error: could not parse search results for download"
            return 1
        }
        while IFS=$'\t' read -r name_with_owner file_path; do
            [[ -z "${name_with_owner}" ]] && continue
            local dl_owner="${name_with_owner%%/*}"
            local dl_repo="${name_with_owner#*/}"
            local local_path="${download_to}/${name_with_owner}/${file_path}"
            if _gh_download_file "${dl_owner}" "${dl_repo}" "${file_path}" "${local_path}"; then
                count=$((count + 1))
            else
                errors=$((errors + 1))
            fi
        done <<< "${entries}"
        echo "Downloaded ${count} files to ${download_to} (${errors} errors)"
        return 0
    fi

    _gh_post_process "${__raw}" "${jq_filter}" "${grep_pattern}" "${grep_before}" \
        "${grep_after}" "${grep_ignore_case}" "${grep_invert}" "${max_lines}" "${tail_lines}" || return $?
}

# Search for GitHub repositories.
# Query is optional — filters alone (owner, topic, language, stars) suffice.
# Maps to: gh search repos [query] [--owner] [--topic] [--language] [--license] [--stars] [--sort] [--limit] [--json]
tool_search_repos() {
    local args="$1"

    local query owner topic language license stars sort limit fields
    local jq_filter max_lines suppress_errors fallback
    query=$(echo "${args}" | jq -r '.query // empty')
    owner=$(echo "${args}" | jq -r '.owner // empty')
    topic=$(echo "${args}" | jq -r '.topic // empty')
    language=$(echo "${args}" | jq -r '.language // empty')
    license=$(echo "${args}" | jq -r '.license // empty')
    stars=$(echo "${args}" | jq -r '.stars // empty')
    sort=$(echo "${args}" | jq -r '.sort // empty')
    limit=$(echo "${args}" | jq -r '.limit // 20')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -n "${sort}" ]]; then
        case "${sort}" in
            stars|forks|help-wanted-issues|updated) ;;
            *)
                echo "Error: sort must be 'stars', 'forks', 'help-wanted-issues', or 'updated', got: '${sort}'"
                return 1
                ;;
        esac
    fi

    _gh_validate_jq_filter "${jq_filter}" || return 1
    _gh_validate_number "${limit}" "limit" || return 1

    local -a cmd=("gh" "search" "repos")
    [[ -n "${query}" ]]    && cmd+=("${query}")
    [[ -n "${owner}" ]]    && cmd+=("--owner" "${owner}")
    [[ -n "${topic}" ]]    && cmd+=("--topic" "${topic}")
    [[ -n "${language}" ]] && cmd+=("--language" "${language}")
    [[ -n "${license}" ]]  && cmd+=("--license" "${license}")
    [[ -n "${stars}" ]]    && cmd+=("--stars" "${stars}")
    [[ -n "${sort}" ]]     && cmd+=("--sort" "${sort}")
    cmd+=("--limit" "${limit}")

    local default_fields="fullName,description,stargazersCount,language,updatedAt,url"
    [[ -n "${fields}" ]] && cmd+=("--json" "${fields}") || cmd+=("--json" "${default_fields}")

    log "INFO" "search_repos: ${cmd[*]}"
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

# Search for GitHub commits.
# Maps to: gh search commits <query> [--repo] [--owner] [--author] [--committer] [--author-date] [--committer-date] [--hash] [--merge] [--sort] [--limit] [--json]
tool_search_commits() {
    local args="$1"

    local query repo owner author committer author_date committer_date hash merge sort limit fields
    local jq_filter suppress_errors fallback
    query=$(echo "${args}" | jq -r '.query // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    owner=$(echo "${args}" | jq -r '.owner // empty')
    author=$(echo "${args}" | jq -r '.author // empty')
    committer=$(echo "${args}" | jq -r '.committer // empty')
    author_date=$(echo "${args}" | jq -r '.author_date // empty')
    committer_date=$(echo "${args}" | jq -r '.committer_date // empty')
    hash=$(echo "${args}" | jq -r '.hash // empty')
    merge=$(echo "${args}" | jq -r '.merge // empty')
    sort=$(echo "${args}" | jq -r '.sort // empty')
    limit=$(echo "${args}" | jq -r '.limit // 20')
    fields=$(echo "${args}" | jq -r '.fields // empty')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${query}" ]]; then
        echo "Error: query is required for search_commits"
        return 1
    fi

    if [[ -n "${sort}" ]]; then
        case "${sort}" in
            author-date|committer-date) ;;
            *)
                echo "Error: sort must be 'author-date' or 'committer-date', got: '${sort}'"
                return 1
                ;;
        esac
    fi

    _gh_validate_jq_filter "${jq_filter}" || return 1
    _gh_validate_number "${limit}" "limit" || return 1

    local -a cmd=("gh" "search" "commits" "${query}")

    # Resolve repo: explicit param > GH_DEFAULT_REPO (consistent with tool_search)
    local effective_repo
    if [[ -n "${repo}" ]]; then
        effective_repo="${repo}"
    else
        effective_repo="${GH_DEFAULT_REPO:-}"
    fi

    if [[ -n "${effective_repo}" ]]; then
        _gh_validate_repo "${effective_repo}" || return 1
        cmd+=("--repo" "${effective_repo}")
    elif [[ -n "${owner}" ]]; then
        cmd+=("--owner" "${owner}")
    fi

    [[ -n "${author}" ]]         && cmd+=("--author" "${author}")
    [[ -n "${committer}" ]]      && cmd+=("--committer" "${committer}")
    [[ -n "${author_date}" ]]    && cmd+=("--author-date" "${author_date}")
    [[ -n "${committer_date}" ]] && cmd+=("--committer-date" "${committer_date}")
    [[ -n "${hash}" ]]           && cmd+=("--hash" "${hash}")
    [[ "${merge}" == "true" ]]   && cmd+=("--merge")
    [[ "${merge}" == "false" ]]  && cmd+=("--merge=false")
    [[ -n "${sort}" ]]           && cmd+=("--sort" "${sort}")
    cmd+=("--limit" "${limit}")

    local default_fields="sha,commit"
    [[ -n "${fields}" ]] && cmd+=("--json" "${fields}") || cmd+=("--json" "${default_fields}")

    log "INFO" "search_commits: ${cmd[*]}"
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

# Search for GitHub discussions using GraphQL.
# Discussions are only available via GraphQL (no gh search discussions subcommand).
# Maps to: gh api graphql with search() query
tool_search_discussions() {
    local args="$1"

    local query repo category author state with_comments limit
    local jq_filter max_lines tail_lines suppress_errors fallback
    query=$(echo "${args}" | jq -r '.query // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    category=$(echo "${args}" | jq -r '.category // empty')
    author=$(echo "${args}" | jq -r '.author // empty')
    state=$(echo "${args}" | jq -r '.state // empty')
    with_comments=$(echo "${args}" | jq -r '.with_comments // false')
    limit=$(echo "${args}" | jq -r '.limit // 20')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    max_lines=$(echo "${args}" | jq -r '.max_lines // empty')
    tail_lines=$(echo "${args}" | jq -r '.tail_lines // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    if [[ -z "${query}" ]]; then
        echo "Error: query is required for search_discussions"
        return 1
    fi

    _gh_validate_jq_filter "${jq_filter}" || return 1
    _gh_validate_number "${limit}" "limit" || return 1

    # Build the search query string
    local search_query="${query}"
    local effective_repo
    if [[ -n "${repo}" ]]; then
        _gh_validate_repo "${repo}" || return 1
        effective_repo="${repo}"
    else
        effective_repo="${GH_DEFAULT_REPO:-}"
    fi
    [[ -n "${effective_repo}" ]] && search_query="repo:${effective_repo} ${search_query}"
    [[ -n "${category}" ]]       && search_query="category:${category} ${search_query}"
    [[ -n "${author}" ]]         && search_query="author:${author} ${search_query}"
    [[ -n "${state}" ]]          && search_query="${state} ${search_query}"

    # Escape for GraphQL string interpolation: backslashes first, then double quotes, then newlines
    search_query="${search_query//\\/\\\\}"
    search_query="${search_query//\"/\\\"}"
    search_query="${search_query//$'\n'/\\n}"

    # Build comments fragment based on with_comments toggle
    local comments_fragment
    if [[ "${with_comments}" == "true" ]]; then
        comments_fragment='comments(first: 20) { nodes { body author { login } isAnswer replies(first: 5) { nodes { body author { login } } } } }'
    else
        comments_fragment='comments { totalCount }'
    fi

    local graphql_query
    graphql_query=$(cat <<GRAPHQL
{
  search(query: "${search_query} type:discussion", type: DISCUSSION, first: ${limit}) {
    nodes {
      ... on Discussion {
        number
        title
        url
        author { login }
        category { name }
        createdAt
        answerChosenAt
        ${comments_fragment}
      }
    }
  }
}
GRAPHQL
)

    local -a cmd=("gh" "api" "graphql" "-f" "query=${graphql_query}")

    log "INFO" "search_discussions: graphql search for '${query}'"
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

    # Extract just the nodes array for cleaner output
    local default_jq='.data.search.nodes'
    local effective_jq="${jq_filter:-${default_jq}}"
    __raw=$(echo "${__raw}" | jq "${effective_jq}") || {
        echo "Error: jq filter failed on output: ${effective_jq}"
        return 1
    }

    _gh_post_process "${__raw}" "" "" 0 0 false false "${max_lines}" "${tail_lines}" || return $?
}
