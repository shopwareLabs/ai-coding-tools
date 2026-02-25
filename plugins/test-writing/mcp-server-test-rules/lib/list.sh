#!/usr/bin/env bash
# list_rules tool for test-rules MCP server
# Discovers applicable rules by metadata filters

tool_list_rules() {
    local args="$1"

    local filter_group filter_test_type filter_test_category filter_scope filter_enforce
    filter_group=$(echo "${args}" | jq -r '.group // empty')
    filter_test_type=$(echo "${args}" | jq -r '.test_type // empty')
    filter_test_category=$(echo "${args}" | jq -r '.test_category // empty')
    filter_scope=$(echo "${args}" | jq -r '.scope // empty')
    filter_enforce=$(echo "${args}" | jq -r '.enforce // empty')

    log "INFO" "list_rules: group=${filter_group:-*} type=${filter_test_type:-*} cat=${filter_test_category:-*} scope=${filter_scope:-*} enforce=${filter_enforce:-*}"

    local output=""
    local count=0
    local id

    # Header
    output="ID | Title | Enforce | Legacy"
    output="${output}"$'\n'"---|-------|---------|-------"

    for id in "${RULE_IDS[@]}"; do
        # Filter by group
        if [[ -n "${filter_group}" ]] && [[ "${RULE_GROUP[${id}]}" != "${filter_group}" ]]; then
            continue
        fi

        # Filter by test type: if filter is "integration" or "migration", exclude unit-only rules
        if [[ -n "${filter_test_type}" ]] && [[ "${filter_test_type}" != "unit" ]]; then
            if [[ "${RULE_TEST_TYPES[${id}]}" == "unit" ]]; then
                continue
            fi
        fi

        # Filter by test category
        if [[ -n "${filter_test_category}" ]]; then
            if ! _csv_contains "${RULE_TEST_CATEGORIES[${id}]}" "${filter_test_category}"; then
                continue
            fi
        fi

        # Filter by scope
        if [[ -n "${filter_scope}" ]]; then
            if ! _csv_contains "${RULE_SCOPE[${id}]}" "${filter_scope}"; then
                continue
            fi
        fi

        # Filter by enforce level
        if [[ -n "${filter_enforce}" ]] && [[ "${RULE_ENFORCE[${id}]}" != "${filter_enforce}" ]]; then
            continue
        fi

        output="${output}"$'\n'"${id} | ${RULE_TITLE[${id}]} | ${RULE_ENFORCE[${id}]} | ${RULE_LEGACY[${id}]}"
        ((count++))
    done

    echo "${output}"
    echo ""
    echo "Total: ${count} rules"
}
