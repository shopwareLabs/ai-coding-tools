#!/usr/bin/env bats
# bats file_tags=test-writing,build-rule-package
# Tests for the build_rule_package tool of the test-rules MCP server
# (lib/build.sh + the shared lib/common.sh:_render_rules renderer): byte-fidelity
# against get_rules, fail-hard guards, per-track scoping, composed per-type
# catalogs, and atomic write.
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
# §7.1 Byte-fidelity golden — package == the matching composed get_rules call
# ============================================================================

@test "build_rule_package with no arguments is byte-identical to get_rules(test_type=unit)" {
    # A bare call renders the composed unit catalog. Both tools compose the same
    # selection and render through _render_rules; this pins it so a future
    # divergence in either path fails loudly.
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package
    assert_success

    local pkg
    pkg="$(_pkg_path)"
    assert [ -f "${pkg}" ]

    local actual expected
    actual="$(cat "${pkg}")"
    expected="$(tool_get_rules '{"test_type":"unit"}')"
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
# §C3 Composed per-type catalogs — a `test_type` without a `group` composes that
# type's own group with every convention/design/isolation/provider rule whose
# test-types declares the type. The unified team review builds one catalog per
# test type this way, and the reviewing skills load it in place of their own
# group alone.
# ============================================================================

# Render the composed catalog for a test type group by group, through the same
# _filter_rules / _render_rules the tool uses but WITHOUT the composition helper
# under test — the independent expectation for byte-fidelity.
# Args: $1=test_type, $2=scoped_review ("true"/empty), $3=review_unit (empty=no
#       filter; may be comma-separated).
_composed_render() {
    local tt="$1" scoped="$2" ru="$3"
    local -a want=()
    local g id
    for g in convention design "${tt}" isolation provider; do
        while IFS= read -r id; do
            [[ -n "${id}" ]] && want+=("${id}")
        done < <(_filter_rules "${g}" "${tt}" "" "" "" "${scoped}" "${ru}")
    done
    _render_rules "${want[@]}"
}

# Sorted rule IDs of one prefix present in a rendered package, read off the
# per-rule header lines (`# <ID> — <Title>`); bodies never start that way.
# Args: $1=package file, $2=rule-ID prefix (e.g. CONV)
_catalog_ids() {
    awk -v P="$2" '$0 ~ "^# " P "-[0-9]+ " { print $2 }' "$1" | LC_ALL=C sort
}

@test "build_rule_package test_type=integration is byte-identical to get_rules(test_type=integration)" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"test_type":"integration"}'
    assert_success
    local pkg actual expected
    pkg="$(_pkg_path)"
    actual="$(cat "${pkg}")"
    expected="$(tool_get_rules '{"test_type":"integration"}')"
    assert_equal "${actual}" "${expected}"
}

@test "build_rule_package test_type=integration renders the group-by-group composition" {
    # Independent of the tool's composition helper: had build.sh composed the
    # wrong group set or dropped the test-types filter, the bytes would diverge.
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"test_type":"integration"}'
    assert_success
    assert_line "groups: convention,design,integration,isolation,provider"
    local pkg actual expected
    pkg="$(_pkg_path)"
    actual="$(cat "${pkg}")"
    expected="$(_composed_render integration "" "")"
    assert_equal "${actual}" "${expected}"
}

@test "build_rule_package test_type=integration excludes the rules that do not declare integration" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"test_type":"integration"}'
    assert_success
    local pkg
    pkg="$(_pkg_path)"

    run grep -E '^# [A-Z]+-[0-9]+ ' "${pkg}"
    assert_success
    assert_line --partial "INTEGRATION-001"
    refute_line --partial "UNIT-"          # the unit group is not composed here
    refute_line --partial "MIGRATION-"     # the other type's own group
    refute_line --partial "PLACEMENT-"     # loaded only by the migrating skill
    refute_line --partial "DESIGN-010"     # test-types: unit
    refute_line --partial "ISOLATION-005"  # test-types: unit
}

@test "build_rule_package test_type=migration composes the migration group with every convention rule" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"test_type":"migration"}'
    assert_success
    assert_line "groups: convention,design,migration,isolation,provider"
    local pkg
    pkg="$(_pkg_path)"

    # Every convention rule declares test-types: all, so the composed migration
    # catalog carries all seventeen — named, so a rule that silently stops
    # reaching migration tests fails here rather than passing under a count.
    assert_equal "$(_catalog_ids "${pkg}" CONV)" "$(printf '%s\n' \
        CONV-001 CONV-002 CONV-003 CONV-004 CONV-005 CONV-006 CONV-007 CONV-008 \
        CONV-009 CONV-010 CONV-011 CONV-012 CONV-013 CONV-014 CONV-015 CONV-016 \
        CONV-017)"

    run grep -E '^# [A-Z]+-[0-9]+ ' "${pkg}"
    assert_success
    assert_line --partial "MIGRATION-001"
    assert_line --partial "MIGRATION-008"
    refute_line --partial "UNIT-"
    refute_line --partial "INTEGRATION-"
    refute_line --partial "PLACEMENT-"
    refute_line --partial "DESIGN-010"
    refute_line --partial "ISOLATION-005"
}

@test "build_rule_package group=placement still renders the single placement group" {
    # The integration-to-unit migrating skill is the one consumer left on the
    # single-group path; composition never pulls placement into a catalog.
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

@test "build_rule_package composed catalogs use test_type filenames that coexist with the unit catalog" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"test_type":"integration"}'
    assert_success
    local pkg
    pkg="$(_pkg_path)"
    assert_equal "$(basename "${pkg}")" "unit-review-tt-integration.md"

    run tool_build_rule_package '{"test_type":"migration"}'
    assert_success
    run tool_build_rule_package '{"group":"placement","test_type":"integration"}'
    assert_success
    run tool_build_rule_package '{}'
    assert_success

    local base="${CLAUDE_PLUGIN_DATA}/rule-packages"
    assert [ -f "${base}/unit-review-tt-integration.md" ]
    assert [ -f "${base}/unit-review-tt-migration.md" ]
    assert [ -f "${base}/unit-review-grp-placement-tt-integration.md" ]
    assert [ -f "${base}/unit-review.md" ]

    # Distinct names must carry distinct catalogs: each type composes a
    # different rule set, so identical content means the test_type never
    # reached the composition.
    run diff -q "${base}/unit-review-tt-integration.md" "${base}/unit-review-tt-migration.md"
    assert_failure
    run diff -q "${base}/unit-review-tt-integration.md" "${base}/unit-review.md"
    assert_failure
}

# ============================================================================
# §C4 test-types is authoritative — composition reads the declared CSV, so a
# rule reaches exactly the types it lists.
# ============================================================================

# Write a rule fixture into an arbitrary group with an explicit test-types CSV.
# The shipped catalog carries no multi-type CSV today; this exercises the value
# the composition contract is written against.
# Args: $1=rules dir, $2=group, $3=rule id, $4=test-types CSV
_write_typed_rule() {
    local dir="$1" group="$2" id="$3" test_types="$4"
    mkdir -p "${dir}/${group}"
    {
        printf '%s\n' "---"
        printf 'id: %s\n' "${id}"
        printf 'title: %s fixture\n' "${id}"
        printf 'group: %s\n' "${group}"
        printf '%s\n' "enforce: must-fix"
        printf 'test-types: %s\n' "${test_types}"
        printf '%s\n' "test-categories: A"
        printf '%s\n' "scope: phpunit"
        printf '%s\n' "review-unit: method"
        printf '%s\n' "scoped-review: include"
        printf '%s\n' "---"
        printf '\n'
        printf '## %s\n' "${id}"
    } > "${dir}/${group}/${id}.md"
}

@test "build_rule_package composes a shared rule into every test type its test-types lists" {
    local fixture="${BATS_TEST_TMPDIR}/typedrules"
    _write_typed_rule "${fixture}" convention CONV-900 "unit,migration"
    _write_typed_rule "${fixture}" migration MIGRATION-900 "migration"
    _build_rule_index "${fixture}"

    run tool_build_rule_package '{"test_type":"migration"}'
    assert_success
    assert_line "groups: convention,migration"
    local pkg
    pkg="$(_pkg_path)"

    run grep -E '^# [A-Z]+-[0-9]+ ' "${pkg}"
    assert_success
    assert_line --partial "CONV-900"
    assert_line --partial "MIGRATION-900"
}

@test "build_rule_package omits a shared rule from a test type its test-types does not list" {
    local fixture="${BATS_TEST_TMPDIR}/typedrules"
    _write_typed_rule "${fixture}" convention CONV-900 "unit,migration"
    _write_typed_rule "${fixture}" integration INTEGRATION-900 "integration"
    _build_rule_index "${fixture}"

    run tool_build_rule_package '{"test_type":"integration"}'
    assert_success
    assert_line "groups: integration"
    local pkg
    pkg="$(_pkg_path)"

    run grep -E '^# [A-Z]+-[0-9]+ ' "${pkg}"
    assert_success
    assert_line --partial "INTEGRATION-900"
    refute_line --partial "CONV-900"
}

@test "build_rule_package refuses a test type it cannot compose a catalog for" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"test_type":"acceptance"}'
    assert_failure
    assert_output --partial "cannot compose a catalog for test_type=acceptance"
    assert [ ! -e "${CLAUDE_PLUGIN_DATA}/rule-packages/unit-review-tt-acceptance.md" ]
}

# ============================================================================
# §C5 scope / enforce filters — build_rule_package presents the same composed
# selection as get_rules under scope and enforce, matching its existing
# review_unit / test_category / scoped_review parity (spec: "build_rule_package
# and get_rules present the same selection under the same filters").
# ============================================================================

@test "build_rule_package test_type=unit scope=phpunit composed selection is byte-identical to get_rules" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"test_type":"unit","scope":"phpunit"}'
    assert_success
    local pkg actual expected
    pkg="$(_pkg_path)"
    actual="$(cat "${pkg}")"
    expected="$(tool_get_rules '{"test_type":"unit","scope":"phpunit"}')"
    assert_equal "${actual}" "${expected}"
}

@test "build_rule_package test_type=unit enforce=must-fix composed selection is byte-identical to get_rules" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"test_type":"unit","enforce":"must-fix"}'
    assert_success
    local pkg actual expected
    pkg="$(_pkg_path)"
    actual="$(cat "${pkg}")"
    expected="$(tool_get_rules '{"test_type":"unit","enforce":"must-fix"}')"
    assert_equal "${actual}" "${expected}"
}

@test "build_rule_package writes a scope-derived filename distinct from the unscoped composed catalog" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package '{"test_type":"unit","scope":"phpunit"}'
    assert_success
    local scoped_pkg
    scoped_pkg="$(_pkg_path)"
    assert_equal "$(basename "${scoped_pkg}")" "unit-review-tt-unit-scope-phpunit.md"

    run tool_build_rule_package '{"test_type":"unit"}'
    assert_success
    local unscoped_pkg
    unscoped_pkg="$(_pkg_path)"

    run diff -q "${scoped_pkg}" "${unscoped_pkg}"
    assert_failure
}

# ============================================================================
# §C6 get_rules composed-catalog empty result is a hard failure, matching
# build_rule_package's zero-rules guard. A non-composed (explicit group) empty
# result is unaffected — it stays a success reporting "No rules match...".
# ============================================================================

@test "get_rules composed catalog matching zero rules fails hard, naming test_type and filters" {
    local fixture="${BATS_TEST_TMPDIR}/composedempty"
    _write_typed_rule "${fixture}" migration MIGRATION-900 "migration"
    _build_rule_index "${fixture}"

    run tool_get_rules '{"test_type":"unit"}'
    assert_failure
    assert_output --partial "composed catalog for test_type=unit"
    assert_output --partial "matched zero rules"
}

@test "get_rules non-composed explicit-group filter matching zero rules still succeeds with No rules match" {
    _build_rule_index "${RULES_DIR}"
    run tool_get_rules '{"group":"convention","test_category":"Z"}'
    assert_success
    assert_output --partial "No rules match"
}
