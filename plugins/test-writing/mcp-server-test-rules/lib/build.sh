#!/usr/bin/env bash
# build_rule_package tool for test-rules MCP server
# Renders the unit-review rule catalog (convention, design, unit, isolation,
# provider) once to a file in Claude Code plugin storage and returns its
# absolute path. Review agents read that file instead of fetching rules per
# agent. With no arguments it renders the full catalog, byte-identical to
# concatenating get_rules(group=X) over the five groups (both paths render
# through _render_rules).
#
# Optional scope filters (review_unit / test_category / scoped_review) render a
# SUBSET so team review can inject only each agent's applicable rules instead of
# the full catalog. They mirror the get_rules filters and forward through the
# shared _filter_rules, so a scoped package is byte-identical to the matching
# get_rules selection. Scoped packages are written under scope-derived filenames
# so the per-track packages a single composition builds coexist as distinct
# paths; the unscoped package keeps the canonical unit-review.md name.

tool_build_rule_package() {
    local args="${1:-}"
    # The dispatcher always passes an arguments object ("{}" when empty); default
    # it so a bare call (e.g. a test) does not feed jq empty input.
    if [[ -z "${args}" ]]; then args='{}'; fi

    # Optional scope filters (mirror get_rules). Omitted => full catalog.
    local filter_test_category filter_scoped_review filter_review_unit
    filter_test_category=$(printf '%s' "${args}" | jq -r '.test_category // empty')
    filter_scoped_review=$(printf '%s' "${args}" | jq -r '.scoped_review // empty')
    filter_review_unit=$(printf '%s' "${args}" | jq -r '.review_unit // empty')

    # The five unit-review rule groups, in reviewing-skill phase order.
    local -a unit_review_groups=(convention design unit isolation provider)

    # Fail hard on unset storage. No fallback to /tmp or CLAUDE_PLUGIN_ROOT — a
    # silent fallback would write the catalog where agents cannot find it.
    if [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]]; then
        printf 'Error: CLAUDE_PLUGIN_DATA is not set; the test-rules MCP server cannot locate plugin storage.\n'
        return 1
    fi

    # Build the ordered union of rule IDs: each group in phase order, rules
    # within a group in discovery order — exactly what get_rules(group=X)
    # returns. The optional scope filters thread through _filter_rules, which
    # accepts a comma-separated review_unit list (whole-class fused track passes
    # "class-structure,class-bodies").
    local -a ids=()
    local -a rendered_groups=()
    local group id before
    for group in "${unit_review_groups[@]}"; do
        before=${#ids[@]}
        while IFS= read -r id; do
            [[ -n "${id}" ]] && ids+=("${id}")
        done < <(_filter_rules "${group}" "" "${filter_test_category}" "" "" "${filter_scoped_review}" "${filter_review_unit}")
        # Track which groups actually contributed a rule so the reported
        # `groups:` line reflects the rendered subset, not the candidate set.
        if [[ ${#ids[@]} -gt ${before} ]]; then rendered_groups+=("${group}"); fi
    done

    # Fail hard when nothing renders — an empty index or a scope that matches no
    # rule. Never write an empty package an agent would silently apply as "no
    # rules". (Also guards the empty-array expansion below under set -u.)
    if [[ ${#ids[@]} -eq 0 ]]; then
        printf 'Error: build_rule_package rendered zero rules; the rule index is empty or the scope filters matched nothing (review_unit=%s test_category=%s scoped_review=%s).\n' \
            "${filter_review_unit:-*}" "${filter_test_category:-*}" "${filter_scoped_review:-false}"
        return 1
    fi

    # Render via the shared get_rules code path so the bytes match by
    # construction.
    local rendered
    if ! rendered=$(_render_rules "${ids[@]}"); then
        printf 'Error: build_rule_package rendered zero rules; the rule index is empty or unreadable.\n'
        return 1
    fi

    # Scope-derived filename so a composition's per-(track, category, scoped)
    # packages coexist as distinct paths; the unscoped package keeps the
    # canonical name so the full-catalog path stays byte-stable. review_unit
    # commas become '+' (filesystem-safe).
    local key=""
    if [[ -n "${filter_review_unit}" ]]; then key="${key}-ru-${filter_review_unit//,/+}"; fi
    if [[ -n "${filter_test_category}" ]]; then key="${key}-cat-${filter_test_category}"; fi
    if [[ "${filter_scoped_review}" == "true" ]]; then key="${key}-scoped"; fi
    local target_name="unit-review${key}.md"

    # Atomic write to plugin storage (mirrors redundant-read-blocker save_tracker).
    local dir="${CLAUDE_PLUGIN_DATA}/rule-packages"
    local target="${dir}/${target_name}"
    if ! mkdir -p "${dir}"; then
        printf 'Error: build_rule_package could not create the storage directory: %s\n' "${dir}"
        return 1
    fi

    local tmp
    if ! tmp=$(mktemp "${dir}/.unit-review.XXXXXX"); then
        printf 'Error: build_rule_package could not create a temp file in: %s\n' "${dir}"
        return 1
    fi

    if ! printf '%s\n' "${rendered}" > "${tmp}"; then
        rm -f -- "${tmp}"
        printf 'Error: build_rule_package failed to write the package contents.\n'
        return 1
    fi

    if ! mv -- "${tmp}" "${target}"; then
        rm -f -- "${tmp}"
        printf 'Error: build_rule_package failed to move the package into place: %s\n' "${target}"
        return 1
    fi

    # Report path + bytes + rule count + groups for the orchestrator to parse.
    local bytes
    bytes=$(wc -c < "${target}" | tr -d ' ')

    local groups_csv=""
    for group in "${rendered_groups[@]}"; do
        groups_csv="${groups_csv:+${groups_csv},}${group}"
    done

    printf 'path: %s\n' "${target}"
    printf 'bytes: %s\n' "${bytes}"
    printf 'rules: %s\n' "${#ids[@]}"
    printf 'groups: %s\n' "${groups_csv}"
}
