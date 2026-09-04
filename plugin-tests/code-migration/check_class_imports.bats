#!/usr/bin/env bats
# bats file_tags=code-migration,check-class-imports
# Pins PHP class-import resolution so missing imports cannot silently create
# namespace-relative service IDs during configuration migration.
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

CHECK_SH="${SCRIPTS_DIR}/check-class-imports.sh"

@test "reports a bare class reference with no matching use import as missing" {
    local file="${BATS_TEST_TMPDIR}/missing.php"
    cp "${FIXTURES_DIR}/php/missing-import.php" "$file"

    run --separate-stderr "${CHECK_SH}" "$file"
    assert_failure 1
    assert_stderr --partial "missing use import for: Foo"
}

@test "an aliased use import satisfies a reference to the alias" {
    local file="${BATS_TEST_TMPDIR}/aliased.php"
    cp "${FIXTURES_DIR}/php/aliased-import.php" "$file"

    run "${CHECK_SH}" "$file"
    assert_success
}

@test "a plain member of a group use import satisfies its class reference" {
    local file="${BATS_TEST_TMPDIR}/group-plain.php"
    cp "${FIXTURES_DIR}/php/group-plain-import.php" "$file"

    run "${CHECK_SH}" "$file"
    assert_success
}

@test "an aliased member of a group use import satisfies its class reference" {
    local file="${BATS_TEST_TMPDIR}/group-alias.php"
    cp "${FIXTURES_DIR}/php/group-aliased-import.php" "$file"

    run "${CHECK_SH}" "$file"
    assert_success
}

@test "function and const members of a group use import are skipped and the plain sibling still satisfies its class reference" {
    local file="${BATS_TEST_TMPDIR}/group-function-member.php"
    cp "${FIXTURES_DIR}/php/group-function-import.php" "$file"

    run "${CHECK_SH}" "$file"
    assert_success
}

@test "a class absent from a group use import remains missing" {
    local file="${BATS_TEST_TMPDIR}/group-missing.php"
    cp "${FIXTURES_DIR}/php/group-missing-import.php" "$file"

    run --separate-stderr "${CHECK_SH}" "$file"
    assert_failure 1
    assert_stderr --partial 'missing use import for: Missing'
}

@test "a leading-backslash FQCN is not flagged as a missing import" {
    local file="${BATS_TEST_TMPDIR}/fqcn.php"
    cp "${FIXTURES_DIR}/php/fqcn-reference.php" "$file"

    run "${CHECK_SH}" "$file"
    assert_success
}

@test "self, static, parent, and ContainerConfigurator are exempt from the import check" {
    local file="${BATS_TEST_TMPDIR}/exempt.php"
    cp "${FIXTURES_DIR}/php/exempt-references.php" "$file"

    run "${CHECK_SH}" "$file"
    assert_success
}

@test "checking multiple files names only the one with a missing import" {
    local good="${BATS_TEST_TMPDIR}/good.php" bad="${BATS_TEST_TMPDIR}/bad.php"
    cp "${FIXTURES_DIR}/php/imported-service.php" "$good"
    cp "${FIXTURES_DIR}/php/missing-bar-import.php" "$bad"

    run --separate-stderr "${CHECK_SH}" "$good" "$bad"
    assert_failure 1
    assert_stderr --partial "${bad}: missing use import for: Bar"
    refute_stderr --partial "${good}:"
}

@test "a named file that does not exist fails with exit 2, naming the path" {
    run --separate-stderr "${CHECK_SH}" "${BATS_TEST_TMPDIR}/absent.php"
    assert_failure 2
    assert_stderr --partial "${BATS_TEST_TMPDIR}/absent.php: not found"
}

@test "a file that does not exist stops the scan before the later argument's missing import is reported" {
    local bad="${BATS_TEST_TMPDIR}/bad.php"
    cp "${FIXTURES_DIR}/php/missing-bar-import.php" "$bad"

    run --separate-stderr "${CHECK_SH}" "${BATS_TEST_TMPDIR}/absent.php" "$bad"
    assert_failure 2
    assert_stderr --partial "${BATS_TEST_TMPDIR}/absent.php: not found"
    refute_stderr --partial "missing use import"
}

@test "no file arguments fails with usage on exit 2" {
    run --separate-stderr "${CHECK_SH}"
    assert_failure 2
    assert_stderr --partial "usage:"
}

@test "a relative PHP file beginning with a dash is treated as a path" {
    local parent="${BATS_TEST_TMPDIR}/leading-dash"
    mkdir -p "$parent"
    cp "${FIXTURES_DIR}/php/aliased-import.php" "${parent}/-config.php"

    run bash -c 'cd "$1" && "$2" -config.php' -- "$parent" "$CHECK_SH"
    assert_success
}
