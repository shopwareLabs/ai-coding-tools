#!/usr/bin/env bats
# bats file_tags=test-writing,team-review,workflow
# Behaviour tests for the committed team-review Workflow script
# (skills/phpunit-unit-test-team-reviewing/workflow/team-review.workflow.mjs).
#
# The script cannot be unit-tested in bash (it runs in Claude Code's Workflow runtime),
# so each test drives a node harness (workflow_harness.mjs) that wraps the real script
# with stub globals and a deterministic agent responder. The assertions live in
# workflow_scenarios.mjs (full object access); each scenario prints "PASS <name>" on
# success and exits non-zero on an assertion failure. This file maps one bats @test to
# one scenario so a regression names the exact behaviour that broke.
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

setup() {
    # Fail loud (never skip) if node is unavailable — GitHub ubuntu-latest ships it on PATH.
    if ! command -v node >/dev/null 2>&1; then
        fail "node is required to run the team-review workflow harness but was not found on PATH"
    fi
}

scenario() {
    run node "${BATS_TEST_DIRNAME}/workflow_scenarios.mjs" "$1"
}

@test "workflow wrap executes and returns the documented result shape" {
    scenario smoke
    assert_success
    assert_output --partial "PASS smoke"
}

@test "per-file adversaries: all-K fail sets coverage_gap for that file only; 1-of-3 keeps it covered" {
    scenario coverage
    assert_success
    assert_output --partial "PASS coverage"
}

@test "size-aware re-spawn: a degraded retry recovers an overflowed adversary, keeping the file covered" {
    scenario degrade-recover
    assert_success
    assert_output --partial "PASS degrade-recover"
}

@test "K=3 distinct-lens adversaries spawn per file in both Wave-0 impressions and Wave-2 red team" {
    scenario lenses
    assert_success
    assert_output --partial "PASS lenses"
}

@test "lens adversaries' introductions are unioned and deduped into the defense wave" {
    scenario defense-union
    assert_success
    assert_output --partial "PASS defense-union"
}

@test "arbitration is uncapped: a contested must-fix past position 15 is arbitrated, not dropped" {
    scenario arb-uncap
    assert_success
    assert_output --partial "PASS arb-uncap"
}

@test "contested must-fix with 2-of-3 arbiters confirming is kept" {
    scenario arb-2confirm
    assert_success
    assert_output --partial "PASS arb-2confirm"
}

@test "contested must-fix with 2-of-3 arbiters refuting is excluded" {
    scenario arb-2refute
    assert_success
    assert_output --partial "PASS arb-2refute"
}

@test "contested must-fix with a 1/1/1 arbiter split is kept and marked split" {
    scenario arb-split
    assert_success
    assert_output --partial "PASS arb-split"
}

@test "quality floor preserved: 3 reviewers/unit, Wave-1 gate, contested bucket, cross-file agent" {
    scenario preserve
    assert_success
    assert_output --partial "PASS preserve"
}
