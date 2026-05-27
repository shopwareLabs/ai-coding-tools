#!/usr/bin/env bash
# Release lookup tools for gh-tooling MCP server
# Tools: release_list

# List GitHub releases for one or more repositories with semver-aware filtering.
# Collapses the repetitive "one api_read per repo" pattern used for dependency
# updates into a single call. Goes beyond /releases/latest with prerelease
# handling, major / major.minor pinning, and optional tag -> commit SHA resolution.
#
# GitHub's /releases endpoint returns by created_at descending, NOT by semver, so
# this tool re-sorts the filtered set by numeric version components in jq and
# treats the highest version as "latest".
#
# Maps to: gh api repos/{owner}/{repo}/releases?per_page={limit}
tool_release_list() {
    local args="$1"

    local latest constraint include_prereleases include_drafts limit resolve_sha
    local jq_filter suppress_errors fallback
    local fields_count fields_json
    # jq's // treats false as a fallthrough, so '.latest // true' would wrongly
    # yield true when the caller passes false; use has() to read it verbatim.
    latest=$(echo "${args}" | jq -r 'if has("latest") then .latest else true end')
    constraint=$(echo "${args}" | jq -r '.constraint // empty')
    include_prereleases=$(echo "${args}" | jq -r '.include_prereleases // false')
    include_drafts=$(echo "${args}" | jq -r '.include_drafts // false')
    limit=$(echo "${args}" | jq -r '.limit // 30')
    resolve_sha=$(echo "${args}" | jq -r '.resolve_sha // false')
    jq_filter=$(echo "${args}" | jq -r '.jq_filter // empty')
    suppress_errors=$(echo "${args}" | jq -r '.suppress_errors // false')
    fallback=$(echo "${args}" | jq -r '.fallback // empty')

    _gh_validate_jq_filter "${jq_filter}" || return 1
    _gh_validate_number "${limit}" "limit" || return 1

    # Constraint is a version prefix: major ("4"/"v4") or major.minor ("4.2"/"v4.2").
    # Range operators (^, ~, >=, <) are intentionally out of scope; reject them
    # rather than silently returning every release.
    if [[ -n "${constraint}" ]] && [[ ! "${constraint}" =~ ^v?[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Error: constraint must be a major ('4'/'v4') or major.minor ('4.2'/'v4.2') version prefix, got: '${constraint}'"
        return 1
    fi

    # 'fields' lets the caller project only the data they need (e.g. just
    # ["tag_name"] for version numbers). Reject unknown keys rather than dropping
    # them silently, so a typo surfaces instead of returning an unexpected shape.
    fields_count=$(echo "${args}" | jq '(.fields // []) | length')
    if [[ "${fields_count}" -gt 0 ]]; then
        local bad
        bad=$(echo "${args}" | jq -r '
            ["repo","tag_name","name","published_at","html_url","prerelease","draft","commit_sha"] as $allowed
            | [.fields[] | . as $f | select(($allowed | index($f)) | not)] | join(", ")')
        if [[ -n "${bad}" ]]; then
            echo "Error: unknown field(s): ${bad}. Allowed: repo, tag_name, name, published_at, html_url, prerelease, draft, commit_sha"
            return 1
        fi
    fi

    # Build the repo list: explicit batch via 'repos', else single-repo resolution.
    local -a repo_list=()
    local repos_count
    repos_count=$(echo "${args}" | jq '(.repos // []) | length')
    if [[ "${repos_count}" -gt 0 ]]; then
        local r
        while IFS= read -r r; do
            [[ -z "${r}" ]] && continue
            _gh_validate_repo "${r}" || return 1
            repo_list+=("${r}")
        done < <(echo "${args}" | jq -r '.repos[]')
    else
        _gh_resolve_owner_repo "${args}" || return 1
        repo_list+=("${_GH_OWNER}/${_GH_REPO}")
    fi

    local per_page="${limit}"
    [[ "${per_page}" -gt 100 ]] && per_page=100

    # jq program: filter drafts/prereleases, parse numeric version tuple, apply
    # the constraint prefix, sort by version descending, optionally keep only the
    # top match, and project a stable output shape.
    local program
    # shellcheck disable=SC2016  # $constraint/$incpre/etc. are jq variables, not shell
    program='
        def vparts: [scan("[0-9]+") | tonumber];
        ($constraint | ltrimstr("v") | vparts) as $cparts
        | [ .[]
            | select(.draft == false or $incdraft)
            | select(.prerelease == false or $incpre)
            | . + {_v: (.tag_name | ltrimstr("v") | vparts)}
            | select(($cparts | length) == 0 or (._v[0:($cparts | length)] == $cparts))
          ]
        | sort_by(._v) | reverse
        | (if $latest_only then .[0:1] else . end)
        | map({repo: $repo, tag_name, name, published_at, html_url, prerelease, draft})
    '

    local all='[]'
    local owner_repo owner repo_name endpoint repo_result
    local -a cmd
    local __raw __exit
    for owner_repo in "${repo_list[@]}"; do
        owner="${owner_repo%%/*}"
        repo_name="${owner_repo#*/}"
        endpoint="repos/${owner}/${repo_name}/releases?per_page=${per_page}"
        cmd=("gh" "api" "${endpoint}")

        log "INFO" "release_list: ${cmd[*]}"
        __raw=""
        __exit=0
        if [[ "${suppress_errors}" == "true" ]]; then
            __raw=$("${cmd[@]}" 2>/dev/null) || __exit=$?
        else
            __raw=$("${cmd[@]}" 2>&1) || __exit=$?
        fi
        if [[ ${__exit} -ne 0 ]]; then
            [[ -n "${fallback}" ]] && { echo "${fallback}"; return 0; }
            [[ "${suppress_errors}" == "true" ]] && continue
            echo "${__raw}"; return ${__exit}
        fi

        repo_result=$(echo "${__raw}" | jq -c \
            --arg repo "${owner}/${repo_name}" \
            --argjson latest_only "${latest}" \
            --argjson incpre "${include_prereleases}" \
            --argjson incdraft "${include_drafts}" \
            --arg constraint "${constraint}" \
            "${program}") || {
            echo "Error: failed to process releases for ${owner}/${repo_name}"
            return 1
        }

        # Resolve each tag to its commit SHA (correct for lightweight and annotated
        # tags) when requested. One extra API call per result; opt-in only.
        if [[ "${resolve_sha}" == "true" ]]; then
            local tag sha
            while IFS= read -r tag; do
                [[ -z "${tag}" ]] && continue
                sha=$(gh api "repos/${owner}/${repo_name}/commits/${tag}" --jq '.sha' 2>/dev/null) || sha=""
                repo_result=$(echo "${repo_result}" | jq -c \
                    --arg t "${tag}" --arg s "${sha}" \
                    'map(if .tag_name == $t then . + {commit_sha: $s} else . end)')
            done < <(echo "${repo_result}" | jq -r '.[].tag_name')
        fi

        all=$(echo "${all} ${repo_result}" | jq -cs 'add')
    done

    # Project to the requested fields after resolve_sha has merged commit_sha in,
    # so ["commit_sha"] works and field order stays predictable.
    if [[ "${fields_count}" -gt 0 ]]; then
        fields_json=$(echo "${args}" | jq -c '.fields')
        all=$(echo "${all}" | jq -c --argjson fields "${fields_json}" \
            'map(with_entries(select(.key as $k | $fields | index($k))))')
    fi

    local output="${all}"
    if [[ -n "${jq_filter}" ]]; then
        output=$(echo "${output}" | jq "${jq_filter}") || {
            echo "Error: jq filter failed on output: ${jq_filter}"
            return 1
        }
    else
        output=$(echo "${output}" | jq '.')
    fi

    echo "${output}"
}
