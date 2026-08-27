#!/usr/bin/env bats
# bats file_tags=test-writing,review-unit,scoped-review
# Tests for review-unit and scoped-review classification: indexing, filtering,
# header exposure, and the fail-hard guard in the test-rules MCP server
# (lib/common.sh + lib/get.sh).
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

setup() {
    # Capture the server's log output so fail-hard tests can assert the message.
    MCP_LOG_FILE="${BATS_TEST_TMPDIR}/mcp.log"
    export MCP_LOG_FILE
    log() { printf '[%s] %s\n' "$1" "$2" >> "${MCP_LOG_FILE}"; }
    source "${TEST_RULES_LIB_DIR}/common.sh"
    source "${TEST_RULES_LIB_DIR}/get.sh"
}

# ============================================================================
# _build_rule_index — review-unit parsing (against the real rule set)
# ============================================================================

_assert_indexed_review_unit() {
    local id="$1" expected="$2"
    _build_rule_index "${RULES_DIR}"
    assert_equal "${RULE_REVIEW_UNIT[${id}]}" "${expected}"
}

@test "_build_rule_index parses a class-structure rule" {
    _assert_indexed_review_unit UNIT-002 class-structure
}

@test "_build_rule_index parses a class-bodies rule" {
    _assert_indexed_review_unit DESIGN-004 class-bodies
}

@test "_build_rule_index parses a method rule" {
    _assert_indexed_review_unit CONV-001 method
}

@test "_build_rule_index succeeds on the real rule set" {
    # Guards that no shipped rule has a missing/invalid review-unit that would
    # abort server startup. Fails loudly the day a new rule omits the field.
    run _build_rule_index "${RULES_DIR}"
    assert_success
}

@test "_build_rule_index trims trailing whitespace on review-unit" {
    # The server must trim like the CI gate; otherwise a stray space bricks startup
    # while the validator stays green.
    local fixture="${BATS_TEST_TMPDIR}/rules"
    write_rule "${fixture}" GOOD-002 "method   "
    _build_rule_index "${fixture}"
    assert_equal "${RULE_REVIEW_UNIT[GOOD-002]}" "method"
}

@test "_build_rule_index ignores a review-unit-like line in the rule body" {
    # A body line beginning review-unit: must not be read as the field value.
    local fixture="${BATS_TEST_TMPDIR}/rules"
    write_rule "${fixture}" GOOD-003 method
    printf '\nreview-unit: whole-class is not a real value\n' >> "${fixture}/unit/GOOD-003.md"
    _build_rule_index "${fixture}"
    assert_equal "${RULE_REVIEW_UNIT[GOOD-003]}" "method"
}

# ============================================================================
# review_unit filter (_filter_rules — against the real rule set)
# ============================================================================

@test "review_unit filter includes rules of that unit" {
    _build_rule_index "${RULES_DIR}"
    run _filter_rules "" "" "" "" "" "" "class-bodies"
    assert_success
    assert_line "DESIGN-004"
    assert_line "ISOLATION-001"
}

@test "review_unit filter excludes other units by exact match" {
    _build_rule_index "${RULES_DIR}"
    run _filter_rules "" "" "" "" "" "" "class-bodies"
    assert_success
    refute_line "CONV-001"    # method
    refute_line "UNIT-002"    # class-structure (proves exact match, not prefix)
}

@test "review_unit filter composes with group filter" {
    _build_rule_index "${RULES_DIR}"
    run _filter_rules "convention" "" "" "" "" "" "class-structure"
    assert_success
    assert_line "CONV-005"
    refute_line "UNIT-002"    # class-structure but not in the convention group
}

# ============================================================================
# get_rules — header exposure and filter threading (lib/get.sh)
# ============================================================================

@test "get_rules exposes review-unit in the per-rule metadata header" {
    _build_rule_index "${RULES_DIR}"
    run tool_get_rules '{"ids":"UNIT-002"}'
    assert_success
    assert_output --partial "Review unit: class-structure"
}

@test "get_rules threads the review_unit filter through to results" {
    # Guards the get.sh wiring: dropping the filter arg would return every rule,
    # so a method/class-structure header would appear.
    _build_rule_index "${RULES_DIR}"
    run tool_get_rules '{"review_unit":"class-bodies"}'
    assert_success
    assert_output --partial "DESIGN-004"
    assert_output --partial "Review unit: class-bodies"
    refute_output --partial "Review unit: method"
    refute_output --partial "Review unit: class-structure"
}

@test "get_rules treats review_unit alone as a filter, not a missing-filter error" {
    _build_rule_index "${RULES_DIR}"
    run tool_get_rules '{"review_unit":"method"}'
    assert_success
    refute_output --partial "provide either ids"
}

@test "get_rules with ids of CONV-* reports CONV-* as not found rather than matching filenames (regression: glob-expansion of caller ids)" {
    # Regression guard for a real defect: the comma-splitting loop in get.sh
    # once iterated `ids_raw` unquoted, so a caller-supplied id containing a
    # glob character was pathname-expanded against the process working
    # directory instead of staying literal. The arrange has to manufacture that
    # hazard: the server's cwd is the user's project root, which is exactly
    # where files named after a rule id could sit, and a bats test's cwd is the
    # repo root, where nothing matches CONV-* — so without the decoys the glob
    # has nothing to expand to and the test passes against the unfixed code.
    # bats runs each @test in its own subshell, so this cd does not leak.
    local hazard="${BATS_TEST_TMPDIR}/project-root"
    mkdir -p "${hazard}"
    : > "${hazard}/CONV-decoy-one.md"
    : > "${hazard}/CONV-decoy-two.md"
    cd "${hazard}"

    _build_rule_index "${RULES_DIR}"
    run tool_get_rules '{"ids":"CONV-*,CONV-001"}'
    assert_success
    # The literal id round-tripping into "Not found:" is the proof it was never
    # expanded; the decoy names are what it would have expanded to.
    assert_output --partial "Not found: CONV-*"
    refute_output --partial "CONV-decoy"
    # The positive half: a real id in the same call still resolves, pinning the
    # fix as "treat the id literally", not "nothing matches any more".
    assert_output --partial "# CONV-001 "
}

@test "get_rules leaves the caller's globbing setting as it found it" {
    # The id loop disables pathname expansion. A bare `set +f` to undo it would
    # force globbing back ON rather than restore it, silently re-enabling it for
    # a caller that had deliberately turned it off. Today every production call
    # site is a command substitution, so such a leak would die with the
    # subshell — which is a property of the call sites, not of this function.
    # Called directly rather than through `run` for the same reason: `run` is a
    # subshell, and the leak would not be observable through it.
    _build_rule_index "${RULES_DIR}"

    local noglob_after
    set -f
    tool_get_rules '{"ids":"CONV-001"}' > /dev/null
    noglob_after=$(shopt -qo noglob && printf 'on' || printf 'off')
    set +f

    assert_equal "${noglob_after}" "on"
}

# ============================================================================
# Fail-hard guard — a missing/invalid review-unit errors, never silently drops
# ============================================================================

@test "_build_rule_index fails and logs the offender when a rule is missing review-unit" {
    local fixture="${BATS_TEST_TMPDIR}/rules"
    write_rule "${fixture}" GOOD-001 method
    write_rule "${fixture}" BAD-001
    run _build_rule_index "${fixture}"
    assert_failure
    run cat "${MCP_LOG_FILE}"
    assert_output --partial "BAD-001"
    assert_output --partial "review-unit=''"
}

@test "_build_rule_index fails and logs the bad value when review-unit is invalid" {
    local fixture="${BATS_TEST_TMPDIR}/rules"
    write_rule "${fixture}" GOOD-001 method
    write_rule "${fixture}" BAD-001 whole-class
    run _build_rule_index "${fixture}"
    assert_failure
    run cat "${MCP_LOG_FILE}"
    assert_output --partial "review-unit='whole-class'"
}

@test "a rule missing review-unit is not indexed as an empty value" {
    local fixture="${BATS_TEST_TMPDIR}/rules"
    write_rule "${fixture}" GOOD-001 method
    write_rule "${fixture}" BAD-001
    _build_rule_index "${fixture}" || true
    # BAD-001 must be absent from the index, not present with an empty value.
    assert_equal "${RULE_REVIEW_UNIT[BAD-001]+present}" ""
}

# ============================================================================
# _build_rule_index — scoped-review parsing (against the real rule set)
# ============================================================================

_assert_indexed_scoped_review() {
    local id="$1" expected="$2"
    _build_rule_index "${RULES_DIR}"
    assert_equal "${RULE_SCOPED_REVIEW[${id}]}" "${expected}"
}

@test "_build_rule_index parses a scoped-review=exclude rule" {
    _assert_indexed_scoped_review UNIT-002 exclude
}

@test "_build_rule_index parses a scoped-review=include rule" {
    _assert_indexed_scoped_review CONV-001 include
}

@test "_build_rule_index trims trailing whitespace on scoped-review" {
    # The server must trim like the CI gate; a stray space must not brick startup.
    local fixture="${BATS_TEST_TMPDIR}/rules"
    write_rule "${fixture}" GOOD-010 method "include   "
    _build_rule_index "${fixture}"
    assert_equal "${RULE_SCOPED_REVIEW[GOOD-010]}" "include"
}

# ============================================================================
# scoped_review filter — behavior-equivalence with the retired class-scope-only
# ============================================================================

@test "scoped_review=true excludes exactly the retired class-scope-only set" {
    # Locks in "no behavior change": the IDs dropped from a scoped review must be
    # the retired class-scope-only=true set — no more, no fewer. Pin the exact set
    # difference (full minus scoped) rather than the 4 known absences, so a
    # regression that ENLARGES the exclude set (a stray include->exclude, or a new
    # rule shipping exclude) fails here even though the 4 known IDs stay absent.
    _build_rule_index "${RULES_DIR}"
    local scoped full excluded
    scoped="$(_filter_rules "" "" "" "" "" "true" "" | sort)"
    full="$(_filter_rules "" "" "" "" "" "" "" | sort)"
    excluded="$(comm -23 <(printf '%s\n' "${full}") <(printf '%s\n' "${scoped}"))"
    assert_equal "${excluded}" "$(printf 'CONV-005\nCONV-007\nINTEGRATION-008\nUNIT-002')"
}

@test "scoped_review=true keeps scoped-review=include rules in the result" {
    _build_rule_index "${RULES_DIR}"
    run _filter_rules "" "" "" "" "" "true" ""
    assert_success
    assert_line "CONV-001"
    assert_line "DESIGN-004"
    assert_line "ISOLATION-001"
}

@test "scoped_review omitted keeps the excluded-set rules in the result" {
    _build_rule_index "${RULES_DIR}"
    run _filter_rules "" "" "" "" "" "" ""
    assert_success
    assert_line "CONV-005"
    assert_line "UNIT-002"
}

# ============================================================================
# get_rules — scoped-review header exposure (lib/get.sh)
# ============================================================================

@test "get_rules exposes scoped-review=exclude in the per-rule metadata header" {
    _build_rule_index "${RULES_DIR}"
    run tool_get_rules '{"ids":"UNIT-002"}'
    assert_success
    assert_output --partial "Scoped review: exclude"
}

@test "get_rules exposes scoped-review=include in the per-rule metadata header" {
    _build_rule_index "${RULES_DIR}"
    run tool_get_rules '{"ids":"CONV-001"}'
    assert_success
    assert_output --partial "Scoped review: include"
}

# ============================================================================
# Fail-hard guard — a missing/invalid scoped-review errors, never silently drops
# ============================================================================

@test "_build_rule_index fails and logs the offender when a rule is missing scoped-review" {
    local fixture="${BATS_TEST_TMPDIR}/rules"
    write_rule "${fixture}" GOOD-001 method
    write_rule "${fixture}" BAD-002 method ""
    run _build_rule_index "${fixture}"
    assert_failure
    run cat "${MCP_LOG_FILE}"
    assert_output --partial "BAD-002"
    assert_output --partial "scoped-review=''"
}

@test "_build_rule_index fails and logs the bad value when scoped-review is invalid" {
    local fixture="${BATS_TEST_TMPDIR}/rules"
    write_rule "${fixture}" GOOD-001 method
    write_rule "${fixture}" BAD-002 method "whole-class"
    run _build_rule_index "${fixture}"
    assert_failure
    run cat "${MCP_LOG_FILE}"
    assert_output --partial "scoped-review='whole-class'"
}

@test "a rule missing scoped-review is not indexed as an empty value" {
    local fixture="${BATS_TEST_TMPDIR}/rules"
    write_rule "${fixture}" GOOD-001 method
    write_rule "${fixture}" BAD-002 method ""
    _build_rule_index "${fixture}" || true
    # BAD-002 must be absent from the index, not present with an empty value.
    assert_equal "${RULE_SCOPED_REVIEW[BAD-002]+present}" ""
}
