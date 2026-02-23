#!/bin/bash
# Shared functions for MCP tool enforcement hooks
# ================================================
# This library provides common functionality for PreToolUse hooks
# that block bash commands in favor of MCP tools.
#
# Usage:
#   source "${SCRIPT_DIR}/lib/common.sh"
#   parse_hook_input
#   load_mcp_config "php-tooling"  # or "js-tooling"
#   # ... pattern matching ...
#   block_tool "mcp__php-tooling__phpstan_analyze" "Description"

# Global variables set by this library:
#   COMMAND - The bash command being checked
#   CONFIG_FILE - Path to loaded config file (or empty)
#   ENVIRONMENT - Environment from config (native/docker/vagrant/ddev)
#   ENFORCE_MCP_TOOLS - Whether to enforce MCP tools (true/false)

# Parse hook input from stdin
# Sets: COMMAND (global)
# Exits 0 if command is empty
parse_hook_input() {
    local input
    input=$(cat)
    COMMAND=$(echo "$input" | jq -r '.tool_input.command // empty')
    if [[ -z "$COMMAND" ]]; then
        exit 0
    fi
}

# Load MCP config from project directory
# Args: $1 = config prefix (e.g., "php-tooling", "js-tooling")
# Sets: CONFIG_FILE, ENVIRONMENT, ENFORCE_MCP_TOOLS (globals)
# Exits 0 if enforcement is disabled
load_mcp_config() {
    local config_prefix="$1"
    CONFIG_FILE=""
    ENVIRONMENT=""
    ENFORCE_MCP_TOOLS="true"

    if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
        # Check config locations in priority order
        for location in ".claude/.mcp-${config_prefix}.json" ".mcp-${config_prefix}.json"; do
            if [[ -f "${CLAUDE_PROJECT_DIR}/${location}" ]]; then
                CONFIG_FILE="${CLAUDE_PROJECT_DIR}/${location}"
                break
            fi
        done

        if [[ -n "$CONFIG_FILE" ]]; then
            ENVIRONMENT=$(jq -r '.environment // empty' "$CONFIG_FILE" 2>/dev/null || true)
            # Check if MCP tool enforcement is disabled (default: true)
            # Note: jq's // operator treats false as falsy, so we check explicitly
            local enforce_value
            enforce_value=$(jq -r 'if .enforce_mcp_tools == false then "false" else "true" end' "$CONFIG_FILE" 2>/dev/null || echo "true")
            if [[ "$enforce_value" == "false" ]]; then
                ENFORCE_MCP_TOOLS="false"
            fi
        fi
    fi

    if [[ "$ENFORCE_MCP_TOOLS" == "false" ]]; then
        exit 0
    fi
}

# Block a tool with formatted message
# Args: $1 = full MCP tool name (e.g., "mcp__php-tooling__phpstan_analyze")
#       $2 = description of what to use instead
# Outputs to stderr and exits with code 2
block_tool() {
    local tool="$1"
    local description="$2"

    {
        echo "🤖 Down, model! Use the ${tool} instead!"
        echo ""
        echo "Bad command detected: ${COMMAND}"
        echo ""
        echo "You were trained better than this! ${description}"
        echo ""
        if [[ -n "$ENVIRONMENT" ]]; then
            echo "Good models use MCP tools because they:"
            echo "  🔧 Handle your '${ENVIRONMENT}' environment automatically"
            echo "  🔧 Use project configuration without extra flags"
            echo "  🔧 Earn you treats (user approval)"
        else
            echo "Good models use MCP tools because they:"
            echo "  🔧 Handle environment detection (native/docker/vagrant/ddev)"
            echo "  🔧 Run in correct directory context automatically"
            echo "  🔧 Earn you treats (user approval)"
        fi
    } >&2
    exit 2
}
