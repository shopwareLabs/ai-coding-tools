#!/usr/bin/env bats
# bats file_tags=test-writing,team-review,verify-method-counts
# Tests for verify-method-counts.sh — the Phase-1 manifest gate that
# deterministically re-counts each entry's test methods from disk before the
# manifest freezes, replacing a subagent-reported mismatch with the extracted
# truth rather than merely warning about it.
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

setup() {
    WORKFLOW_DIR="${PLUGIN_DIR}/skills/phpunit-test-team-reviewing/workflow"
    SCRIPT="${WORKFLOW_DIR}/verify-method-counts.sh"
    REPO_DIR="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "${REPO_DIR}/tests/unit"
    # shellcheck source=/dev/null  # SCRIPT is derived from PLUGIN_DIR at runtime
    source "${SCRIPT}"
}

# Write a minimal test-class fixture with the given (bare) test method names.
_write_test_class() {
    local path="$1"
    shift
    {
        echo "<?php"
        echo "class Fixture extends TestCase {"
        local name
        for name in "$@"; do
            echo "    public function ${name}(): void {}"
        done
        echo "}"
    } > "${path}"
}

_write_manifest() {
    local path="$1" test_file="$2" method_count="$3" methods_json="$4"
    jq -n --arg path "${test_file}" --argjson count "${method_count}" --argjson methods "${methods_json}" \
        '[{path: $path, method_count: $count, test_methods: $methods}]' > "${path}"
}

# ============================================================================
# Happy path — the manifest already matches the extracted truth: no change,
# no stderr log line.
# ============================================================================

@test "leaves a matching entry unchanged and logs nothing" {
    _write_test_class "${REPO_DIR}/tests/unit/FooTest.php" testAlpha testBeta testGamma
    _write_manifest "${BATS_TEST_TMPDIR}/manifest.json" "tests/unit/FooTest.php" 3 '["testAlpha","testBeta","testGamma"]'

    run --separate-stderr verify_method_counts "${BATS_TEST_TMPDIR}/manifest.json" "${REPO_DIR}"
    assert_success
    assert_equal "${stderr}" ""

    run jq -c '.[0] | {method_count, test_methods}' <<< "${output}"
    assert_output '{"method_count":3,"test_methods":["testAlpha","testBeta","testGamma"]}'
}

# ============================================================================
# Mismatch — a subagent under- or over-counted; the script replaces both
# fields with the extracted truth and logs exactly one line naming the file,
# the old count, and the new count.
# ============================================================================

@test "corrects a mismatched entry, logs one line, and writes the extracted truth" {
    _write_test_class "${REPO_DIR}/tests/unit/FooTest.php" testAlpha testBeta testGamma
    _write_manifest "${BATS_TEST_TMPDIR}/manifest.json" "tests/unit/FooTest.php" 2 '["testAlpha","testBeta"]'

    run --separate-stderr verify_method_counts "${BATS_TEST_TMPDIR}/manifest.json" "${REPO_DIR}"
    assert_success
    assert_equal "${stderr}" "verify-method-counts: tests/unit/FooTest.php: method_count 2 -> 3"

    run jq -c '.[0] | {method_count, test_methods}' <<< "${output}"
    assert_output '{"method_count":3,"test_methods":["testAlpha","testBeta","testGamma"]}'
}

# ============================================================================
# Hard failures — a missing entry file, or invalid manifest JSON, both abort
# with a non-zero exit and a clear message; never a silent skip.
# ============================================================================

@test "fails hard when an entry's file cannot be read, rather than reporting a false zero count" {
    _write_test_class "${REPO_DIR}/tests/unit/FooTest.php" testAlpha testBeta
    chmod 000 "${REPO_DIR}/tests/unit/FooTest.php"
    if [[ -r "${REPO_DIR}/tests/unit/FooTest.php" ]]; then
        skip "running as a user that bypasses file permissions (e.g. root) — chmod 000 did not deny read"
    fi
    _write_manifest "${BATS_TEST_TMPDIR}/manifest.json" "tests/unit/FooTest.php" 2 '["testAlpha","testBeta"]'

    run verify_method_counts "${BATS_TEST_TMPDIR}/manifest.json" "${REPO_DIR}"
    assert_failure
    assert_output --partial "grep failed reading"

    chmod 644 "${REPO_DIR}/tests/unit/FooTest.php"
}

@test "fails hard when an entry's file does not exist on disk" {
    _write_manifest "${BATS_TEST_TMPDIR}/manifest.json" "tests/unit/NoSuchTest.php" 1 '["testX"]'

    run verify_method_counts "${BATS_TEST_TMPDIR}/manifest.json" "${REPO_DIR}"
    assert_failure
    assert_output --partial "entry file not found"
}

@test "fails hard on invalid manifest JSON" {
    printf '%s\n' '{bad json' > "${BATS_TEST_TMPDIR}/manifest.json"

    run verify_method_counts "${BATS_TEST_TMPDIR}/manifest.json" "${REPO_DIR}"
    assert_failure
    assert_output --partial "not valid JSON"
}

@test "fails hard when the manifest top level is not an array" {
    printf '%s\n' '{}' > "${BATS_TEST_TMPDIR}/manifest.json"

    run verify_method_counts "${BATS_TEST_TMPDIR}/manifest.json" "${REPO_DIR}"
    assert_failure
    assert_output --partial "not an array"
}

# ============================================================================
# Order-sensitivity — a reordered-but-identical-set test_methods list is still
# a mismatch: the extracted file-order list is the truth, not merely the set.
# ============================================================================

# ============================================================================
# Per-entry shape validation — a wrongly-typed field (method_count as a
# string, test_methods as an object) is a corrupted manifest, not a mismatch
# to "correct": it must fail hard and name the entry and the offending field,
# never silently pass through with method_count 0.
# ============================================================================

@test "fails hard when method_count is a string and test_methods is an object, rather than silently correcting" {
    _write_test_class "${REPO_DIR}/tests/unit/FooTest.php" testAlpha testBeta testGamma
    jq -n '[{path: "tests/unit/FooTest.php", method_count: "three", test_methods: {}}]' > "${BATS_TEST_TMPDIR}/manifest.json"

    run verify_method_counts "${BATS_TEST_TMPDIR}/manifest.json" "${REPO_DIR}"
    assert_failure
    assert_output --partial "entry 0"
    assert_output --partial "tests/unit/FooTest.php"
    assert_output --partial "method_count is not a number"
    assert_output --partial "test_methods is not an array"
}

@test "corrects a reordered test_methods list to file order even though the set matches" {
    _write_test_class "${REPO_DIR}/tests/unit/FooTest.php" testAlpha testBeta
    _write_manifest "${BATS_TEST_TMPDIR}/manifest.json" "tests/unit/FooTest.php" 2 '["testBeta","testAlpha"]'

    run --separate-stderr verify_method_counts "${BATS_TEST_TMPDIR}/manifest.json" "${REPO_DIR}"
    assert_success
    assert_equal "${stderr}" "verify-method-counts: tests/unit/FooTest.php: method_count 2 -> 2"

    run jq -c '.[0].test_methods' <<< "${output}"
    assert_output '["testAlpha","testBeta"]'
}
