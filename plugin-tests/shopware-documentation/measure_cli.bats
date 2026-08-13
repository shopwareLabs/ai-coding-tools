#!/usr/bin/env bats
# bats file_tags=shopware-documentation,measure-cli
# Command-line surface of measure.sh: argument handling, scope expansion,
# the composed `all` mode, and the exit-code contract.
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

# --- argument handling ---

@test "an invocation with no path prints usage" {
    run_measure size

    assert_failure 2
    assert_stderr_contains 'measure.sh <mode> [flags] PATH'
}

@test "an unrecognised mode prints usage" {
    run_measure sizes "${FIXTURES_DIR}/links/resolving_link.md"

    assert_failure 2
    assert_stderr_contains 'measure.sh <mode> [flags] PATH'
}

@test "an unrecognised flag prints usage" {
    run_measure size --verbose "${FIXTURES_DIR}/links/resolving_link.md"

    assert_failure 2
    assert_stderr_contains 'measure.sh <mode> [flags] PATH'
}

@test "a non-numeric budget value prints usage" {
    run_measure size --goal generous "${FIXTURES_DIR}/links/resolving_link.md"

    assert_failure 2
    assert_stderr_contains 'measure.sh <mode> [flags] PATH'
}

@test "flags interleaved between paths are still parsed" {
    make_counted_md "${BATS_TEST_TMPDIR}/a.md" 7000
    make_counted_md "${BATS_TEST_TMPDIR}/b.md" 7000

    run_measure size "${BATS_TEST_TMPDIR}/a.md" --goal 8000 "${BATS_TEST_TMPDIR}/b.md"

    assert_success
    assert_output --partial '2 surfaces measured, 0 findings'
}

@test "-- ends flag parsing so a dash-prefixed path is measured, not rejected as a flag" {
    cd "${BATS_TEST_TMPDIR}" || fail "could not enter ${BATS_TEST_TMPDIR}"
    make_counted_md '-dashed.md' 5000

    run_measure size -- '-dashed.md'

    assert_success
    assert_output --partial '1 surface measured, 0 findings'
}

@test "a nonexistent path is rejected by name" {
    run_measure size "${BATS_TEST_TMPDIR}/absent-surface.md"

    assert_failure 2
    assert_stderr_contains "path does not exist: ${BATS_TEST_TMPDIR}/absent-surface.md"
}

@test "several nonexistent paths are reported in one comma-joined line" {
    run_measure size "${BATS_TEST_TMPDIR}/absent-one.md" "${BATS_TEST_TMPDIR}/absent-two.md"

    assert_failure 2
    assert_stderr_contains "path does not exist: ${BATS_TEST_TMPDIR}/absent-one.md, ${BATS_TEST_TMPDIR}/absent-two.md"
}

@test "one nonexistent path among existing ones measures nothing and names only the missing path" {
    run_measure size "${FIXTURES_DIR}/links/resolving_link.md" "${BATS_TEST_TMPDIR}/absent-surface.md"

    assert_failure 2
    assert_output ''
    assert_stderr_contains "path does not exist: ${BATS_TEST_TMPDIR}/absent-surface.md"
}

# --- scope expansion ---

@test "a directory scope measures only its markdown files" {
    run_measure size "${FIXTURES_DIR}/scope"

    assert_success
    assert_output --partial '3 surfaces measured, 0 findings'
}

@test "a directory scope reports its files sorted by full path" {
    run_measure links "${FIXTURES_DIR}/scope"

    assert_success
    assert_line --index 1 --partial 'alpha.md'
    assert_line --index 2 --partial 'nested/beta.md'
    assert_line --index 3 --partial 'zulu.md'
}

@test "two directory paths given in reverse lexicographic order are reported per-directory sorted, not globally merged" {
    mkdir -p "${BATS_TEST_TMPDIR}/zzz" "${BATS_TEST_TMPDIR}/aaa"
    printf '%s\n' '# Z A' '' 'See [missing](no-such.md) here.' > "${BATS_TEST_TMPDIR}/zzz/a.md"
    printf '%s\n' '# Z B' '' 'See [missing](no-such.md) here.' > "${BATS_TEST_TMPDIR}/zzz/b.md"
    printf '%s\n' '# A X' '' 'See [missing](no-such.md) here.' > "${BATS_TEST_TMPDIR}/aaa/x.md"
    printf '%s\n' '# A Y' '' 'See [missing](no-such.md) here.' > "${BATS_TEST_TMPDIR}/aaa/y.md"

    run_measure links "${BATS_TEST_TMPDIR}/zzz" "${BATS_TEST_TMPDIR}/aaa"

    assert_success
    assert_line --index 1 --partial 'zzz/a.md'
    assert_line --index 2 --partial 'zzz/b.md'
    assert_line --index 3 --partial 'aaa/x.md'
    assert_line --index 4 --partial 'aaa/y.md'
}

@test "an existing file without the markdown suffix contributes no surface" {
    run_measure size "${FIXTURES_DIR}/scope/notes.txt"

    assert_success
    assert_output --partial '0 surfaces measured, 0 findings'
}

# --- all mode ---

@test "all mode prints the links report one blank line after the size report" {
    run_measure all "${FIXTURES_DIR}/links/resolving_link.md"

    assert_success
    assert_line --index 3 '1 surface measured, 0 findings'
    assert_line --index 4 ''
    assert_line --index 5 '1 files scanned, 1 citations found, 1 resolved, 0 findings'
}

@test "a finding from the size half drives the strict exit code in all mode" {
    make_counted_md "${BATS_TEST_TMPDIR}/oversized.md" 10001 \
        '## Usage' '' 'Jump to [usage](#usage) for the details.'

    run_measure all --strict "${BATS_TEST_TMPDIR}/oversized.md"

    assert_failure 1
    assert_output --partial '10001 chars above the 10000 ceiling'
}

@test "a raised goal in all mode shifts the size verdict while the links half stays unaffected" {
    printf '# Target\n' > "${BATS_TEST_TMPDIR}/target.md"
    make_counted_md "${BATS_TEST_TMPDIR}/surface.md" 7000 \
        '## Heading' '' 'See [Guide](target.md) for more.'

    run_measure all --goal 8000 "${BATS_TEST_TMPDIR}/surface.md"

    assert_success
    assert_output --partial '    0  goal'
    assert_output --partial '1 files scanned, 1 citations found, 1 resolved, 0 findings'
}

@test "a finding from the links half drives the strict exit code in all mode" {
    run_measure all --strict "${FIXTURES_DIR}/links/missing_target.md"

    assert_failure 1
    assert_output --partial 'link target does not exist: no-such-guide.md'
}

# --- exit codes ---

@test "findings without strict mode still exit zero" {
    make_counted_md "${BATS_TEST_TMPDIR}/oversized.md" 10001

    run_measure size "${BATS_TEST_TMPDIR}/oversized.md"

    assert_success
    assert_output --partial '1 surface measured, 1 findings'
}

@test "findings under strict mode exit one" {
    make_counted_md "${BATS_TEST_TMPDIR}/oversized.md" 10001

    run_measure size --strict "${BATS_TEST_TMPDIR}/oversized.md"

    assert_failure 1
    assert_output --partial '1 surface measured, 1 findings'
}

@test "a clean run under strict mode exits zero" {
    make_counted_md "${BATS_TEST_TMPDIR}/within-goal.md" 5000

    run_measure size --strict "${BATS_TEST_TMPDIR}/within-goal.md"

    assert_success
    assert_output --partial '1 surface measured, 0 findings'
}
