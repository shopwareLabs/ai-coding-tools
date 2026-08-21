#!/usr/bin/env bats
# bats file_tags=chunkhound-integration,sweep
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

# Fixture tree: two matching .md files, one matching .php file, one
# non-matching file, with StoredElement/RenderedElement split across
# files so ERE alternation is observable.
setup() {
    TREE="${BATS_TEST_TMPDIR}/tree"
    mkdir -p "${TREE}/sub"
    printf '%s\n' 'StoredElement is the storage model' > "${TREE}/stored.md"
    printf '%s\n' 'RenderedElement one' 'RenderedElement two' > "${TREE}/sub/rendered.md"
    printf '%s\n' 'class StoredElement {}' > "${TREE}/code.php"
    printf '%s\n' 'nothing to see' > "${TREE}/other.md"
}

@test "default mode lists matching files and counts them" {
    run_sweep "StoredElement|RenderedElement" "${TREE}"
    assert_success
    assert_line "${TREE}/stored.md"
    assert_line "${TREE}/sub/rendered.md"
    assert_line "${TREE}/code.php"
    assert_line "count: 3"
    refute_output --partial "other.md"
}

@test "-n mode lists matching lines and counts lines, not files" {
    run_sweep -n "RenderedElement" "${TREE}"
    assert_success
    assert_line "${TREE}/sub/rendered.md:1:RenderedElement one"
    assert_line "${TREE}/sub/rendered.md:2:RenderedElement two"
    assert_line "count: 2"
}

@test "-g glob restricts the sweep to matching file names" {
    run_sweep -g '*.md' "StoredElement|RenderedElement" "${TREE}"
    assert_success
    assert_line "count: 2"
    refute_output --partial "code.php"
}

@test "zero matches yields count 0 and exit 0" {
    run_sweep "NoSuchSymbolAnywhere" "${TREE}"
    assert_success
    assert_output $'---\ncount: 0'
}

@test "escaped pipe matches a literal pipe, not alternation" {
    printf '%s\n' 'literal StoredElement|RenderedElement pipe' > "${TREE}/piped.md"
    run_sweep 'StoredElement\|RenderedElement' "${TREE}"
    assert_success
    assert_output "${TREE}/piped.md"$'\n---\ncount: 1'
}

@test "missing arguments fails with usage on stderr" {
    run_sweep "onlypattern"
    assert_failure 2
    assert [ -z "${output}" ]
    [[ "${stderr}" == *"usage: sweep.sh"* ]]
}

@test "nonexistent search path fails with a nonzero status above 1" {
    run_sweep "StoredElement" "${TREE}/does-not-exist"
    assert_failure
    assert [ "${status}" -gt 1 ]
}
