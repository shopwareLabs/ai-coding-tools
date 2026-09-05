#!/usr/bin/env bats
# bats file_tags=test-writing,team-review,verify-finding-evidence
# Tests for verify-finding-evidence.sh — the merge/adversarial-stage gate that
# checks every kept finding's `current` block against the reviewed file's real
# content (whitespace-normalized substring containment) and demotes a finding
# that quotes code the file does not contain from its kept bucket into
# `contested`, rather than letting a fabricated quote reach the report.
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

setup() {
    WORKFLOW_DIR="${PLUGIN_DIR}/skills/phpunit-test-team-reviewing/workflow"
    SCRIPT="${WORKFLOW_DIR}/verify-finding-evidence.sh"
    REPO_DIR="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "${REPO_DIR}/tests/unit"
    # shellcheck source=/dev/null  # SCRIPT is derived from PLUGIN_DIR at runtime
    source "${SCRIPT}"

    _write_bar_test_file
}

# The fixture file every test's finding is checked against: a real test
# method containing one real assertion.
_write_bar_test_file() {
    {
        echo "<?php"
        echo "class BarTest extends TestCase {"
        echo "    public function testReal(): void {"
        echo "        \$x = 1;"
        echo "        static::assertSame(1, \$x);"
        echo "    }"
        echo "}"
    } > "${REPO_DIR}/tests/unit/BarTest.php"
}

# Write a one-file result JSON with a single finding of the given `current`
# in the given kept bucket (errors|warnings|informational).
_write_result() {
    local path="$1" bucket="$2" current="$3"
    jq -n --arg bucket "${bucket}" --arg current "${current}" \
        '{files: [{path: "tests/unit/BarTest.php",
                   errors: [], warnings: [], informational: [], contested: []}
                  | .[$bucket] = [{finding_id: "CONV-001|testReal", rule_id: "CONV-001", current: $current}]]}' \
        > "${path}"
}

# ============================================================================
# Happy path — a finding whose `current` is a real substring of the file is
# left in place; a finding with empty `current` is exempt from the check.
# ============================================================================

@test "keeps a finding whose current matches the file exactly" {
    # shellcheck disable=SC2016  # the literal $x is PHP code under test, not a shell expansion
    _write_result "${BATS_TEST_TMPDIR}/result.json" errors 'static::assertSame(1, $x);'

    run --separate-stderr verify_finding_evidence "${BATS_TEST_TMPDIR}/result.json" "${REPO_DIR}"
    assert_success
    assert_equal "${stderr}" ""

    run jq -c '.files[0] | {errors: (.errors | length), contested: (.contested | length)}' <<< "${output}"
    assert_output '{"errors":1,"contested":0}'
}

@test "exempts a finding with empty current from the check" {
    jq -n '{files: [{path: "tests/unit/BarTest.php",
                      errors: [{finding_id: "TEAM-SPLIT|class-level", rule_id: "TEAM-SPLIT", current: ""}],
                      warnings: [], informational: [], contested: []}]}' > "${BATS_TEST_TMPDIR}/result.json"

    run --separate-stderr verify_finding_evidence "${BATS_TEST_TMPDIR}/result.json" "${REPO_DIR}"
    assert_success
    assert_equal "${stderr}" ""

    run jq -c '.files[0] | {errors: (.errors | length), contested: (.contested | length)}' <<< "${output}"
    assert_output '{"errors":1,"contested":0}'
}

# ============================================================================
# Whitespace normalization — a quote reformatted with different indentation
# or line breaks still passes, since both sides collapse whitespace runs to
# a single space before the containment check.
# ============================================================================

@test "matches under whitespace normalization despite different indentation" {
    # shellcheck disable=SC2016  # the literal $x is PHP code under test, not a shell expansion
    _write_result "${BATS_TEST_TMPDIR}/result.json" errors "$(printf 'static::assertSame(1,\n      $x);')"

    run --separate-stderr verify_finding_evidence "${BATS_TEST_TMPDIR}/result.json" "${REPO_DIR}"
    assert_success
    assert_equal "${stderr}" ""

    run jq -c '.files[0] | {errors: (.errors | length), contested: (.contested | length)}' <<< "${output}"
    assert_output '{"errors":1,"contested":0}'
}

# ============================================================================
# Demotion — a fabricated quote (code the file does not contain) is moved
# from its kept bucket into `contested`, tagged with an `outcome` reason, and
# logged to stderr.
# ============================================================================

@test "demotes a fabricated quote into contested with an outcome and a log line" {
    # shellcheck disable=SC2016  # the literal $doesNotExist is PHP code under test, not a shell expansion
    _write_result "${BATS_TEST_TMPDIR}/result.json" errors 'static::assertSame(999, $doesNotExist);'

    run --separate-stderr verify_finding_evidence "${BATS_TEST_TMPDIR}/result.json" "${REPO_DIR}"
    assert_success
    assert_equal "${stderr}" "verify-finding-evidence: demoted CONV-001|testReal in tests/unit/BarTest.php: current block not found under whitespace normalization"

    run jq -c '.files[0] | {errors: (.errors | length), contested}' <<< "${output}"
    assert_output --partial '"errors":0'
    assert_output --partial '"finding_id":"CONV-001|testReal"'
    assert_output --partial '"outcome":"evidence check: current block not found in tests/unit/BarTest.php under whitespace normalization"'
}

@test "syncs a demotion into adversarial_input, moving it from kept to contested there too" {
    jq -n '{files: [{path: "tests/unit/BarTest.php",
                      errors: [{finding_id: "CONV-001|testReal", rule_id: "CONV-001", current: "static::assertSame(999, $doesNotExist);"}],
                      warnings: [], informational: [], contested: [],
                      adversarial_input: {
                        kept: [{finding_id: "CONV-001|testReal", rule_id: "CONV-001", current: "static::assertSame(999, $doesNotExist);"}],
                        contested: []
                      }}]}' > "${BATS_TEST_TMPDIR}/result.json"

    run --separate-stderr verify_finding_evidence "${BATS_TEST_TMPDIR}/result.json" "${REPO_DIR}"
    assert_success
    assert_equal "${stderr}" "verify-finding-evidence: demoted CONV-001|testReal in tests/unit/BarTest.php: current block not found under whitespace normalization"

    run jq -c '.files[0].adversarial_input | {kept: (.kept | length), contested}' <<< "${output}"
    assert_output --partial '"kept":0'
    assert_output --partial '"finding_id":"CONV-001|testReal"'
    assert_output --partial '"outcome":"evidence check: current block not found in tests/unit/BarTest.php under whitespace normalization"'
}

# ============================================================================
# Per-entry shape validation — a bucket that is not an array (e.g. `errors: {}`)
# is a corrupted result, not zero candidates to skip past: it must fail hard
# and name the entry and the offending field, never silently pass through as
# a clean review.
# ============================================================================

@test "fails hard when errors is an object instead of an array, rather than silently passing through" {
    jq -n '{files: [{path: "tests/unit/BarTest.php", errors: {}, warnings: [], informational: [], contested: []}]}' \
        > "${BATS_TEST_TMPDIR}/result.json"

    run verify_finding_evidence "${BATS_TEST_TMPDIR}/result.json" "${REPO_DIR}"
    assert_failure
    assert_output --partial "entry 0"
    assert_output --partial "tests/unit/BarTest.php"
    assert_output --partial "errors is not an array"
}

@test "demotes from the warnings bucket the same way as errors" {
    _write_result "${BATS_TEST_TMPDIR}/result.json" warnings 'this code does not exist anywhere'

    run --separate-stderr verify_finding_evidence "${BATS_TEST_TMPDIR}/result.json" "${REPO_DIR}"
    assert_success

    run jq -c '.files[0] | {warnings: (.warnings | length), contested: (.contested | length)}' <<< "${output}"
    assert_output '{"warnings":0,"contested":1}'
}

# ============================================================================
# Hard failures — a target file that does not exist, or invalid result JSON,
# both abort with a non-zero exit and a clear message; never a silent skip.
# ============================================================================

@test "fails hard when the referenced file does not exist on disk" {
    jq -n '{files: [{path: "tests/unit/NoSuch.php",
                      errors: [{finding_id: "CONV-001|testX", rule_id: "CONV-001", current: "something"}],
                      warnings: [], informational: [], contested: []}]}' > "${BATS_TEST_TMPDIR}/result.json"

    run verify_finding_evidence "${BATS_TEST_TMPDIR}/result.json" "${REPO_DIR}"
    assert_failure
    assert_output --partial "target file not found"
}

@test "fails hard on invalid result JSON" {
    printf '%s\n' '{bad json' > "${BATS_TEST_TMPDIR}/result.json"

    run verify_finding_evidence "${BATS_TEST_TMPDIR}/result.json" "${REPO_DIR}"
    assert_failure
    assert_output --partial "not valid JSON"
}

@test "fails hard when the result has no top-level files array" {
    printf '%s\n' '{}' > "${BATS_TEST_TMPDIR}/result.json"

    run verify_finding_evidence "${BATS_TEST_TMPDIR}/result.json" "${REPO_DIR}"
    assert_failure
    assert_output --partial "no top-level"
}
