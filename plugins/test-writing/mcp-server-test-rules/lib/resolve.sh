#!/usr/bin/env bash
# resolve_legacy tool for test-rules MCP server
# Maps legacy E/W/I codes to current rule IDs

tool_resolve_legacy() {
    local args="$1"

    local codes_raw
    codes_raw=$(echo "${args}" | jq -r '.codes // empty')

    if [[ -z "${codes_raw}" ]]; then
        echo "Error: codes is required. Pass comma-separated legacy codes (e.g. 'E001,W004,I007')."
        return 1
    fi

    log "INFO" "resolve_legacy: codes=${codes_raw}"

    local output=""
    local IFS=','
    local code id

    output="Legacy | Current ID | Title | Group"
    output="${output}"$'\n'"-------|------------|-------|------"

    for code in ${codes_raw}; do
        # Trim whitespace
        code=$(echo "${code}" | tr -d '[:space:]')
        [[ -z "${code}" ]] && continue

        if [[ -n "${LEGACY_TO_ID[${code}]+_}" ]]; then
            id="${LEGACY_TO_ID[${code}]}"
            output="${output}"$'\n'"${code} | ${id} | ${RULE_TITLE[${id}]} | ${RULE_GROUP[${id}]}"
        else
            output="${output}"$'\n'"${code} | NOT FOUND | - | -"
        fi
    done

    echo "${output}"
}
