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
