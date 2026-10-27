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
#   COMMAND - The bash command being checked, heredoc bodies removed
#   MCP_CONFIG_JSON - The config read by read_mcp_config (or empty)
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
    if [[ "$COMMAND" == *'<<'* && "$COMMAND" == *$'\n'* ]]; then
        strip_heredoc_bodies
    fi
}

# Removes every heredoc body from COMMAND, from the line after the one that
# opens it through its terminator line, because the block patterns anchor at
# each line start and a body line such as a script's `vendor/bin/phpunit` would
# read as a command. A `<<-` terminator may be indented with tabs. A heredoc
# whose terminator never comes removes the rest of the command.
# Globals: reads and rewrites COMMAND
strip_heredoc_bodies() {
    local opener='(^|[^<])<<(-?)[[:space:]]*["'\'']?([A-Za-z_][A-Za-z0-9_]*)'
    local line kept="" delimiter="" tab_indented=""
    while IFS= read -r line; do
        if [[ -n "$delimiter" ]]; then
            if [[ -n "$tab_indented" ]]; then
                while [[ "$line" == $'\t'* ]]; do
                    line="${line#$'\t'}"
                done
            fi
            if [[ "$line" == "$delimiter" ]]; then
                delimiter=""
            fi
            continue
        fi
        kept+="${line}"$'\n'
        if [[ "$line" =~ $opener ]]; then
            tab_indented="${BASH_REMATCH[2]}"
            delimiter="${BASH_REMATCH[3]}"
        fi
    done <<< "$COMMAND"
    COMMAND="${kept%$'\n'}"
}

# Read the MCP config the way the MCP servers find theirs: the file named by
# MCP_PHP_TOOLING_CONFIG or MCP_JS_TOOLING_CONFIG when that variable is set,
# else every file found at the servers' locations, deep-merged with later
# locations winning. A missing override file, or a file that does not hold a
# JSON object, reads as no config, so the defaults apply.
# Args: $1 = config prefix ("php-tooling" or "js-tooling")
#       $2 = project directory, may be empty
# Sets: MCP_CONFIG_JSON - the merged config object, or empty when none is read
read_mcp_config() {
    local config_prefix="$1" project_dir="$2"
    local override="" location
    local -a files=()
    MCP_CONFIG_JSON=""

    case "$config_prefix" in
        php-tooling) override="${MCP_PHP_TOOLING_CONFIG:-}" ;;
        js-tooling) override="${MCP_JS_TOOLING_CONFIG:-}" ;;
    esac

    if [[ -n "$override" ]]; then
        if [[ -f "$override" ]]; then
            files=("$override")
        fi
    elif [[ -n "$project_dir" ]]; then
        # Merge order of CONFIG_LOCATIONS in templates/mcp-shared/config.sh.
        for location in "" .aiassistant/ .amazonq/ .cline/ .cursor/ .kiro/ .windsurf/ .zed/ .claude/; do
            if [[ -f "${project_dir}/${location}.mcp-${config_prefix}.json" ]]; then
                files+=("${project_dir}/${location}.mcp-${config_prefix}.json")
            fi
        done
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        return 0
    fi
    MCP_CONFIG_JSON=$(jq -s 'reduce .[] as $config ({}; . * $config)' "${files[@]}" 2>/dev/null) || MCP_CONFIG_JSON=""
}

# Load MCP config for the project directory (resolve_project_dir on HOOK_INPUT)
# Args: $1 = config prefix (e.g., "php-tooling", "js-tooling")
# Sets: MCP_CONFIG_JSON, ENVIRONMENT, ENFORCE_MCP_TOOLS (globals)
# Exits 0 if enforcement is disabled
load_mcp_config() {
    local config_prefix="$1"
    ENVIRONMENT=""
    ENFORCE_MCP_TOOLS="true"

    read_mcp_config "$config_prefix" "$(resolve_project_dir "$HOOK_INPUT")"

    if [[ -n "$MCP_CONFIG_JSON" ]]; then
        # jq's // treats false as absent, so the opt-out is compared explicitly.
        local settings
        settings=$(jq -r '"\(.enforce_mcp_tools != false)\t\(.environment // "")"' <<< "$MCP_CONFIG_JSON")
        ENFORCE_MCP_TOOLS="${settings%%$'\t'*}"
        ENVIRONMENT="${settings#*$'\t'}"
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
