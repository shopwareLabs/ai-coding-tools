#!/usr/bin/env bash
# Common utilities for test-rules MCP server
# Provides frontmatter parser, index builder, and CSV helpers

# Associative arrays for the rule index (populated by _build_rule_index)
declare -gA RULE_ID_TO_FILE=()
declare -gA LEGACY_TO_ID=()
declare -gA RULE_TITLE=()
declare -gA RULE_GROUP=()
declare -gA RULE_ENFORCE=()
declare -gA RULE_TEST_TYPES=()
declare -gA RULE_TEST_CATEGORIES=()
declare -gA RULE_SCOPE=()
declare -gA RULE_LEGACY=()

# All rule IDs in discovery order
declare -ga RULE_IDS=()

# Parse a single frontmatter field from a rule file.
# Uses sed only — no yq dependency.
# Args: $1 = field name, $2 = file path
# Outputs: field value (trimmed)
_get_field() {
    sed -n "/^$1: */s/^$1: *//p" "$2"
}

# Build the rule index by scanning all rules/*/*.md files.
# Populates associative arrays for fast lookup.
# Args: $1 = rules directory path
_build_rule_index() {
    local rules_dir="$1"
    local file id title legacy group enforce test_types test_categories scope

    for file in "${rules_dir}"/*/*.md; do
        [[ -f "${file}" ]] || continue

        id=$(_get_field "id" "${file}")
        [[ -z "${id}" ]] && continue

        title=$(_get_field "title" "${file}")
        legacy=$(_get_field "legacy" "${file}")
        group=$(_get_field "group" "${file}")
        enforce=$(_get_field "enforce" "${file}")
        test_types=$(_get_field "test-types" "${file}")
        test_categories=$(_get_field "test-categories" "${file}")
        scope=$(_get_field "scope" "${file}")

        RULE_IDS+=("${id}")
        RULE_ID_TO_FILE["${id}"]="${file}"
        RULE_TITLE["${id}"]="${title}"
        RULE_GROUP["${id}"]="${group}"
        RULE_ENFORCE["${id}"]="${enforce}"
        RULE_TEST_TYPES["${id}"]="${test_types}"
        RULE_TEST_CATEGORIES["${id}"]="${test_categories}"
        RULE_SCOPE["${id}"]="${scope}"
        RULE_LEGACY["${id}"]="${legacy}"

        if [[ -n "${legacy}" ]]; then
            LEGACY_TO_ID["${legacy}"]="${id}"
        fi
    done

    log "INFO" "Indexed ${#RULE_IDS[@]} rules from ${rules_dir}"
}

# Check if a CSV field contains a specific value.
# Args: $1 = CSV string (e.g. "A,B,C"), $2 = value to find
# Returns: 0 if found, 1 if not
_csv_contains() {
    local csv="$1"
    local needle="$2"
    local IFS=','
    local item
    for item in ${csv}; do
        [[ "${item}" == "${needle}" ]] && return 0
    done
    return 1
}

# Filter rules by metadata criteria.
# Outputs matching rule IDs, one per line.
# Args: $1=group, $2=test_type, $3=test_category, $4=scope, $5=enforce
# All args are optional (pass empty string to skip a filter).
_filter_rules() {
    local filter_group="${1:-}" filter_test_type="${2:-}" filter_test_category="${3:-}" filter_scope="${4:-}" filter_enforce="${5:-}"
    local id

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

        echo "${id}"
    done
}

# Strip YAML frontmatter from a markdown file (removes both --- delimiters and content between).
# Args: $1 = file path
# Outputs: file content without frontmatter
_strip_frontmatter() {
    awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$1"
}
