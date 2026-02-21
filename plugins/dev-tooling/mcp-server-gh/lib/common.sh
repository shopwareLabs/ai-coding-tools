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
