#!/usr/bin/env bash
# get_rules tool for test-rules MCP server
# Retrieves full content of rules by ID or by metadata filters

# Retrieve full content for a set of rules, either by explicit IDs or by
# metadata filters, rendered through the shared _render_rules renderer.
# Arguments:
#   JSON arguments object with either `ids` (comma-separated rule IDs) or one
#   or more filter fields: group, test_type, test_category, scope, enforce,
#   scoped_review, review_unit.
# Outputs:
#   Rendered rule content, a "No rules match..." message, or an error message.
# Returns:
#   0 on a rendered result or a filter match of zero rules; 1 when neither
#   ids nor a filter is supplied, or when ids resolves to no valid rule.
tool_get_rules() {
    local args="$1"

    local ids_raw
    ids_raw=$(printf '%s' "${args}" | jq -r '.ids // empty')

    # Detect filter parameters
    local filter_group filter_test_type filter_test_category filter_scope filter_enforce
    filter_group=$(printf '%s' "${args}" | jq -r '.group // empty')
    filter_test_type=$(printf '%s' "${args}" | jq -r '.test_type // empty')
    filter_test_category=$(printf '%s' "${args}" | jq -r '.test_category // empty')
    filter_scope=$(printf '%s' "${args}" | jq -r '.scope // empty')
    filter_enforce=$(printf '%s' "${args}" | jq -r '.enforce // empty')

    local filter_scoped_review
    filter_scoped_review=$(printf '%s' "${args}" | jq -r '.scoped_review // empty')

    local filter_review_unit
    filter_review_unit=$(printf '%s' "${args}" | jq -r '.review_unit // empty')

    local has_filters=false
    [[ -n "${filter_group}" || -n "${filter_test_type}" || -n "${filter_test_category}" || -n "${filter_scope}" || -n "${filter_enforce}" || -n "${filter_scoped_review}" || -n "${filter_review_unit}" ]] && has_filters=true

    if [[ -z "${ids_raw}" ]] && [[ "${has_filters}" == false ]]; then
        printf 'Error: provide either ids (comma-separated rule IDs) or filter parameters (group, test_type, test_category, scope, enforce, scoped_review, review_unit).\n'
        return 1
    fi

    # Build list of IDs to retrieve
    local -a target_ids=()

    if [[ -n "${ids_raw}" ]]; then
        # ID mode: split comma-separated IDs. Pathname expansion is disabled
        # for this loop so a caller-supplied id containing a glob character
        # (e.g. "CONV-*") stays literal instead of matching filenames in the
        # process working directory. `local -` restores the caller's option set
        # on return; a bare `set +f` would instead force globbing back ON for a
        # caller that had already disabled it.
        log "INFO" "get_rules: ids=${ids_raw}"
        local IFS=','
        local raw_id
        local -
        set -f
        for raw_id in ${ids_raw}; do
            raw_id=$(printf '%s' "${raw_id}" | tr -d '[:space:]')
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
            printf 'No rules match the specified filters.\n'
            return 0
        fi
    fi

    # Render full content for each ID via the shared renderer (also used by
    # tool_build_rule_package, so both emit byte-identical output).
    # ID mode can reach here with nothing collected — `{"ids":","}` passes the
    # non-empty check above and then strips to no ids at all. Expanding an empty
    # array as a plain "${a[@]}" aborts under set -u on every bash before 4.4,
    # short of the "no valid IDs" refusal below; the +-guarded form passes zero
    # arguments instead, so _render_rules refuses uniformly across the range.
    local output
    if ! output=$(_render_rules ${target_ids[@]+"${target_ids[@]}"}); then
        printf 'Error: no valid IDs provided\n'
        return 1
    fi

    printf '%s\n' "${output}"
}
