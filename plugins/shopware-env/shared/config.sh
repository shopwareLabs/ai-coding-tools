#!/usr/bin/env bash
# Configuration discovery and merging for MCP Servers
# Supports environment variable override and multiple config file locations
# with deep merging (later files override earlier ones)
#
# Required: CONFIG_PREFIX must be set before sourcing (e.g., "php-tooling", "js-tooling")
#
# Environment variable: MCP_<PREFIX>_CONFIG (absolute path to config file)
#   - php-tooling: MCP_PHP_TOOLING_CONFIG
#   - js-tooling: MCP_JS_TOOLING_CONFIG
#
# Default locations: every entry of the CONFIG_LOCATIONS array below, in merge
# order (later wins)
#
# Usage: export CONFIG_PREFIX="php-tooling"
#        source this file after mcpserver_core.sh (needs log function)
#        then call: load_config "$PROJECT_ROOT"
#        Result: LINT_CONFIG_FILE is set and exported. When more than one file
#        is found and they cannot be merged, or the override names a missing
#        file, load_config fails and CONFIG_LOAD_ERROR names the cause; it is
#        empty after any other outcome.

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

if [[ -z "${CONFIG_PREFIX:-}" ]]; then
    echo "ERROR: CONFIG_PREFIX must be set before sourcing config.sh" >&2
    exit 1
fi

# Generate config file name and environment variable from prefix:
#   php-tooling -> .mcp-php-tooling.json, MCP_PHP_TOOLING_CONFIG
CONFIG_FILE_NAME=".mcp-${CONFIG_PREFIX}.json"
CONFIG_ENV_VAR="MCP_${CONFIG_PREFIX^^}_CONFIG"
CONFIG_ENV_VAR="${CONFIG_ENV_VAR//-/_}"

# Configuration locations relative to PROJECT_ROOT
# Order: base -> override (later entries have higher priority)
# Supports directories from popular LLM coding tools
CONFIG_LOCATIONS=(
    "${CONFIG_FILE_NAME}"
    ".aiassistant/${CONFIG_FILE_NAME}"
    ".amazonq/${CONFIG_FILE_NAME}"
    ".cline/${CONFIG_FILE_NAME}"
    ".cursor/${CONFIG_FILE_NAME}"
    ".kiro/${CONFIG_FILE_NAME}"
    ".windsurf/${CONFIG_FILE_NAME}"
    ".zed/${CONFIG_FILE_NAME}"
    ".claude/${CONFIG_FILE_NAME}"
)

_CONFIG_TEMP_FILE=""
CONFIG_LOAD_ERROR=""

# Removes the merged-config temp file _merge_configs created, if any.
# Installed below as the module's own EXIT trap; a caller whose EXIT trap
# runs after this one is sourced (e.g. worktree state cleanup) calls this
# directly so the removal still happens once that trap replaces this one.
config_cleanup() {
    if [[ -n "${_CONFIG_TEMP_FILE}" && -f "${_CONFIG_TEMP_FILE}" ]]; then
        rm -f "${_CONFIG_TEMP_FILE}"
    fi
}
trap config_cleanup EXIT

# Called directly, not in a command substitution, so the EXIT trap sees _CONFIG_TEMP_FILE.
# Args: config file paths (merge order, later wins)
# Sets: LINT_CONFIG_FILE and _CONFIG_TEMP_FILE to the temp file on success;
#       CONFIG_LOAD_ERROR to the logged cause on failure
# Returns: 0 on success, 1 otherwise
_merge_configs() {
    # Each file is checked on its own so the refusal names the one at fault.
    local config_file
    for config_file in "$@"; do
        if ! jq -e 'type == "object"' "${config_file}" >/dev/null 2>&1; then
            CONFIG_LOAD_ERROR="${config_file} is not valid JSON: a config file must hold one JSON object"
            log "ERROR" "${CONFIG_LOAD_ERROR}"
            return 1
        fi
    done

    local merged
    merged=$(cat "$1")
    shift

    # Deep merge remaining files (jq -s '.[0] * .[1]' merges recursively)
    for config_file in "$@"; do
        merged=$(jq -s '.[0] * .[1]' - "${config_file}" <<< "${merged}")
    done

    local temp_file
    temp_file=$(mktemp)
    _CONFIG_TEMP_FILE="${temp_file}"
    printf '%s\n' "${merged}" > "${temp_file}"
    LINT_CONFIG_FILE="${temp_file}"
}

# Sets: _FOUND_CONFIGS array with absolute paths
_discover_configs() {
    local project_root="$1"
    _FOUND_CONFIGS=()

    for location in "${CONFIG_LOCATIONS[@]}"; do
        local full_path="${project_root}/${location}"
        if [[ -f "${full_path}" ]]; then
            _FOUND_CONFIGS+=("${full_path}")
            log "INFO" "Found config: ${full_path}"
        fi
    done
}

# Load and merge configuration
# Sets: LINT_CONFIG_FILE (path to config file, possibly merged temp file);
#       CONFIG_LOAD_ERROR (empty unless the override file is missing or the
#       merge failed)
# Args: $1 = project root directory
# Returns: 0 on success, 1 on error (logs error message)
#
# Priority:
#   1. Environment variable (CONFIG_ENV_VAR, e.g., MCP_PHP_TOOLING_CONFIG)
#   2. Config files from CONFIG_LOCATIONS (merged if multiple exist)
#
# Error conditions:
#   - Environment variable set but file doesn't exist
#   - No config files found at any location
#   - More than one found and one of them does not hold a JSON object
load_config() {
    local project_root="$1"
    CONFIG_LOAD_ERROR=""

    local env_value="${!CONFIG_ENV_VAR:-}"
    if [[ -n "${env_value}" ]]; then
        log "INFO" "Using config from environment variable ${CONFIG_ENV_VAR}: ${env_value}"

        if [[ ! -f "${env_value}" ]]; then
            CONFIG_LOAD_ERROR="Config file from ${CONFIG_ENV_VAR} not found: ${env_value}"
            log "ERROR" "${CONFIG_LOAD_ERROR}"
            return 1
        fi

        LINT_CONFIG_FILE="${env_value}"
        export LINT_CONFIG_FILE
        return 0
    fi

    _discover_configs "${project_root}"

    if [[ ${#_FOUND_CONFIGS[@]} -eq 0 ]]; then
        log "ERROR" "No config file found"
        log "ERROR" "Create ${CONFIG_FILE_NAME} in project root or any supported tool directory"
        log "ERROR" "Supported: .claude/, .cursor/, .windsurf/, .zed/, .cline/, .aiassistant/, .amazonq/, .kiro/"
        log "ERROR" "Or set ${CONFIG_ENV_VAR} environment variable"
        return 1
    fi

    if [[ ${#_FOUND_CONFIGS[@]} -eq 1 ]]; then
        LINT_CONFIG_FILE="${_FOUND_CONFIGS[0]}"
        log "INFO" "Using single config: ${LINT_CONFIG_FILE}"
    else
        log "INFO" "Merging ${#_FOUND_CONFIGS[@]} config files"
        if ! _merge_configs "${_FOUND_CONFIGS[@]}"; then
            return 1
        fi
        log "INFO" "Merged config created: ${LINT_CONFIG_FILE}"
    fi

    export LINT_CONFIG_FILE
    return 0
}
