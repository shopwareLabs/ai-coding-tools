#!/usr/bin/env bash
# MCP Server Core - JSON-RPC 2.0 Protocol Handler
# Based on Model Context Protocol specification
# Requires: bash 4+, jq

set -euo pipefail

: "${MCP_CONFIG_FILE:=config.json}"
: "${MCP_TOOLS_LIST_FILE:=tools.json}"
: "${MCP_LOG_FILE:=/dev/null}"
: "${MCP_EXTRA_LOG_FILE:=}"

log() {
    local level="$1"
    local message="$2"
    local line
    line="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
    echo "$line" >> "$MCP_LOG_FILE"
    [[ -n "${MCP_EXTRA_LOG_FILE}" ]] && echo "$line" >> "$MCP_EXTRA_LOG_FILE"
    return 0
}

# Configure an additional log file from user config.
# Relative paths are resolved against PROJECT_ROOT.
# If the parent directory does not exist, logs a warning and skips.
_configure_extra_log_file() {
    local raw_path="${1:-}"
    [[ -z "$raw_path" ]] && return 0

    local resolved="$raw_path"
    if [[ "$raw_path" != /* ]]; then
        resolved="${PROJECT_ROOT}/${raw_path}"
    fi

    local parent_dir
    parent_dir="$(dirname "$resolved")"
    if [[ ! -d "$parent_dir" ]]; then
        log "WARN" "log_file parent directory does not exist: ${parent_dir} — extra log file disabled"
        return 0
    fi

    MCP_EXTRA_LOG_FILE="$resolved"
    export MCP_EXTRA_LOG_FILE
    log "INFO" "Extra log file configured: ${MCP_EXTRA_LOG_FILE}"
}

read_json_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cat "$file"
    else
        log "ERROR" "File not found: $file"
        echo "{}"
    fi
}

create_response() {
    local id="$1"
    local result="$2"

    jq -n -c \
        --argjson id "$id" \
        --argjson result "$result" \
        '{"jsonrpc": "2.0", "id": $id, "result": $result}'
}

create_error_response() {
    local id="$1"
    local code="$2"
    local message="$3"

    jq -n -c \
        --argjson id "$id" \
        --argjson code "$code" \
        --arg message "$message" \
        '{"jsonrpc": "2.0", "id": $id, "error": {"code": $code, "message": $message}}'
}

handle_initialize() {
    local id="$1"
    local params="$2"

    log "INFO" "Handling initialize request"

    local config
    config=$(read_json_file "$MCP_CONFIG_FILE")

    local result
    result=$(jq -n -c \
        --argjson config "$config" \
        '{
            "protocolVersion": ($config.protocolVersion // "2024-11-05"),
            "serverInfo": ($config.serverInfo // {"name": "mcp-server", "version": "1.0.0"}),
            "capabilities": ($config.capabilities // {"tools": {}})
        }')

    create_response "$id" "$result"
}

handle_tools_list() {
    local id="$1"

    log "INFO" "Handling tools/list request"

    local tools_config
    tools_config=$(read_json_file "$MCP_TOOLS_LIST_FILE")

    local tools
    tools=$(echo "$tools_config" | jq -c '.tools // []')

    local result
    result=$(jq -n -c --argjson tools "$tools" '{"tools": $tools}')

    create_response "$id" "$result"
}

# Validate call arguments against the tool's declared inputSchema.
# Enforces `required` (every listed field must be present) and, when the schema
# sets `additionalProperties: false`, rejects any field not in `properties`.
# Tools without a schema (or with an unreadable tools list) are not validated.
# Args: $1 = tool name, $2 = arguments JSON object
# On violation: prints a human-readable message to stdout and returns 1.
validate_tool_arguments() {
    local tool_name="$1"
    local arguments="$2"

    local tools_config schema
    tools_config=$(read_json_file "$MCP_TOOLS_LIST_FILE")
    schema=$(echo "$tools_config" | jq -c --arg n "$tool_name" \
        '(.tools[]? | select(.name == $n) | .inputSchema) // empty' 2>/dev/null || true)
    [[ -z "$schema" || "$schema" == "null" ]] && return 0

    local message
    message=$(jq -n -r \
        --argjson schema "$schema" \
        --argjson args "$arguments" \
        '
        ($schema.required // [])               as $req
        | ($args | keys)                        as $present
        | (($schema.properties // {}) | keys)   as $allowed
        | [ $req[]     | . as $r | select(($present | index($r)) == null) ] as $missing
        | ( if ($schema.additionalProperties == false)
            then [ $present[] | . as $p | select(($allowed | index($p)) == null) ]
            else [] end )                        as $unknown
        | if   ($missing | length) > 0 then
            "Missing required parameter(s): " + ($missing | join(", ")) + "."
          elif ($unknown | length) > 0 then
            "Unknown parameter(s): " + ($unknown | join(", "))
            + ". Allowed parameters: " + ($allowed | join(", ")) + "."
          else "" end
        ' 2>/dev/null || true)

    if [[ -n "$message" ]]; then
        printf '%s' "$message"
        return 1
    fi
    return 0
}

handle_tools_call() {
    local id="$1"
    local params="$2"

    local tool_name
    tool_name=$(echo "$params" | jq -r '.name // ""')

    local arguments
    arguments=$(echo "$params" | jq -c '.arguments // {}')

    log "INFO" "Handling tools/call: $tool_name"

    # Prevents command injection via tool name
    if [[ ! "$tool_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        create_error_response "$id" -32602 "Invalid tool name: $tool_name"
        return
    fi

    local func_name="tool_${tool_name}"
    if ! type "$func_name" &>/dev/null; then
        create_error_response "$id" -32601 "Tool not found: $tool_name"
        return
    fi

    local validation_error
    if ! validation_error=$(validate_tool_arguments "$tool_name" "$arguments"); then
        log "ERROR" "Tool $tool_name argument validation failed: $validation_error"
        local invalid_result
        invalid_result=$(jq -n -c \
            --arg text "$validation_error" \
            '{"content": [{"type": "text", "text": $text}], "isError": true}')
        create_response "$id" "$invalid_result"
        return
    fi

    local output
    local exit_code=0
    output=$("$func_name" "$arguments" 2>&1) || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log "ERROR" "Tool $tool_name failed with exit code $exit_code"
        local error_result
        error_result=$(jq -n -c \
            --arg text "Error executing $tool_name: $output" \
            '{"content": [{"type": "text", "text": $text}], "isError": true}')
        create_response "$id" "$error_result"
        return
    fi

    local result
    result=$(jq -n -c \
        --arg text "$output" \
        '{"content": [{"type": "text", "text": $text}], "isError": false}')

    create_response "$id" "$result"
}

process_request() {
    local request="$1"

    if ! echo "$request" | jq -e '.' >/dev/null 2>&1; then
        log "ERROR" "Invalid JSON received"
        create_error_response "null" -32700 "Parse error: Invalid JSON"
        return
    fi

    local jsonrpc id method params
    jsonrpc=$(echo "$request" | jq -r '.jsonrpc // ""')
    id=$(echo "$request" | jq -c '.id // null')
    method=$(echo "$request" | jq -r '.method // ""')
    params=$(echo "$request" | jq -c '.params // {}')

    if [[ "$jsonrpc" != "2.0" ]]; then
        log "ERROR" "Invalid JSON-RPC version: $jsonrpc"
        create_error_response "$id" -32600 "Invalid Request: jsonrpc must be 2.0"
        return
    fi

    # JSON-RPC notifications have no id and require no response
    if [[ "$id" == "null" ]]; then
        log "INFO" "Received notification: $method"
        return
    fi

    case "$method" in
        "initialize")
            handle_initialize "$id" "$params"
            ;;
        "tools/list")
            handle_tools_list "$id"
            ;;
        "tools/call")
            handle_tools_call "$id" "$params"
            ;;
        "notifications/initialized")
            log "INFO" "Client initialized"
            ;;
        "ping")
            create_response "$id" '{}'
            ;;
        *)
            log "ERROR" "Unknown method: $method"
            create_error_response "$id" -32601 "Method not found: $method"
            ;;
    esac
}

run_mcp_server() {
    log "INFO" "MCP Server starting..."

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue

        log "INFO" "Received: ${line:0:100}..."

        local response
        response=$(process_request "$line")

        if [[ -n "$response" ]]; then
            log "RESPONSE" "${response:0:100}..."
            echo "$response"
        fi
    done

    log "INFO" "MCP Server shutting down"
}
