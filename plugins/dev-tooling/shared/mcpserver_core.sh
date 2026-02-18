#!/usr/bin/env bash
# MCP Server Core - JSON-RPC 2.0 Protocol Handler
# Based on Model Context Protocol specification
# Requires: bash 4+, jq

set -euo pipefail

: "${MCP_CONFIG_FILE:=config.json}"
: "${MCP_TOOLS_LIST_FILE:=tools.json}"
: "${MCP_LOG_FILE:=/dev/null}"

log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$MCP_LOG_FILE"
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
