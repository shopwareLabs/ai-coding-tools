#!/usr/bin/env bash
# run-chunkhound.sh - Config discovery wrapper for ChunkHound MCP
#
# Searches for .chunkhound.json in multiple locations (LLM tool directories)
# and passes --config if found in non-standard location.
#
# Config locations (priority order, last wins):
#   - .chunkhound.json (project root - native ChunkHound discovery)
#   - .ai/.chunkhound.json
#   - .aider/.chunkhound.json
#   - .cursor/.chunkhound.json
#   - .kite/.chunkhound.json
#   - .llm/.chunkhound.json
#   - .tabnine/.chunkhound.json
#   - .claude/.chunkhound.json (Claude Code - highest priority)
#
# Environment variable override: CHUNKHOUND_CONFIG_FILE (takes precedence)

set -euo pipefail

# Get project root (current working directory where Claude Code runs)
PROJECT_ROOT="${PWD}"

# Check for environment variable override first
if [[ -n "${CHUNKHOUND_CONFIG_FILE:-}" ]]; then
    if [[ -f "${CHUNKHOUND_CONFIG_FILE}" ]]; then
        exec chunkhound mcp --config "${CHUNKHOUND_CONFIG_FILE}" "$@"
    else
        echo "Warning: CHUNKHOUND_CONFIG_FILE set but file not found: ${CHUNKHOUND_CONFIG_FILE}" >&2
    fi
fi

# Config locations to check (last wins)
CONFIG_LOCATIONS=(
    ".chunkhound.json"
    ".ai/.chunkhound.json"
    ".aider/.chunkhound.json"
    ".cursor/.chunkhound.json"
    ".kite/.chunkhound.json"
    ".llm/.chunkhound.json"
    ".tabnine/.chunkhound.json"
    ".claude/.chunkhound.json"
)

# Find config file (last match wins)
CONFIG_FILE=""
for location in "${CONFIG_LOCATIONS[@]}"; do
    full_path="${PROJECT_ROOT}/${location}"
    if [[ -f "${full_path}" ]]; then
        CONFIG_FILE="${full_path}"
    fi
done

# Build and execute command
if [[ -n "${CONFIG_FILE}" && "${CONFIG_FILE}" != "${PROJECT_ROOT}/.chunkhound.json" ]]; then
    # Non-standard location found - pass explicit --config
    exec chunkhound mcp --config "${CONFIG_FILE}" "$@"
else
    # Project root config or no config - let ChunkHound use native discovery
    exec chunkhound mcp "$@"
fi
