#!/usr/bin/env bash
# get_rules tool for test-rules MCP server
# Retrieves full content of rules by ID or by metadata filters

# Retrieve full content for a set of rules, either by explicit IDs or by
# metadata filters, rendered through the shared _render_rules renderer.
#
# A `test_type` with no `group` returns that type's composed catalog — the
# type's own group plus every convention, design, isolation, and provider rule
# whose test-types declares the type — byte-identical to the matching
# build_rule_package call. With a `group`, the filters apply within that group.
# Arguments:
#   JSON arguments object with either `ids` (comma-separated rule IDs) or one
#   or more filter fields: group, test_type, test_category, scope, enforce,
#   scoped_review, review_unit.
# Outputs:
#   Rendered rule content, a "No rules match..." message, or an error message.
# Returns:
#   0 on a rendered result or a non-composed filter match of zero rules; 1 when
#   neither ids nor a filter is supplied, when the test type has no composed
#   catalog, when a composed catalog (test_type without group) matches zero
#   rules, or when ids resolves to no valid rule.
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
        local composed_path=false
        if [[ -z "${filter_group}" ]] && [[ -n "${filter_test_type}" ]]; then
            # A test type without a group asks for that type's catalog: its own
            # group plus every convention/design/isolation/provider rule
            # declaring the type. Composed through the same helper
            # build_rule_package walks, so both tools present one selection.
            composed_path=true
            local composed
            if ! composed=$(_composed_rule_ids "${filter_test_type}" "${filter_test_category}" "${filter_scope}" "${filter_enforce}" "${filter_scoped_review}" "${filter_review_unit}"); then
                printf 'Error: get_rules cannot compose a catalog for test_type=%s; expected unit, integration, or migration.\n' "${filter_test_type}"
                return 1
            fi
            while IFS= read -r filtered_id; do
                [[ -n "${filtered_id}" ]] && target_ids+=("${filtered_id}")
            done <<< "${composed}"
        else
            while IFS= read -r filtered_id; do
                [[ -n "${filtered_id}" ]] && target_ids+=("${filtered_id}")
            done < <(_filter_rules "${filter_group}" "${filter_test_type}" "${filter_test_category}" "${filter_scope}" "${filter_enforce}" "${filter_scoped_review}" "${filter_review_unit}")
        fi

        if [[ ${#target_ids[@]} -eq 0 ]]; then
            # A composed catalog (test_type with no group) yielding zero rules is
            # a hard failure, matching build_rule_package: an empty composed
            # selection would otherwise look like "the type has no violations"
            # rather than "the catalog could not be composed under this filter
            # set". The non-composed (explicit group, or no test_type at all)
            # empty result stays a success — it legitimately means "no rule in
            # this group/filter combination", not a broken composition.
            if [[ "${composed_path}" == true ]]; then
                printf 'Error: get_rules composed catalog for test_type=%s matched zero rules (test_category=%s scope=%s enforce=%s scoped_review=%s review_unit=%s).\n' \
                    "${filter_test_type}" "${filter_test_category:-*}" "${filter_scope:-*}" "${filter_enforce:-*}" "${filter_scoped_review:-false}" "${filter_review_unit:-*}"
                return 1
            fi
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
