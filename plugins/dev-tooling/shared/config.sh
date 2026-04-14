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
# Default locations (in merge order, later wins):
#   - .mcp-<prefix>.json (project root)
#   - .claude/.mcp-<prefix>.json (higher priority)
#
# Usage: export CONFIG_PREFIX="php-tooling"
#        source this file after mcpserver_core.sh (needs log function)
#        then call: load_config "$PROJECT_ROOT"
#        Result: LINT_CONFIG_FILE is set and exported

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

if [[ -z "${CONFIG_PREFIX:-}" ]]; then
    echo "ERROR: CONFIG_PREFIX must be set before sourcing config.sh" >&2
    exit 1
fi

# Generate config file name and environment variable from prefix.
#
# MCP path (default, CONFIG_FILE_PREFIX unset):
#   php-tooling -> .mcp-php-tooling.json, MCP_PHP_TOOLING_CONFIG
#
# LSP path (caller sets CONFIG_FILE_PREFIX=".lsp-", CONFIG_ENV_VAR_PREFIX="LSP"):
#   php-tooling -> .lsp-php-tooling.json, LSP_PHP_TOOLING_CONFIG
#
# The LSP path is explicit by design — we don't default CONFIG_FILE_PREFIX to ".mcp-"
# because a silent fallback would mask caller bugs. MCP's .mcp- literal stays hardcoded
# in the else branch below.
if [[ -n "${CONFIG_FILE_PREFIX:-}" ]]; then
    if [[ -z "${CONFIG_ENV_VAR_PREFIX:-}" ]]; then
        echo "ERROR: CONFIG_ENV_VAR_PREFIX required when CONFIG_FILE_PREFIX is set" >&2
        exit 1
    fi
    CONFIG_FILE_NAME="${CONFIG_FILE_PREFIX}${CONFIG_PREFIX}.json"
    CONFIG_ENV_VAR="${CONFIG_ENV_VAR_PREFIX}_${CONFIG_PREFIX^^}_CONFIG"
else
    CONFIG_FILE_NAME=".mcp-${CONFIG_PREFIX}.json"
    CONFIG_ENV_VAR="MCP_${CONFIG_PREFIX^^}_CONFIG"
fi
CONFIG_ENV_VAR="${CONFIG_ENV_VAR//-/_}"  # Replace hyphens with underscores

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

_config_cleanup() {
    if [[ -n "${_CONFIG_TEMP_FILE}" && -f "${_CONFIG_TEMP_FILE}" ]]; then
        rm -f "${_CONFIG_TEMP_FILE}"
    fi
}
trap _config_cleanup EXIT

# Args: config file paths (merge order, later wins)
# Returns: path to temp file with merged JSON
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
# Sets: LINT_CONFIG_FILE (path to config file, possibly merged temp file)
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
load_config() {
    local project_root="$1"

    local env_value="${!CONFIG_ENV_VAR:-}"
    if [[ -n "${env_value}" ]]; then
        log "INFO" "Using config from environment variable ${CONFIG_ENV_VAR}: ${env_value}"

        if [[ ! -f "${env_value}" ]]; then
            log "ERROR" "Config file from ${CONFIG_ENV_VAR} not found: ${env_value}"
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
        LINT_CONFIG_FILE=$(_merge_configs "${_FOUND_CONFIGS[@]}")
        log "INFO" "Merged config created: ${LINT_CONFIG_FILE}"
    fi

    export LINT_CONFIG_FILE
    return 0
}
