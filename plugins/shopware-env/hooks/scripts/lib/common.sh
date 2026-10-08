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
#   block_tool "php-tooling" "Description" "phpstan_analyze"

# Global variables set by this library:
#   HOOK_INPUT - The hook-event JSON read from stdin
#   COMMAND - The bash command being checked
#   CONFIG_FILE - Path to loaded config file (or empty)
#   ENVIRONMENT - Environment from config (native/docker/docker-compose/vagrant/ddev)
#   ENFORCE_MCP_TOOLS - Whether to enforce MCP tools (true/false)

# Resolve the session's project directory: CLAUDE_PROJECT_DIR when set and
# non-empty, else the hook input's .cwd (Codex sets no CLAUDE_PROJECT_DIR; both
# name the session directory). Stdin is read once by the caller and passed in.
# Args: $1 = hook-event JSON
# Stdout: the directory, or nothing when neither source names one
resolve_project_dir() {
    if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
        printf '%s\n' "$CLAUDE_PROJECT_DIR"
        return 0
    fi
    printf '%s' "$1" | jq -r 'if (.cwd | type) == "string" then .cwd else empty end'
}

# Parse hook input from stdin
# Sets: HOOK_INPUT, COMMAND (globals)
# Exits 0 if command is empty
parse_hook_input() {
    HOOK_INPUT=$(cat)
    COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty')
    if [[ -z "$COMMAND" ]]; then
        exit 0
    fi
}

# Load MCP config from project directory (resolve_project_dir on HOOK_INPUT)
# Args: $1 = config prefix (e.g., "php-tooling", "js-tooling")
# Sets: CONFIG_FILE, ENVIRONMENT, ENFORCE_MCP_TOOLS (globals)
# Exits 0 if enforcement is disabled
load_mcp_config() {
    local config_prefix="$1"
    CONFIG_FILE=""
    ENVIRONMENT=""
    ENFORCE_MCP_TOOLS="true"

    local project_dir
    project_dir=$(resolve_project_dir "$HOOK_INPUT")

    if [[ -n "$project_dir" ]]; then
        # Check config locations in priority order
        for location in ".claude/.mcp-${config_prefix}.json" ".mcp-${config_prefix}.json"; do
            if [[ -f "${project_dir}/${location}" ]]; then
                CONFIG_FILE="${project_dir}/${location}"
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

    # Early exit if enforcement is disabled
    if [[ "$ENFORCE_MCP_TOOLS" == "false" ]]; then
        exit 0
    fi
}

# Block a tool with formatted message
# Tool names carry no host prefix: Claude Code and Codex each build their own
# mcp__ form, so the message names the tool and its server instead.
# Args: $1 = MCP server name (e.g., "php-tooling")
#       $2 = description of what to use instead
#       $3... = tool names, one or more (e.g., "ecs_check" "ecs_fix")
# Outputs to stderr and exits with code 2
block_tool() {
    local server="$1"
    local description="$2"
    shift 2

    local tools="" name
    for name in "$@"; do
        tools+="${tools:+ or }\`${name}\`"
    done

    {
        echo "🤖 Down, model! Use ${tools} on the \`${server}\` MCP server instead!"
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
            echo "  🔧 Handle environment detection (native/docker/docker-compose/vagrant/ddev)"
            echo "  🔧 Run in correct directory context automatically"
            echo "  🔧 Earn you treats (user approval)"
        fi
    } >&2
    exit 2
}
