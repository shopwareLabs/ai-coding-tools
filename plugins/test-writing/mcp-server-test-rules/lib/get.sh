#!/usr/bin/env bash
# get_rules tool for test-rules MCP server
# Retrieves full content of rules by ID or by metadata filters

tool_get_rules() {
    local args="$1"

    local ids_raw
    ids_raw=$(echo "${args}" | jq -r '.ids // empty')

    # Detect filter parameters
    local filter_group filter_test_type filter_test_category filter_scope filter_enforce
    filter_group=$(echo "${args}" | jq -r '.group // empty')
    filter_test_type=$(echo "${args}" | jq -r '.test_type // empty')
    filter_test_category=$(echo "${args}" | jq -r '.test_category // empty')
    filter_scope=$(echo "${args}" | jq -r '.scope // empty')
    filter_enforce=$(echo "${args}" | jq -r '.enforce // empty')

    local has_filters=false
    [[ -n "${filter_group}" || -n "${filter_test_type}" || -n "${filter_test_category}" || -n "${filter_scope}" || -n "${filter_enforce}" ]] && has_filters=true

    if [[ -z "${ids_raw}" ]] && [[ "${has_filters}" == false ]]; then
        echo "Error: provide either ids (comma-separated rule IDs) or filter parameters (group, test_type, test_category, scope, enforce)."
        return 1
    fi

    # Build list of IDs to retrieve
    local -a target_ids=()

    if [[ -n "${ids_raw}" ]]; then
        # ID mode: split comma-separated IDs
        log "INFO" "get_rules: ids=${ids_raw}"
        local IFS=','
        local raw_id
        for raw_id in ${ids_raw}; do
            raw_id=$(echo "${raw_id}" | tr -d '[:space:]')
            [[ -n "${raw_id}" ]] && target_ids+=("${raw_id}")
        done
    else
        # Filter mode: use _filter_rules
        log "INFO" "get_rules: filter mode group=${filter_group:-*} type=${filter_test_type:-*} cat=${filter_test_category:-*} scope=${filter_scope:-*} enforce=${filter_enforce:-*}"
        local filtered_id
        while IFS= read -r filtered_id; do
            [[ -n "${filtered_id}" ]] && target_ids+=("${filtered_id}")
        done < <(_filter_rules "${filter_group}" "${filter_test_type}" "${filter_test_category}" "${filter_scope}" "${filter_enforce}")

        if [[ ${#target_ids[@]} -eq 0 ]]; then
            echo "No rules match the specified filters."
            return 0
        fi
    fi

    # Render full content for each ID
    local output=""
    local found=0
    local not_found=""
    local raw_id id file

    for raw_id in "${target_ids[@]}"; do
        id="${raw_id}"
        if [[ -z "${RULE_ID_TO_FILE[${id}]+_}" ]]; then
            not_found="${not_found:+${not_found}, }${raw_id}"
            continue
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
        output="${output}Group: ${RULE_GROUP[${id}]} | Enforce: ${RULE_ENFORCE[${id}]}"$'\n'
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
