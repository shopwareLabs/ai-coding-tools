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

    local filter_scoped_review
    filter_scoped_review=$(echo "${args}" | jq -r '.scoped_review // empty')

    local filter_review_unit
    filter_review_unit=$(echo "${args}" | jq -r '.review_unit // empty')

    local has_filters=false
    [[ -n "${filter_group}" || -n "${filter_test_type}" || -n "${filter_test_category}" || -n "${filter_scope}" || -n "${filter_enforce}" || -n "${filter_scoped_review}" || -n "${filter_review_unit}" ]] && has_filters=true

    if [[ -z "${ids_raw}" ]] && [[ "${has_filters}" == false ]]; then
        echo "Error: provide either ids (comma-separated rule IDs) or filter parameters (group, test_type, test_category, scope, enforce, scoped_review, review_unit)."
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
        log "INFO" "get_rules: filter mode group=${filter_group:-*} type=${filter_test_type:-*} cat=${filter_test_category:-*} scope=${filter_scope:-*} enforce=${filter_enforce:-*} review_unit=${filter_review_unit:-*}"
        local filtered_id
        while IFS= read -r filtered_id; do
            [[ -n "${filtered_id}" ]] && target_ids+=("${filtered_id}")
        done < <(_filter_rules "${filter_group}" "${filter_test_type}" "${filter_test_category}" "${filter_scope}" "${filter_enforce}" "${filter_scoped_review}" "${filter_review_unit}")

        if [[ ${#target_ids[@]} -eq 0 ]]; then
            echo "No rules match the specified filters."
            return 0
        fi
    fi

    # Render full content for each ID via the shared renderer (also used by
    # tool_build_rule_package, so both emit byte-identical output).
    local output
    if ! output=$(_render_rules "${target_ids[@]}"); then
        echo "Error: no valid IDs provided"
        return 1
    fi

    echo "${output}"
}
