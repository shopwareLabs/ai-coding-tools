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

    local filter_scoped_review
    filter_scoped_review=$(echo "${args}" | jq -r '.scoped_review // empty')

    log "INFO" "list_rules: group=${filter_group:-*} type=${filter_test_type:-*} cat=${filter_test_category:-*} scope=${filter_scope:-*} enforce=${filter_enforce:-*} scoped_review=${filter_scoped_review:-*}"

    local output=""
    local count=0

    # Header
    output="ID | Title | Enforce"
    output="${output}"$'\n'"---|-------|--------"

    local id
    while IFS= read -r id; do
        [[ -z "${id}" ]] && continue
        output="${output}"$'\n'"${id} | ${RULE_TITLE[${id}]} | ${RULE_ENFORCE[${id}]}"
        ((count++))
    done < <(_filter_rules "${filter_group}" "${filter_test_type}" "${filter_test_category}" "${filter_scope}" "${filter_enforce}" "${filter_scoped_review}")

    echo "${output}"
    echo ""
    echo "Total: ${count} rules"
}
