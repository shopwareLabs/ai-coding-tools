#!/usr/bin/env bash
# Common utilities for test-rules MCP server
# Provides frontmatter parser, index builder, and CSV helpers

# Associative arrays for the rule index (populated by _build_rule_index)
declare -gA RULE_ID_TO_FILE=()
declare -gA RULE_TITLE=()
declare -gA RULE_GROUP=()
declare -gA RULE_ENFORCE=()
declare -gA RULE_TEST_TYPES=()
declare -gA RULE_TEST_CATEGORIES=()
declare -gA RULE_SCOPE=()
declare -gA RULE_CLASS_SCOPE_ONLY=()
declare -gA RULE_REVIEW_UNIT=()

# All rule IDs in discovery order
declare -ga RULE_IDS=()

# Parse a single frontmatter field from a rule file.
# Uses sed only — no yq dependency.
# Args: $1 = field name, $2 = file path
# Outputs: field value (trimmed)
_get_field() {
    sed -n "/^$1: */s/^$1: *//p" "$2"
}

# Parse a single field scoped to the leading `--- ... ---` frontmatter block,
# with leading/trailing whitespace trimmed. Unlike _get_field (a whole-file sed
# match), this ignores body lines and trims, so it mirrors the CI gate's parser
# (.github/scripts/validate-review-unit.sh:read_frontmatter_field). Used for the
# validated review-unit field so the gate and the server agree on the value.
# Args: $1 = field name, $2 = file path
# Outputs: trimmed field value (empty if absent)
_get_frontmatter_field() {
    local field="$1" file="$2"
    local in_frontmatter=0 delim_count=0 line val
    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" == "---" ]]; then
            delim_count=$((delim_count + 1))
            if [[ ${delim_count} -eq 1 ]]; then
                in_frontmatter=1
                continue
            fi
            break
        fi
        if [[ ${in_frontmatter} -eq 1 && "${line}" == "${field}:"* ]]; then
            val="${line#"${field}":}"
            val="${val#"${val%%[![:space:]]*}"}"
            val="${val%"${val##*[![:space:]]}"}"
            printf '%s\n' "${val}"
            return 0
        fi
    done < "${file}"
    return 0
}

# Build the rule index by scanning all rules/*/*.md files.
# Populates associative arrays for fast lookup.
# Args: $1 = rules directory path
_build_rule_index() {
    local rules_dir="$1"
    local file id title group enforce test_types test_categories scope review_unit
    local -a invalid_review_unit=()

    for file in "${rules_dir}"/*/*.md; do
        [[ -f "${file}" ]] || continue

        id=$(_get_field "id" "${file}")
        [[ -z "${id}" ]] && continue

        # review-unit is required and validated: a missing or invalid value is an
        # error, not an empty index entry (an empty value would silently drop the
        # rule from review_unit= queries). Collect offenders and fail the build.
        # Read frontmatter-scoped + trimmed so a trailing space or a body mention
        # cannot diverge from the CI gate (which would brick startup while CI stays green).
        review_unit=$(_get_frontmatter_field "review-unit" "${file}")
        case "${review_unit}" in
            method|class-structure|class-bodies) ;;
            *)
                invalid_review_unit+=("${id} (${file}): review-unit='${review_unit}'")
                continue
                ;;
        esac

        title=$(_get_field "title" "${file}")
        group=$(_get_field "group" "${file}")
        enforce=$(_get_field "enforce" "${file}")
        test_types=$(_get_field "test-types" "${file}")
        test_categories=$(_get_field "test-categories" "${file}")
        scope=$(_get_field "scope" "${file}")

        local class_scope_only
        class_scope_only=$(_get_field "class-scope-only" "${file}")

        RULE_IDS+=("${id}")
        # shellcheck disable=SC2034  # RULE_ID_TO_FILE consumed by lib/get.sh via dynamic scope
        RULE_ID_TO_FILE["${id}"]="${file}"
        # shellcheck disable=SC2034  # RULE_TITLE consumed by lib/get.sh via dynamic scope
        RULE_TITLE["${id}"]="${title}"
        RULE_GROUP["${id}"]="${group}"
        RULE_ENFORCE["${id}"]="${enforce}"
        RULE_TEST_TYPES["${id}"]="${test_types}"
        RULE_TEST_CATEGORIES["${id}"]="${test_categories}"
        RULE_SCOPE["${id}"]="${scope}"
        RULE_CLASS_SCOPE_ONLY["${id}"]="${class_scope_only}"
        RULE_REVIEW_UNIT["${id}"]="${review_unit}"
    done

    if [[ ${#invalid_review_unit[@]} -gt 0 ]]; then
        local offender
        for offender in "${invalid_review_unit[@]}"; do
            log "ERROR" "Rule missing or invalid review-unit (must be method|class-structure|class-bodies): ${offender}"
        done
        log "ERROR" "Refusing to index: ${#invalid_review_unit[@]} rule(s) with missing or invalid review-unit"
        return 1
    fi

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
# Args: $1=group, $2=test_type, $3=test_category, $4=scope, $5=enforce,
#       $6=scoped_review, $7=review_unit
# All args are optional (pass empty string to skip a filter).
# review_unit is orthogonal to scoped_review: it filters by the minimal
# evaluation input a rule's detection algorithm needs, not by review mode.
_filter_rules() {
    local filter_group="${1:-}" filter_test_type="${2:-}" filter_test_category="${3:-}" filter_scope="${4:-}" filter_enforce="${5:-}" filter_scoped_review="${6:-}" filter_review_unit="${7:-}"
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

        # Filter by scoped review: exclude class-scope-only rules
        if [[ -n "${filter_scoped_review}" ]] && [[ "${filter_scoped_review}" == "true" ]]; then
            if [[ "${RULE_CLASS_SCOPE_ONLY[${id}]}" == "true" ]]; then
                continue
            fi
        fi

        # Filter by review unit: exact match on the minimal evaluation input
        if [[ -n "${filter_review_unit}" ]] && [[ "${RULE_REVIEW_UNIT[${id}]}" != "${filter_review_unit}" ]]; then
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
