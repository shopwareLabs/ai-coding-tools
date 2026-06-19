#!/usr/bin/env bats
# bats file_tags=test-writing,review-unit,validator
# Tests for the CI gate .github/scripts/validate-review-unit.sh against fixture
# rule trees (RULES_DIR override), covering the pass, missing, invalid, and
# fatal paths and their messages/exit codes.
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

@test "validator passes when every rule declares a valid review-unit" {
    local fixture="${BATS_TEST_TMPDIR}/rules"
    write_rule "${fixture}" CONV-100 method
    write_rule "${fixture}" DESIGN-100 class-bodies
    RULES_DIR="${fixture}" run bash "${REVIEW_UNIT_VALIDATOR}"
    assert_success
    assert_output --partial "valid review-unit"
}

@test "validator fails with a message when a rule is missing review-unit" {
    local fixture="${BATS_TEST_TMPDIR}/rules"
    write_rule "${fixture}" CONV-100 method
    write_rule "${fixture}" BAD-100
    RULES_DIR="${fixture}" run bash "${REVIEW_UNIT_VALIDATOR}"
    assert_failure 1
    assert_output --partial "BAD-100"
    assert_output --partial "missing required"
}

@test "validator fails with a message when a rule has an invalid review-unit" {
    local fixture="${BATS_TEST_TMPDIR}/rules"
    write_rule "${fixture}" CONV-100 method
    write_rule "${fixture}" BAD-100 whole-class
    RULES_DIR="${fixture}" run bash "${REVIEW_UNIT_VALIDATOR}"
    assert_failure 1
    assert_output --partial "BAD-100"
    assert_output --partial "invalid review-unit"
}

@test "validator trims trailing whitespace and treats it as valid" {
    local fixture="${BATS_TEST_TMPDIR}/rules"
    write_rule "${fixture}" CONV-100 "method   "
    RULES_DIR="${fixture}" run bash "${REVIEW_UNIT_VALIDATOR}"
    assert_success
}

@test "validator exits fatally when the rules directory is absent" {
    RULES_DIR="${BATS_TEST_TMPDIR}/does-not-exist" run bash "${REVIEW_UNIT_VALIDATOR}"
    assert_failure 2
    assert_output --partial "Rules directory not found"
}
