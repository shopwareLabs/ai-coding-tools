#!/usr/bin/env bash
# Common utilities for gh-tooling MCP server
# Provides input validation and repo resolution helpers

# Validate a GitHub number (PR, issue, run, job ID - positive integer)
# Args: $1 = value, $2 = field name for error message
# Outputs error message to stdout and returns 1 on failure
_gh_validate_number() {
    local value="$1"
    local field="${2:-number}"
    if [[ -z "${value}" ]] || [[ ! "${value}" =~ ^[0-9]+$ ]]; then
        echo "Error: ${field} must be a positive integer, got: '${value}'"
        return 1
    fi
}

# Validate a GitHub repository in owner/repo format
# Args: $1 = repo string (empty is allowed - means use default)
# Outputs error message to stdout and returns 1 on invalid format
_gh_validate_repo() {
    local repo="$1"
    [[ -z "${repo}" ]] && return 0
    if [[ ! "${repo}" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
        echo "Error: repo must be in 'owner/repo' format, got: '${repo}'"
        return 1
    fi
}

# Validate a git commit SHA (7-40 hex characters)
# Args: $1 = sha string
_gh_validate_sha() {
    local sha="$1"
    if [[ -z "${sha}" ]] || [[ ! "${sha}" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
        echo "Error: sha must be a valid git commit hash (7-40 hex chars), got: '${sha}'"
        return 1
    fi
}

# Resolve the effective repository to use for an API call.
# Uses the provided repo arg first, then falls back to GH_DEFAULT_REPO.
# Args: $1 = repo from tool arguments (may be empty)
# Outputs: resolved repo string, or empty if none configured
_gh_resolve_repo() {
    local repo_arg="${1:-}"
    echo "${repo_arg:-${GH_DEFAULT_REPO:-}}"
}

# Assert that a repo is available (either passed or configured as default).
# Outputs error and returns 1 if no repo available.
# Args: $1 = effective repo string (from _gh_resolve_repo)
_gh_require_repo() {
    local effective_repo="$1"
    if [[ -z "${effective_repo}" ]]; then
        echo "Error: repo is required. Pass 'repo' argument or set 'repo' in .mcp-gh-tooling.json"
        return 1
    fi
}

# Read a value from the gh-tooling config file
# Args: $1 = jq path (e.g. '.repo'), $2 = default value
_gh_config_value() {
    local path="$1"
    local default="${2:-}"
    [[ -f "${GH_TOOLING_CONFIG_FILE:-}" ]] || { echo "${default}"; return 0; }
    local value
    value=$(jq -r "${path} // empty" "${GH_TOOLING_CONFIG_FILE}" 2>/dev/null || echo "")
    [[ -n "${value}" ]] && echo "${value}" || echo "${default}"
}

# Validate jq filter syntax before execution.
# Only rejects definitive compile/parse/lexical errors; runtime errors on null are acceptable.
# Args: $1 = filter expression, $2 = field name for error message (default: jq_filter)
# Outputs error message to stdout and returns 1 on compile-time syntax failure.
_gh_validate_jq_filter() {
    local filter="$1"
    local field="${2:-jq_filter}"
    [[ -z "${filter}" ]] && return 0
    local err
    err=$(jq -n "${filter}" 2>&1 1>/dev/null) || true
    if [[ -n "${err}" ]] && echo "${err}" | grep -qiE "compile error|unexpected \\\$end|parse error|lexical error"; then
        echo "Error: Invalid ${field}: ${err}"
        return 1
    fi
}

# Apply optional pipeline post-processing steps in order: jq → grep → head → tail.
# Each step is a no-op when its controlling parameter is empty/zero.
# Args: $1=output $2=jq_filter $3=grep_pattern $4=grep_before $5=grep_after
#       $6=grep_ignore_case $7=grep_invert $8=max_lines $9=tail_lines
# Outputs processed text to stdout; returns 1 if jq filter fails on the output.
_gh_post_process() {
    local output="$1"
    local jq_filter="${2:-}"
    local grep_pattern="${3:-}"
    local grep_before="${4:-0}"
    local grep_after="${5:-0}"
    local grep_ignore_case="${6:-false}"
    local grep_invert="${7:-false}"
    local max_lines="${8:-}"
    local tail_lines="${9:-}"

    if [[ -n "${jq_filter}" ]]; then
        output=$(echo "${output}" | jq "${jq_filter}") || {
            echo "Error: jq filter failed on output: ${jq_filter}"
            return 1
        }
    fi

    if [[ -n "${grep_pattern}" ]]; then
        local -a gcmd=("grep" "-E")
        [[ "${grep_ignore_case}" == "true" ]] && gcmd+=("-i")
        [[ "${grep_invert}" == "true" ]]      && gcmd+=("-v")
        [[ "${grep_before}" -gt 0 ]]          && gcmd+=("-B" "${grep_before}")
        [[ "${grep_after}" -gt 0 ]]           && gcmd+=("-A" "${grep_after}")
        gcmd+=("--" "${grep_pattern}")
        output=$(echo "${output}" | "${gcmd[@]}") || true
    fi

    if [[ -n "${max_lines}" && "${max_lines}" -gt 0 ]]; then
        output=$(echo "${output}" | head -n "${max_lines}")
    fi

    if [[ -n "${tail_lines}" && "${tail_lines}" -gt 0 ]]; then
        output=$(echo "${output}" | tail -n "${tail_lines}")
    fi

    echo "${output}"
}

# Parse a GitHub URL into owner, repo, ref, and path components.
# Handles /tree/{ref}/{path} and /blob/{ref}/{path} URLs.
# Sets globals: _GH_URL_OWNER, _GH_URL_REPO, _GH_URL_REF, _GH_URL_PATH
# Returns 1 for non-GitHub URLs or unrecognized formats.
# Limitation: refs with slashes (e.g. feature/branch) take only the first segment.
_gh_parse_github_url() {
    local url="$1"
    _GH_URL_OWNER="" _GH_URL_REPO="" _GH_URL_REF="" _GH_URL_PATH=""

    # Must be a github.com URL
    if [[ ! "${url}" =~ ^https?://github\.com/ ]]; then
        return 1
    fi

    # Strip scheme and host
    local path_part="${url#*github.com/}"

    # Extract owner/repo (first two segments)
    local owner repo remainder
    owner="${path_part%%/*}"
    remainder="${path_part#*/}"
    repo="${remainder%%/*}"
    remainder="${remainder#*/}"

    if [[ -z "${owner}" || -z "${repo}" ]]; then
        return 1
    fi

    # Strip .git suffix if present
    repo="${repo%.git}"

    _GH_URL_OWNER="${owner}"
    _GH_URL_REPO="${repo}"

    # If there's nothing beyond owner/repo, we're done
    if [[ "${path_part}" == "${owner}/${repo}" || "${remainder}" == "${repo}" ]]; then
        return 0
    fi

    # Check for tree/ or blob/ prefix
    local kind="${remainder%%/*}"
    if [[ "${kind}" == "tree" || "${kind}" == "blob" ]]; then
        remainder="${remainder#*/}"
        # First segment after tree/blob is the ref
        _GH_URL_REF="${remainder%%/*}"
        # Everything after ref is the path
        local after_ref="${remainder#*/}"
        if [[ "${after_ref}" != "${_GH_URL_REF}" ]]; then
            _GH_URL_PATH="${after_ref}"
        fi
    fi

    return 0
}

# Validate a file path (reject traversal and leading slash).
# Empty path is valid (means repo root).
# Args: $1 = path string
_gh_validate_path() {
    local path="$1"
    [[ -z "${path}" ]] && return 0
    if [[ "${path}" == /* ]]; then
        echo "Error: path must not start with '/': ${path}"
        return 1
    fi
    if [[ "${path}" == *".."* ]]; then
        echo "Error: path must not contain '..': ${path}"
        return 1
    fi
}

# Download a file from GitHub to a local path.
# Args: $1=owner, $2=repo, $3=remote_path, $4=local_path, $5=ref (optional)
_gh_download_file() {
    local owner="$1" repo="$2" remote_path="$3" local_path="$4" ref="${5:-}"
    local -a cmd=("gh" "api" "repos/${owner}/${repo}/contents/${remote_path}")
    [[ -n "${ref}" ]] && cmd+=("-f" "ref=${ref}")
    cmd+=("-H" "Accept: application/vnd.github.raw+json")

    local parent_dir
    parent_dir=$(dirname "${local_path}")
    mkdir -p "${parent_dir}" 2>/dev/null || {
        echo "Error: cannot create directory ${parent_dir}"
        return 1
    }
    "${cmd[@]}" > "${local_path}" 2>&1 || {
        echo "Error: failed to download ${owner}/${repo}/${remote_path}"
        return 1
    }
}

# Resolve owner/repo from multiple sources with priority:
# url > owner+repo > repository (owner/repo string) > GH_DEFAULT_REPO
# Sets globals: _GH_OWNER, _GH_REPO, _GH_REF, _GH_PATH
# Args: $1=JSON args string
_gh_resolve_owner_repo() {
    local args="$1"
    _GH_OWNER="" _GH_REPO="" _GH_REF="" _GH_PATH=""

    local url owner repo repository ref path
    url=$(echo "${args}" | jq -r '.url // empty')
    owner=$(echo "${args}" | jq -r '.owner // empty')
    repo=$(echo "${args}" | jq -r '.repo // empty')
    repository=$(echo "${args}" | jq -r '.repository // empty')
    ref=$(echo "${args}" | jq -r '.ref // empty')
    path=$(echo "${args}" | jq -r '.path // empty')

    # Priority 1: URL
    if [[ -n "${url}" ]]; then
        _gh_parse_github_url "${url}" || {
            echo "Error: could not parse GitHub URL: ${url}"
            return 1
        }
        _GH_OWNER="${_GH_URL_OWNER}"
        _GH_REPO="${_GH_URL_REPO}"
        [[ -n "${_GH_URL_REF}" ]] && _GH_REF="${_GH_URL_REF}"
        [[ -n "${_GH_URL_PATH}" ]] && _GH_PATH="${_GH_URL_PATH}"
        # Explicit params override URL-extracted values
        [[ -n "${ref}" ]] && _GH_REF="${ref}"
        [[ -n "${path}" ]] && _GH_PATH="${path}"
        return 0
    fi

    # Priority 2: explicit owner + repo
    if [[ -n "${owner}" && -n "${repo}" ]]; then
        _GH_OWNER="${owner}"
        _GH_REPO="${repo}"
        _GH_REF="${ref}"
        _GH_PATH="${path}"
        return 0
    fi

    # Priority 3: repository (owner/repo format)
    if [[ -n "${repository}" ]]; then
        _gh_validate_repo "${repository}" || return 1
        _GH_OWNER="${repository%%/*}"
        _GH_REPO="${repository#*/}"
        _GH_REF="${ref}"
        _GH_PATH="${path}"
        return 0
    fi

    # Priority 4: GH_DEFAULT_REPO
    if [[ -n "${GH_DEFAULT_REPO:-}" ]]; then
        _GH_OWNER="${GH_DEFAULT_REPO%%/*}"
        _GH_REPO="${GH_DEFAULT_REPO#*/}"
        _GH_REF="${ref}"
        _GH_PATH="${path}"
        return 0
    fi

    echo "Error: repository is required. Provide 'url', 'owner'+'repo', 'repository', or set 'repo' in .mcp-gh-tooling.json"
    return 1
}
