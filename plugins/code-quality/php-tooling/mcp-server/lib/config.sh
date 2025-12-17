#!/usr/bin/env bash
# Configuration discovery and merging for PHP Tooling MCP Server
# Supports environment variable override and multiple config file locations
# with deep merging (later files override earlier ones)
#
# Environment variable: MCP_PHP_TOOLING_CONFIG (absolute path to config file)
# Default locations (in merge order, later wins):
#   - .mcp-php-tooling.json (project root)
#   - .claude/.mcp-php-tooling.json (higher priority)
#
# Usage: source this file after mcpserver_core.sh (needs log function)
#        then call: load_config "$PROJECT_ROOT"
#        Result: LINT_CONFIG_FILE is set and exported

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

# Configuration locations relative to PROJECT_ROOT
# Order: base -> override (later entries have higher priority)
# To add new location: insert into array at appropriate position
CONFIG_LOCATIONS=(
    ".mcp-php-tooling.json"
    ".claude/.mcp-php-tooling.json"
)

# Temporary file for merged config (cleaned up on exit)
_CONFIG_TEMP_FILE=""

# Cleanup merged config temp file on exit
_config_cleanup() {
    if [[ -n "${_CONFIG_TEMP_FILE}" && -f "${_CONFIG_TEMP_FILE}" ]]; then
        rm -f "${_CONFIG_TEMP_FILE}"
    fi
}
trap _config_cleanup EXIT

# Deep merge multiple JSON files using jq
# Args: $1, $2, ... = config file paths (in merge order, later wins)
# Returns: path to temp file containing merged JSON
# Note: Uses jq's recursive merge operator (*)
_merge_configs() {
    local temp_file
    temp_file=$(mktemp)
    _CONFIG_TEMP_FILE="${temp_file}"

    # Start with first file
    local merged
    merged=$(cat "$1")
    shift

    # Deep merge remaining files (jq -s '.[0] * .[1]' merges recursively)
    for config_file in "$@"; do
        merged=$(echo "${merged}" | jq -s '.[0] * .[1]' - "${config_file}")
    done

    echo "${merged}" > "${temp_file}"
    echo "${temp_file}"
}

# Discover existing config files from CONFIG_LOCATIONS
# Args: $1 = project root
# Sets: _FOUND_CONFIGS array with absolute paths to existing config files
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
# Sets: LINT_CONFIG_FILE (path to config file, possibly merged temp file)
# Args: $1 = project root directory
# Returns: 0 on success, 1 on error (logs error message)
#
# Priority:
#   1. MCP_PHP_TOOLING_CONFIG environment variable (absolute path)
#   2. Config files from CONFIG_LOCATIONS (merged if multiple exist)
#
# Error conditions:
#   - Environment variable set but file doesn't exist
#   - No config files found at any location
load_config() {
    local project_root="$1"

    # Priority 1: Environment variable override
    if [[ -n "${MCP_PHP_TOOLING_CONFIG:-}" ]]; then
        log "INFO" "Using config from environment variable: ${MCP_PHP_TOOLING_CONFIG}"

        if [[ ! -f "${MCP_PHP_TOOLING_CONFIG}" ]]; then
            log "ERROR" "Config file from MCP_PHP_TOOLING_CONFIG not found: ${MCP_PHP_TOOLING_CONFIG}"
            return 1
        fi

        LINT_CONFIG_FILE="${MCP_PHP_TOOLING_CONFIG}"
        export LINT_CONFIG_FILE
        return 0
    fi

    # Priority 2: Discover and merge config files from locations
    _discover_configs "${project_root}"

    if [[ ${#_FOUND_CONFIGS[@]} -eq 0 ]]; then
        log "ERROR" "No config file found"
        log "ERROR" "Create .mcp-php-tooling.json or .claude/.mcp-php-tooling.json"
        log "ERROR" "Or set MCP_PHP_TOOLING_CONFIG environment variable"
        return 1
    fi

    if [[ ${#_FOUND_CONFIGS[@]} -eq 1 ]]; then
        # Single config - use directly
        LINT_CONFIG_FILE="${_FOUND_CONFIGS[0]}"
        log "INFO" "Using single config: ${LINT_CONFIG_FILE}"
    else
        # Multiple configs - merge them
        log "INFO" "Merging ${#_FOUND_CONFIGS[@]} config files"
        LINT_CONFIG_FILE=$(_merge_configs "${_FOUND_CONFIGS[@]}")
        log "INFO" "Merged config created: ${LINT_CONFIG_FILE}"
    fi

    export LINT_CONFIG_FILE
    return 0
}
