#!/usr/bin/env bash
# build_rule_package tool for test-rules MCP server
# Renders the unit-review rule catalog (convention, design, unit, isolation,
# provider) once to a file in Claude Code plugin storage and returns its
# absolute path. Review agents read that file instead of fetching rules per
# agent. Output is byte-identical to concatenating get_rules(group=X) over the
# five groups, because both paths render through _render_rules.

tool_build_rule_package() {
    # The five unit-review rule groups, in reviewing-skill phase order.
    local -a unit_review_groups=(convention design unit isolation provider)

    # Fail hard on unset storage. No fallback to /tmp or CLAUDE_PLUGIN_ROOT — a
    # silent fallback would write the catalog where agents cannot find it.
    if [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]]; then
        printf 'Error: CLAUDE_PLUGIN_DATA is not set; the test-rules MCP server cannot locate plugin storage.\n'
        return 1
    fi

    # Build the ordered union of rule IDs: each group in phase order, rules
    # within a group in discovery order — exactly what get_rules(group=X) returns.
    local -a ids=()
    local group id
    for group in "${unit_review_groups[@]}"; do
        while IFS= read -r id; do
            [[ -n "${id}" ]] && ids+=("${id}")
        done < <(_filter_rules "${group}" "" "" "" "" "" "")
    done

    # Render via the shared get_rules code path so the bytes match by
    # construction. Fail hard if zero rules render (empty or unreadable index).
    local rendered
    if ! rendered=$(_render_rules "${ids[@]}"); then
        printf 'Error: build_rule_package rendered zero rules; the rule index is empty or unreadable.\n'
        return 1
    fi

    # Atomic write to plugin storage (mirrors redundant-read-blocker save_tracker).
    local dir="${CLAUDE_PLUGIN_DATA}/rule-packages"
    local target="${dir}/unit-review.md"
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

    printf 'path: %s\n' "${target}"
    printf 'bytes: %s\n' "${bytes}"
    printf 'rules: %s\n' "${#ids[@]}"
    printf 'groups: %s\n' "convention,design,unit,isolation,provider"
}
