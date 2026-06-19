#!/usr/bin/env bats
# bats file_tags=test-writing,review-unit
# Tests for review-unit indexing, filtering, header exposure, and the fail-hard
# guard in the test-rules MCP server (lib/common.sh + lib/get.sh).
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
