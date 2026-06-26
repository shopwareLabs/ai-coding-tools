#!/usr/bin/env bats
# bats file_tags=test-writing,team-review,build-run-script
# Tests for build-run-script.sh — the flat-launcher helper that splices the
# assembled manifest into a top-level copy of the committed team-review workflow.
# Covers the exactly-one marker guard (pass on the real workflow; fail loud on 0
# and 2 occurrences), the jq-empty args validity gate, and the splice transform
# (marker replaced, surrounding lines byte-identical, injected region valid JSON).
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

setup() {
    WORKFLOW_DIR="${PLUGIN_DIR}/skills/phpunit-test-team-reviewing/workflow"
    BUILD_SCRIPT="${WORKFLOW_DIR}/build-run-script.sh"
    COMMITTED_WORKFLOW="${WORKFLOW_DIR}/team-review.workflow.mjs"
    # Source the helper directly: it defines the functions without running main,
    # so the guards are exercised in-process.
    source "${BUILD_SCRIPT}"
}

# Write a fixture workflow with <count> marker lines between two sentinel lines.
_fixture_workflow() {
    local path="$1" count="$2" i
    {
        echo "const head = 1;"
        for ((i = 0; i < count; i++)); do echo "const manifest = args;"; done
        echo "const tail = 2;"
    } > "${path}"
}

# ============================================================================
# Marker guard — the committed workflow must carry exactly one
# `const manifest = args;`; the build fails loudly otherwise.
# ============================================================================

@test "assert_single_marker passes on the committed workflow" {
    run assert_single_marker "${COMMITTED_WORKFLOW}"
    assert_success
}

@test "assert_single_marker fails loudly when the marker is absent" {
    _fixture_workflow "${BATS_TEST_TMPDIR}/wf0.mjs" 0
    run assert_single_marker "${BATS_TEST_TMPDIR}/wf0.mjs"
    assert_failure
    assert_output --partial "found 0"
}

@test "assert_single_marker fails loudly when the marker appears twice" {
    _fixture_workflow "${BATS_TEST_TMPDIR}/wf2.mjs" 2
    run assert_single_marker "${BATS_TEST_TMPDIR}/wf2.mjs"
    assert_failure
    assert_output --partial "found 2"
}

# ============================================================================
# Args validity gate — malformed JSON is rejected before any output is written.
# ============================================================================

@test "build_run_script rejects malformed args json and writes no output" {
    _fixture_workflow "${BATS_TEST_TMPDIR}/wf.mjs" 1
    printf '%s\n' '{bad json' > "${BATS_TEST_TMPDIR}/args.json"
    local out="${BATS_TEST_TMPDIR}/run.mjs"
    run build_run_script "${BATS_TEST_TMPDIR}/args.json" "${out}" "${BATS_TEST_TMPDIR}/wf.mjs"
    assert_failure
    assert_output --partial "not valid JSON"
    assert [ ! -f "${out}" ]
}

@test "build_run_script enforces the marker guard and writes no output on a bad workflow" {
    # Proves the guard is wired into build_run_script, not merely a standalone
    # function: a workflow with the wrong marker count must abort before writing.
    _fixture_workflow "${BATS_TEST_TMPDIR}/wf2.mjs" 2
    printf '%s\n' '{"files":[]}' > "${BATS_TEST_TMPDIR}/args.json"
    local out="${BATS_TEST_TMPDIR}/run.mjs"
    run build_run_script "${BATS_TEST_TMPDIR}/args.json" "${out}" "${BATS_TEST_TMPDIR}/wf2.mjs"
    assert_failure
    assert_output --partial "found 2"
    assert [ ! -f "${out}" ]
}

# ============================================================================
# Splice transform — marker replaced, surrounding lines byte-identical, the
# injected region a valid JSON literal.
# ============================================================================

@test "build_run_script replaces the marker and keeps surrounding lines byte-identical" {
    _fixture_workflow "${BATS_TEST_TMPDIR}/wf.mjs" 1
    printf '%s\n' '{"x":1}' > "${BATS_TEST_TMPDIR}/args.json"
    local out="${BATS_TEST_TMPDIR}/run.mjs"
    run build_run_script "${BATS_TEST_TMPDIR}/args.json" "${out}" "${BATS_TEST_TMPDIR}/wf.mjs"
    assert_success

    run cat "${out}"
    assert_output "$(printf '%s\n' 'const head = 1;' 'const manifest = {"x":1}' ';' 'const tail = 2;')"
}

@test "build_run_script injects the manifest verbatim as a valid JSON literal" {
    _fixture_workflow "${BATS_TEST_TMPDIR}/wf.mjs" 1
    printf '%s\n' '{' '  "files": [],' '  "rule_packages": {}' '}' > "${BATS_TEST_TMPDIR}/args.json"
    local out="${BATS_TEST_TMPDIR}/run.mjs"
    run build_run_script "${BATS_TEST_TMPDIR}/args.json" "${out}" "${BATS_TEST_TMPDIR}/wf.mjs"
    assert_success

    # Reconstruct the injected literal: everything between `const manifest = ` and
    # the standalone `;`. It must equal the source args verbatim AND be valid JSON
    # (valid JSON is a valid JS expression — the right check, since the workflow's
    # top-level `return` makes `node --check` unusable).
    run awk '
        /^const manifest = / { sub(/^const manifest = /, ""); cap=1; print; next }
        cap && $0 == ";" { cap=0; next }
        cap { print }
    ' "${out}"
    assert_success
    assert_output "$(cat "${BATS_TEST_TMPDIR}/args.json")"
    printf '%s' "${output}" | jq empty
}

@test "build_run_script splices the committed workflow and removes the marker" {
    printf '%s\n' '{"files":[],"rule_packages":{}}' > "${BATS_TEST_TMPDIR}/args.json"
    local out="${BATS_TEST_TMPDIR}/run.mjs"
    run build_run_script "${BATS_TEST_TMPDIR}/args.json" "${out}" "${COMMITTED_WORKFLOW}"
    assert_success

    run grep -F -c 'const manifest = args;' "${out}"
    assert_output "0"

    run head -n 1 "${out}"
    assert_output "export const meta = {"

    run grep -F -c "typeof manifest !== 'object'" "${out}"
    assert_output "1"
}
