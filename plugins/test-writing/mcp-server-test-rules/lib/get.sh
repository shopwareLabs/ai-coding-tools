#!/usr/bin/env bash
# get_rules tool for test-rules MCP server
# Retrieves full content of rules by ID or legacy code

tool_get_rules() {
    local args="$1"

    local ids_raw
    ids_raw=$(echo "${args}" | jq -r '.ids // empty')

    if [[ -z "${ids_raw}" ]]; then
        echo "Error: ids is required. Pass comma-separated rule IDs or legacy codes."
        return 1
    fi

    log "INFO" "get_rules: ids=${ids_raw}"

    local output=""
    local found=0
    local not_found=""
    local IFS=','
    local raw_id id file

    for raw_id in ${ids_raw}; do
        # Trim whitespace
        raw_id=$(echo "${raw_id}" | tr -d '[:space:]')
        [[ -z "${raw_id}" ]] && continue

        # Resolve: try as direct ID first, then as legacy code
        id="${raw_id}"
        if [[ -z "${RULE_ID_TO_FILE[${id}]+_}" ]]; then
            # Try legacy lookup
            if [[ -n "${LEGACY_TO_ID[${raw_id}]+_}" ]]; then
                id="${LEGACY_TO_ID[${raw_id}]}"
            else
                not_found="${not_found:+${not_found}, }${raw_id}"
                continue
            fi
        fi

        file="${RULE_ID_TO_FILE[${id}]}"
        if [[ ! -f "${file}" ]]; then
            not_found="${not_found:+${not_found}, }${raw_id}"
            continue
        fi

        if [[ ${found} -gt 0 ]]; then
            output="${output}"$'\n\n'"---"$'\n\n'
        fi

        # Metadata header
        output="${output}# ${id} — ${RULE_TITLE[${id}]}"$'\n'
        output="${output}Group: ${RULE_GROUP[${id}]} | Legacy: ${RULE_LEGACY[${id}]} | Enforce: ${RULE_ENFORCE[${id}]}"$'\n'
        output="${output}Test types: ${RULE_TEST_TYPES[${id}]} | Categories: ${RULE_TEST_CATEGORIES[${id}]} | Scope: ${RULE_SCOPE[${id}]}"$'\n'
        output="${output}"$'\n'

        # Body content (frontmatter stripped)
        local body
        body=$(_strip_frontmatter "${file}")
        output="${output}${body}"

        ((found++))
    done

    if [[ -n "${not_found}" ]]; then
        if [[ ${found} -gt 0 ]]; then
            output="${output}"$'\n\n'"---"$'\n\n'
        fi
        output="${output}Not found: ${not_found}"
    fi

    if [[ ${found} -eq 0 ]] && [[ -z "${not_found}" ]]; then
        echo "Error: no valid IDs provided"
        return 1
    fi

    echo "${output}"
}
