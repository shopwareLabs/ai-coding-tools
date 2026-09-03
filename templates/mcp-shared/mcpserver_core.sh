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
# Rejects arguments that are not a JSON object, enforces `required` (every
# listed field must be present), when the schema sets
# `additionalProperties: false` rejects any field not in `properties`,
# enforces a declared scalar `type` (string, integer, number, boolean, array,
# object) on any present field, enforces a declared `pattern` against any
# present string-valued field, enforces a declared array `items.type` and
# `items.enum` against every element of a present array-valued field, and
# rejects any present field whose schema declares an `enum` when the supplied
# value is not one of the declared values. Diagnostics take precedence in
# that order — missing, unknown, type, pattern, items, enum — so a value that
# fails more than one constraint is reported with the most fundamental defect
# first (a type mismatch is reported before an unrelated enum mismatch).
# A tool with no entry in the tools list, or whose entry declares no
# inputSchema, is not validated. A jq failure is a rejection and never a skip:
# a validator that could not evaluate its input has not validated it, and
# reporting success there would wave every constraint through. That branch is
# defense-in-depth for a direct call rather than a live remote-input guard —
# process_request gates the whole request through `jq -e '.'`, so arguments
# arriving over the protocol are always parseable JSON. The non-object branch
# is NOT in that category: `null`, `false` and every other JSON scalar are
# parseable, so a client can send them and they reach this validator.
# Args: $1 = tool name, $2 = arguments JSON
# On violation: prints a human-readable message to stdout and returns 1.
validate_tool_arguments() {
    local tool_name="$1"
    local arguments="$2"

    local tools_config schema rc
    # errexit is off inside this function — handle_tools_call tests it in a
    # conditional — so the unreadable-tools-list fallback must be explicit
    # rather than left to the call site's shape.
    tools_config=$(read_json_file "$MCP_TOOLS_LIST_FILE" 2>/dev/null) || tools_config='{}'
    rc=0
    schema=$(echo "$tools_config" | jq -c --arg n "$tool_name" \
        '(.tools[]? | select(.name == $n) | .inputSchema) // empty' 2>/dev/null) || rc=$?
    if [[ $rc -ne 0 ]]; then
        printf '%s' "Cannot validate arguments for ${tool_name}: the tool list at ${MCP_TOOLS_LIST_FILE} is not parseable JSON."
        return 1
    fi
    [[ -z "$schema" || "$schema" == "null" ]] && return 0

    # A non-object `arguments` is rejected in the first branch because every
    # constraint below reads `$args | keys`, which errors on any other type and
    # would take the whole schema down with it.
    local message
    rc=0
    message=$(jq -n -r \
        --argjson schema "$schema" \
        --argjson args "$arguments" \
        '
        # `want == "integer"` treats a whole-valued JSON number as satisfying
        # it (JSON has no distinct integer type); every other `want` is a
        # plain jq `type` comparison.
        def type_ok(want; val):
            if want == "integer" then
                (val | type) == "number" and (val == (val | floor))
            else
                (val | type) == want
            end;
        def type_label(want; val):
            if want == "integer" and (val | type) == "number" then
                "number (non-integer)"
            else
                (val | type)
            end;
        if ($args | type) != "object" then
            "Invalid arguments: expected a JSON object, got "
            + ($args | type) + "."
        else
          ($schema.required // [])               as $req
        | ($args | keys)                        as $present
        | (($schema.properties // {}) | keys)   as $allowed
        | (($schema.properties // {}))          as $props
        | [ $req[]     | . as $r | select(($present | index($r)) == null) ] as $missing
        | ( if ($schema.additionalProperties == false)
            then [ $present[] | . as $p | select(($allowed | index($p)) == null) ]
            else [] end )                        as $unknown
        | [ $present[] | . as $p
            | ($props[$p].type // empty)          as $t
            | select($t != null and ($t | type) == "string")
            | ($args[$p])                          as $v
            | select((type_ok($t; $v)) | not)
            | {p: $p, expected: $t, actual: type_label($t; $v), v: $v}
          ]                                      as $invalid_type
        | [ $present[] | . as $p
            | ($props[$p].pattern // empty)       as $pat
            | select($pat != null)
            | ($args[$p])                          as $v
            | select(($v | type) == "string")
            | select(($v | test($pat)) | not)
            | {p: $p, pattern: $pat, v: $v}
          ]                                      as $invalid_pattern
        | [ $present[] | . as $p
            | ($props[$p].items // empty)         as $items
            | select($items != null)
            | ($args[$p])                          as $v
            | select(($v | type) == "array")
            # Plain field access, not `// empty`: `.items` may declare only
            # one of `type`/`enum`. A missing key yields `null` here (one
            # output), so the other, present constraint still reaches the
            # comprehension below. `// empty` on either would yield zero
            # outputs when that key is absent, and an `as` binding with zero
            # outputs runs its body zero times — silently discarding every
            # element of this property, including violations of the
            # constraint that *was* declared.
            | ($items.type)                        as $it
            | ($items.enum)                        as $ie
            | ( $v | to_entries[]
                | . as $entry
                | ($entry.value)                    as $ev
                | ($entry.key)                       as $idx
                | if ($it != null and ($it | type) == "string" and (type_ok($it; $ev) | not)) then
                    {p: $p, index: $idx, issue: "type", expected: $it, actual: type_label($it; $ev), v: $ev}
                  elif ($ie != null and ($ie | index($ev)) == null) then
                    {p: $p, index: $idx, issue: "enum", enum: $ie, v: $ev}
                  else empty end
              )
          ]                                      as $invalid_items
        | [ $present[] | . as $p
            | ($props[$p].enum // empty) as $enum
            | ($args[$p])                            as $v
            | select(($enum | index($v)) == null)
            | {p: $p, v: $v, enum: $enum}
          ]                                      as $invalid_enum
        | if   ($missing | length) > 0 then
            "Missing required parameter(s): " + ($missing | join(", ")) + "."
          elif ($unknown | length) > 0 then
            "Unknown parameter(s): " + ($unknown | join(", "))
            + ". Allowed parameters: " + ($allowed | join(", ")) + "."
          elif ($invalid_type | length) > 0 then
            "Invalid type(s): " + ($invalid_type | map(
                .p + " expected " + .expected + ", got " + .actual
                + " (" + (.v | tojson) + ")"
              ) | join("; ")) + "."
          elif ($invalid_pattern | length) > 0 then
            "Invalid value(s): " + ($invalid_pattern | map(
                .p + "=" + (.v | tojson) + " does not match pattern " + .pattern
              ) | join("; ")) + "."
          elif ($invalid_items | length) > 0 then
            "Invalid array item(s): " + ($invalid_items | map(
                if .issue == "type" then
                  .p + "[" + (.index | tostring) + "] expected " + .expected
                  + ", got " + .actual + " (" + (.v | tojson) + ")"
                else
                  .p + "[" + (.index | tostring) + "]=" + (.v | tojson)
                  + " (allowed: " + (.enum | join(", ")) + ")"
                end
              ) | join("; ")) + "."
          elif ($invalid_enum | length) > 0 then
            "Invalid value(s): " + ($invalid_enum | map(
                .p + "=\"" + (.v | tostring) + "\" (allowed: " + (.enum | join(", ")) + ")"
              ) | join("; ")) + "."
          else "" end
        end
        ' 2>/dev/null) || rc=$?
    if [[ $rc -ne 0 ]]; then
        printf '%s' "Cannot validate arguments for ${tool_name}: they could not be evaluated against its schema."
        return 1
    fi

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

    # `.arguments // {}` would substitute {} for a present `null` or `false`,
    # because jq's `//` treats both as absent — the validator's non-object
    # branch would then never see either. Only a genuinely absent key defaults.
    local arguments
    arguments=$(echo "$params" | jq -c 'if has("arguments") then .arguments else {} end')

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
