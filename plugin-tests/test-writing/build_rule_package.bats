#!/usr/bin/env bats
# bats file_tags=test-writing,build-rule-package
# Tests for the build_rule_package tool of the test-rules MCP server
# (lib/build.sh + the shared lib/common.sh:_render_rules renderer): byte-fidelity
# against get_rules, fail-hard guards, unit-review scoping, and atomic write.
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

setup() {
    MCP_LOG_FILE="${BATS_TEST_TMPDIR}/mcp.log"
    export MCP_LOG_FILE
    log() { printf '[%s] %s\n' "$1" "$2" >> "${MCP_LOG_FILE}"; }
    source "${TEST_RULES_LIB_DIR}/common.sh"
    source "${TEST_RULES_LIB_DIR}/get.sh"
    source "${TEST_RULES_LIB_DIR}/build.sh"

    # Each test gets its own plugin-storage root; tests that exercise the unset
    # or write-failure guards override it locally.
    export CLAUDE_PLUGIN_DATA="${BATS_TEST_TMPDIR}/plugindata"
}

# Extract the `path:` value from a build_rule_package response in $output.
_pkg_path() {
    local p="${output#*path: }"
    printf '%s' "${p%%$'\n'*}"
}

# ============================================================================
# §7.1 Byte-fidelity golden — package == concatenated get_rules(group=X)
# ============================================================================

@test "build_rule_package output is byte-identical to concatenated get_rules(group=X)" {
    # Equality is by construction (both render through _render_rules); this pins
    # it so a future divergence in either path fails loudly.
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package
    assert_success

    local pkg
    pkg="$(_pkg_path)"
    assert [ -f "${pkg}" ]

    local expected="" g part
    for g in convention design unit isolation provider; do
        part="$(tool_get_rules "{\"group\":\"${g}\"}")"
        if [[ -n "${expected}" ]]; then
            expected="${expected}"$'\n\n'"---"$'\n\n'
        fi
        expected="${expected}${part}"
    done

    local actual
    actual="$(cat "${pkg}")"
    assert_equal "${actual}" "${expected}"
}

# Count the rule files the unit-review catalog is built from, straight off disk.
# Derived without the index or the filter the tool itself walks, so a rule that
# fails to index, gets dropped by a filter, or renders empty surfaces as a
# mismatch instead of passing under a threshold.
_unit_review_rules_on_disk() {
    local group file count=0
    for group in convention design unit isolation provider; do
        for file in "${RULES_DIR}/${group}"/*.md; do
            [[ -e "${file}" ]] || continue
            count=$(( count + 1 ))
        done
    done
    printf '%s\n' "${count}"
}

@test "build_rule_package reports one rule per unit-review rule file, known rule ids present, and a matching byte count" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package
    assert_success

    # A floor (the previous assertion was `-ge 40` against 46 real rules) lets
    # rules disappear silently. An exact literal would churn on every deliberate
    # rule add or removal. Comparing against the file count does neither: both
    # sides move together when a rule is added or removed on purpose, and any
    # rule the tool loses on the way to the package is a mismatch.
    local reported_rules expected_rules
    reported_rules="${output#*rules: }"
    reported_rules="${reported_rules%%$'\n'*}"
    expected_rules="$(_unit_review_rules_on_disk)"
    assert_equal "${reported_rules}" "${expected_rules}"
    assert_line "groups: convention,design,unit,isolation,provider"

    local pkg reported actual
    pkg="$(_pkg_path)"
    reported="${output#*bytes: }"
    reported="${reported%%$'\n'*}"
    actual="$(wc -c < "${pkg}" | tr -d ' ')"
    assert_equal "${reported}" "${actual}"

    # The count proves how many rules rendered; these prove which. A swap that
    # drops one rule and adds another keeps the count intact. One confirmed
    # on-disk must-fix/should-fix rule per unit-review group, distinct from the
    # "-001" sentinels asserted below.
    run cat "${pkg}"
    assert_output --partial "# CONV-002 "
    assert_output --partial "# DESIGN-002 "
    assert_output --partial "# UNIT-002 "
    assert_output --partial "# ISOLATION-002 "
    assert_output --partial "# PROVIDER-002 "
}

# ============================================================================
# §7.4 Scoping — only the five unit-review groups are rendered
# ============================================================================

@test "build_rule_package renders the five unit-review group sentinels" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package
    assert_success
    local pkg
    pkg="$(_pkg_path)"

    run cat "${pkg}"
    assert_output --partial "# CONV-001 "
    assert_output --partial "# DESIGN-001 "
    assert_output --partial "# UNIT-001 "
    assert_output --partial "# ISOLATION-001 "
    assert_output --partial "# PROVIDER-001 "
}

@test "build_rule_package excludes migration, integration, and placement rules" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package
    assert_success
    local pkg
    pkg="$(_pkg_path)"

    # Inspect only rule-header lines (# ID — Title); bodies never start that way.
    run grep -E '^# [A-Z]+-[0-9]+ ' "${pkg}"
    assert_success
    refute_line --partial "MIGRATION-"
    refute_line --partial "INTEGRATION-"
    refute_line --partial "PLACEMENT-"
}

@test "build_rule_package strips YAML frontmatter from every rule" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package
    assert_success
    local pkg
    pkg="$(_pkg_path)"

    # The frontmatter `id:` line must not survive; the first line is a header.
    run grep -c '^id: ' "${pkg}"
    assert_output "0"
    run head -1 "${pkg}"
    assert_output "# CONV-001 — Attribute Order"
}

# ============================================================================
# §7.3 Fail-hard guards — no silent fallback
# ============================================================================

@test "build_rule_package fails hard when CLAUDE_PLUGIN_DATA is unset" {
    _build_rule_index "${RULES_DIR}"
    unset CLAUDE_PLUGIN_DATA
    run tool_build_rule_package
    assert_failure
    assert_output --partial "CLAUDE_PLUGIN_DATA is not set"
}

@test "build_rule_package fails hard when zero rules render" {
    local empty="${BATS_TEST_TMPDIR}/emptyrules"
    mkdir -p "${empty}"
    _build_rule_index "${empty}"
    run tool_build_rule_package
    assert_failure
    assert_output --partial "rendered zero rules"
    # No file may be written on the zero-rules path.
    assert [ ! -e "${CLAUDE_PLUGIN_DATA}/rule-packages/unit-review.md" ]
}

@test "build_rule_package fails hard when the storage directory cannot be created" {
    _build_rule_index "${RULES_DIR}"
    # Point storage at a regular file so mkdir -p of its child fails (ENOTDIR).
    local blocker="${BATS_TEST_TMPDIR}/blocker"
    touch "${blocker}"
    export CLAUDE_PLUGIN_DATA="${blocker}"
    run tool_build_rule_package
    assert_failure
    assert_output --partial "could not create the storage directory"
    assert [ ! -e "${blocker}/rule-packages/unit-review.md" ]
}

# ============================================================================
# §7.5 Atomic write — file is complete, no temp residue
# ============================================================================

@test "build_rule_package leaves no temp residue and writes a complete file" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package
    assert_success
    local pkg
    pkg="$(_pkg_path)"

    # Complete: the last group (provider) is present through its final rule.
    run cat "${pkg}"
    assert_output --partial "# PROVIDER-005 "

    # No partial temp file left behind in the storage directory.
    run bash -c 'set -- "$1"/rule-packages/.unit-review.*; [ -e "$1" ] && echo LEFTOVER || echo CLEAN' _ "${CLAUDE_PLUGIN_DATA}"
    assert_output "CLEAN"
}

@test "build_rule_package overwrites a prior package atomically on rebuild" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package
    assert_success
    local pkg first
    pkg="$(_pkg_path)"
    first="$(cat "${pkg}")"

    run tool_build_rule_package
    assert_success
    local second
    second="$(cat "${pkg}")"
    assert_equal "${second}" "${first}"

    run bash -c 'set -- "$1"/rule-packages/.unit-review.*; [ -e "$1" ] && echo LEFTOVER || echo CLEAN' _ "${CLAUDE_PLUGIN_DATA}"
    assert_output "CLEAN"
}

# ============================================================================
# §7.6 Scoped packages — review_unit / test_category / scoped_review render a
# byte-faithful subset under a scope-derived filename (C2 per-track scoping)
# ============================================================================

# Render the catalog IDs a scope should produce, via the same _filter_rules /
# _render_rules the tool uses — the independent expectation for byte-fidelity.
# Args: $1=test_category (empty=no filter), $2=scoped_review ("true"/empty),
#       $3=review_unit (empty=no filter; may be comma-separated).
_scoped_render() {
    local cat="$1" scoped="$2" ru="$3"
    local -a want=()
    local g id
    for g in convention design unit isolation provider; do
        while IFS= read -r id; do
            [[ -n "${id}" ]] && want+=("${id}")
        done < <(_filter_rules "${g}" "" "${cat}" "" "" "${scoped}" "${ru}")
    done
    _render_rules "${want[@]}"
}

@test "build_rule_package review_unit scope renders a byte-faithful subset" {
    # Guards the wiring: had build.sh dropped the review_unit filter it would
    # render all 49 rules; the expectation renders only the method rules.
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"review_unit":"method"}'
    assert_success
    local pkg actual expected
    pkg="$(_pkg_path)"
    actual="$(cat "${pkg}")"
    expected="$(_scoped_render "" "" "method")"
    assert_equal "${actual}" "${expected}"
}

@test "build_rule_package review_unit list renders the union of both units" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"review_unit":"class-structure,class-bodies"}'
    assert_success
    local pkg
    pkg="$(_pkg_path)"

    # Inspect only rule-header lines (# ID — Title); bodies never start that way.
    run grep -E '^# [A-Z]+-[0-9]+ ' "${pkg}"
    assert_success
    assert_line --partial "UNIT-002"     # class-structure
    assert_line --partial "DESIGN-004"   # class-bodies
    refute_line --partial "CONV-001"     # method — outside the requested set
}

@test "build_rule_package groups line reflects only the rendered groups" {
    # A structural scope drops the provider group (no provider rule is
    # class-structure/class-bodies), so the reported groups must narrow — proving
    # the line tracks the rendered subset rather than a hardcoded five-group list.
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"review_unit":"class-structure,class-bodies"}'
    assert_success
    assert_line "groups: convention,design,unit,isolation"
    refute_line "groups: convention,design,unit,isolation,provider"
}

@test "build_rule_package test_category + scoped_review render a byte-faithful subset" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"test_category":"B","scoped_review":true}'
    assert_success
    local pkg actual expected
    pkg="$(_pkg_path)"
    actual="$(cat "${pkg}")"
    expected="$(_scoped_render "B" "true" "")"
    assert_equal "${actual}" "${expected}"
}

@test "build_rule_package scoped_review=true drops scoped-review=exclude rules" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"scoped_review":true}'
    assert_success
    local pkg
    pkg="$(_pkg_path)"

    run grep -E '^# [A-Z]+-[0-9]+ ' "${pkg}"
    assert_success
    refute_line --partial "UNIT-002"     # scoped-review=exclude
    refute_line --partial "CONV-005"     # scoped-review=exclude
    assert_line --partial "CONV-001"     # scoped-review=include — kept
}

@test "build_rule_package writes a scoped package under a scope-derived filename" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"review_unit":"method"}'
    assert_success
    local pkg
    pkg="$(_pkg_path)"
    assert_equal "$(basename "${pkg}")" "unit-review-ru-method.md"
    assert [ -f "${pkg}" ]
}

@test "build_rule_package keeps the canonical unit-review.md name when unscoped" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{}'
    assert_success
    local pkg
    pkg="$(_pkg_path)"
    assert_equal "$(basename "${pkg}")" "unit-review.md"
}

@test "build_rule_package distinct scopes coexist as distinct files" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"review_unit":"method"}'
    assert_success
    run tool_build_rule_package '{"review_unit":"class-structure"}'
    assert_success
    # Both per-track packages plus an unscoped build survive side by side.
    run tool_build_rule_package '{}'
    assert_success

    local base="${CLAUDE_PLUGIN_DATA}/rule-packages"
    assert [ -f "${base}/unit-review-ru-method.md" ]
    assert [ -f "${base}/unit-review-ru-class-structure.md" ]
    assert [ -f "${base}/unit-review.md" ]
}

@test "build_rule_package fails hard when a scope matches no rule" {
    # A fixture index of only a method rule: a class-structure scope matches
    # nothing and must fail hard, never write an empty package.
    local fixture="${BATS_TEST_TMPDIR}/methodonly"
    write_rule "${fixture}" ONLY-001 method
    _build_rule_index "${fixture}"
    run tool_build_rule_package '{"review_unit":"class-structure"}'
    assert_failure
    assert_output --partial "rendered zero rules"
    assert_output --partial "matched nothing"
    assert [ ! -e "${CLAUDE_PLUGIN_DATA}/rule-packages/unit-review-ru-class-structure.md" ]
}

# ============================================================================
# §C3 Non-unit catalogs — group/test_type render a single group, byte-faithful
# to the matching get_rules selection (the unified team review composes one
# catalog per test type this way).
# ============================================================================

@test "build_rule_package group=integration is byte-identical to get_rules(group=integration, test_type=integration)" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"group":"integration","test_type":"integration"}'
    assert_success
    local pkg actual expected
    pkg="$(_pkg_path)"
    actual="$(cat "${pkg}")"
    expected="$(tool_get_rules '{"group":"integration","test_type":"integration"}')"
    assert_equal "${actual}" "${expected}"
}

@test "build_rule_package group=migration renders only migration rules" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"group":"migration","test_type":"migration"}'
    assert_success
    assert_line "groups: migration"
    local pkg
    pkg="$(_pkg_path)"

    run grep -E '^# [A-Z]+-[0-9]+ ' "${pkg}"
    assert_success
    assert_line --partial "MIGRATION-001"
    refute_line --partial "CONV-"
    refute_line --partial "INTEGRATION-"
    refute_line --partial "PLACEMENT-"
}

@test "build_rule_package group=placement renders the placement reasoning rules" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"group":"placement","test_type":"integration"}'
    assert_success
    assert_line "groups: placement"
    local pkg
    pkg="$(_pkg_path)"

    run grep -E '^# [A-Z]+-[0-9]+ ' "${pkg}"
    assert_success
    assert_line --partial "PLACEMENT-001"
    refute_line --partial "INTEGRATION-"
    refute_line --partial "CONV-"
}

@test "build_rule_package non-unit catalogs use group/test_type filenames that coexist with the unit catalog" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"group":"integration","test_type":"integration"}'
    assert_success
    local pkg
    pkg="$(_pkg_path)"
    assert_equal "$(basename "${pkg}")" "unit-review-grp-integration-tt-integration.md"

    run tool_build_rule_package '{"group":"migration","test_type":"migration"}'
    assert_success
    run tool_build_rule_package '{"group":"placement","test_type":"integration"}'
    assert_success
    run tool_build_rule_package '{}'
    assert_success

    local base="${CLAUDE_PLUGIN_DATA}/rule-packages"
    assert [ -f "${base}/unit-review-grp-integration-tt-integration.md" ]
    assert [ -f "${base}/unit-review-grp-migration-tt-migration.md" ]
    assert [ -f "${base}/unit-review-grp-placement-tt-integration.md" ]
    assert [ -f "${base}/unit-review.md" ]
}
