#!/usr/bin/env bash
# build_rule_package tool for test-rules MCP server

# Render a rule catalog to a file in Claude Code plugin storage and return its
# absolute path. Review agents read that file instead of fetching rules per
# agent.
#
# Without `group` it composes the catalog for `test_type` (unit when the field
# is absent): that type's own group together with every convention, design,
# isolation, and provider rule whose test-types declares the type. The result is
# byte-identical to get_rules(test_type=X) — both compose through
# _composed_rule_ids and render through _render_rules. The unified team review
# builds one catalog per test type present this way.
#
# Pass `group` (with `test_type`) to render that single group instead — the
# integration-to-unit migrating skill's group=placement path.
#
# Optional scope filters (review_unit / test_category / scoped_review / scope /
# enforce) render a SUBSET so team review can inject only each agent's
# applicable rules instead of the full catalog. They mirror the get_rules
# filters and forward through the shared _filter_rules, so a scoped package is
# byte-identical to the matching get_rules selection. Packages are written
# under scope-derived filenames so the per-catalog packages that a single
# composition builds coexist as distinct paths; the unscoped unit catalog keeps
# the canonical unit-review.md name.
# Globals:
#   CLAUDE_PLUGIN_DATA - plugin storage root; required, no fallback.
# Arguments:
#   JSON arguments object (optional; a bare call defaults to "{}"): test_type
#   selects the composed catalog, group narrows to a single rule group;
#   review_unit, test_category, scoped_review, scope, enforce render a scoped
#   subset of whichever catalog is selected.
# Outputs:
#   On success: `path:`, `bytes:`, `rules:`, `groups:` lines on stdout. On
#   failure: an `Error: ...` message on stdout.
# Returns:
#   0 on a written package; 1 when CLAUDE_PLUGIN_DATA is unset, the test type
#   has no composed catalog, the filtered rule set is empty, or the storage
#   directory/file write fails.
tool_build_rule_package() {
    local args="${1:-}"
    # The dispatcher always passes an arguments object ("{}" when empty); default
    # it so a bare call (e.g. a test) does not feed jq empty input.
    if [[ -z "${args}" ]]; then args='{}'; fi

    # Optional group/test_type selector + scope filters (mirror get_rules).
    # group omitted => the composed catalog for test_type (unit when absent).
    local filter_group filter_test_type filter_test_category filter_scoped_review filter_review_unit filter_scope filter_enforce
    filter_group=$(printf '%s' "${args}" | jq -r '.group // empty')
    filter_test_type=$(printf '%s' "${args}" | jq -r '.test_type // empty')
    filter_test_category=$(printf '%s' "${args}" | jq -r '.test_category // empty')
    filter_scoped_review=$(printf '%s' "${args}" | jq -r '.scoped_review // empty')
    filter_review_unit=$(printf '%s' "${args}" | jq -r '.review_unit // empty')
    filter_scope=$(printf '%s' "${args}" | jq -r '.scope // empty')
    filter_enforce=$(printf '%s' "${args}" | jq -r '.enforce // empty')

    # Groups to render. A single `group` renders that group with the test_type
    # filter; no `group` composes the requested type's catalog — its own group
    # plus the four shared groups, in reviewing-skill phase order. An absent
    # test_type composes the unit catalog, so a bare call keeps rendering the
    # canonical unit-review package.
    local -a groups=()
    local group group_test_type
    if [[ -n "${filter_group}" ]]; then
        groups=("${filter_group}")
        group_test_type="${filter_test_type}"
    else
        group_test_type="${filter_test_type:-unit}"
        local groups_raw
        if ! groups_raw=$(_composed_groups "${group_test_type}"); then
            printf 'Error: build_rule_package cannot compose a catalog for test_type=%s; expected unit, integration, or migration.\n' "${group_test_type}"
            return 1
        fi
        while IFS= read -r group; do
            [[ -n "${group}" ]] && groups+=("${group}")
        done <<< "${groups_raw}"
    fi

    # Fail hard on unset storage. No fallback to /tmp or CLAUDE_PLUGIN_ROOT — a
    # silent fallback would write the catalog where agents cannot find it.
    if [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]]; then
        printf 'Error: CLAUDE_PLUGIN_DATA is not set; the test-rules MCP server cannot locate plugin storage.\n'
        return 1
    fi

    # Build the ordered union of rule IDs: each group in render order, rules
    # within a group in discovery order — the same walk _composed_rule_ids makes
    # for get_rules, so the two tools present the same selection. The optional
    # scope filters thread through _filter_rules, which accepts a
    # comma-separated review_unit list (whole-class fused track passes
    # "class-structure,class-bodies").
    local -a ids=()
    local -a rendered_groups=()
    local id before
    for group in "${groups[@]}"; do
        before=${#ids[@]}
        while IFS= read -r id; do
            [[ -n "${id}" ]] && ids+=("${id}")
        done < <(_filter_rules "${group}" "${group_test_type}" "${filter_test_category}" "${filter_scope}" "${filter_enforce}" "${filter_scoped_review}" "${filter_review_unit}")
        # Track which groups actually contributed a rule so the reported
        # `groups:` line reflects the rendered subset, not the candidate set.
        if [[ ${#ids[@]} -gt ${before} ]]; then rendered_groups+=("${group}"); fi
    done

    # Fail hard when nothing renders — an empty index or a scope that matches no
    # rule. Never write an empty package an agent would silently apply as "no
    # rules". (Also guards the empty-array expansion below under set -u.)
    if [[ ${#ids[@]} -eq 0 ]]; then
        printf 'Error: build_rule_package rendered zero rules; the rule index is empty or the scope filters matched nothing (group=%s test_type=%s review_unit=%s test_category=%s scoped_review=%s scope=%s enforce=%s).\n' \
            "${filter_group:-*}" "${filter_test_type:-*}" "${filter_review_unit:-*}" "${filter_test_category:-*}" "${filter_scoped_review:-false}" "${filter_scope:-*}" "${filter_enforce:-*}"
        return 1
    fi

    # Render via the shared get_rules code path so the bytes match by
    # construction.
    local rendered
    if ! rendered=$(_render_rules "${ids[@]}"); then
        printf 'Error: build_rule_package rendered zero rules; the rule index is empty or unreadable.\n'
        return 1
    fi

    # Scope-derived filename so a composition's per-(group, type, track,
    # category, scoped) packages coexist as distinct paths; the unscoped unit
    # package keeps the canonical name so the full-catalog path stays
    # byte-stable. review_unit commas become '+' (filesystem-safe).
    local key=""
    if [[ -n "${filter_group}" ]]; then key="${key}-grp-${filter_group}"; fi
    if [[ -n "${filter_test_type}" ]]; then key="${key}-tt-${filter_test_type}"; fi
    if [[ -n "${filter_review_unit}" ]]; then key="${key}-ru-${filter_review_unit//,/+}"; fi
    if [[ -n "${filter_test_category}" ]]; then key="${key}-cat-${filter_test_category}"; fi
    if [[ "${filter_scoped_review}" == "true" ]]; then key="${key}-scoped"; fi
    if [[ -n "${filter_scope}" ]]; then key="${key}-scope-${filter_scope}"; fi
    if [[ -n "${filter_enforce}" ]]; then key="${key}-enf-${filter_enforce}"; fi
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
