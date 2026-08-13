#!/usr/bin/env bats
# bats file_tags=shopware-documentation,measure-links
# `links` mode: citation resolution, anchor checks, backticked bare paths, and
# the known-positive fixture guard.
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

# --- markdown link resolution ---

@test "a relative link to an existing surface counts as resolved" {
    run_measure links "${FIXTURES_DIR}/links/resolving_link.md"

    assert_success
    assert_line --index 0 '1 files scanned, 1 citations found, 1 resolved, 0 findings'
}

@test "a link to a missing surface is a finding on its 1-based line" {
    cd "${FIXTURES_DIR}/links" || fail "could not enter the links fixture directory"

    run_measure links 'missing_target.md'

    assert_success
    assert_line --index 1 '  missing_target.md:5: link target does not exist: no-such-guide.md'
}

@test "every link on a single line is scanned" {
    run_measure links "${FIXTURES_DIR}/links/multiple_links.md"

    assert_success
    assert_output --partial '2 citations found, 2 resolved, 0 findings'
}

@test "the links summary line reports exact counts for a multi-citation scope" {
    run_measure links "${FIXTURES_DIR}/links/multiple_links.md"

    assert_success
    assert_line --index 0 '1 files scanned, 2 citations found, 2 resolved, 0 findings'
    assert_equal "${#lines[@]}" 1
}

@test "a link with an empty target and no anchor resolves against the citing surface" {
    run_measure links "${FIXTURES_DIR}/links/empty_target_no_anchor.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

@test "links inside a fence are not scanned" {
    run_measure links "${FIXTURES_DIR}/links/fenced_links.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

@test "a fence delimiter with leading whitespace still hides the link inside it" {
    run_measure links "${FIXTURES_DIR}/links/indented_fence.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

@test "an absolute-looking link target is resolved by concatenation with the citing directory" {
    run_measure links "${FIXTURES_DIR}/links/absolute_target.md"

    assert_success
    assert_line --index 0 '1 files scanned, 1 citations found, 1 resolved, 0 findings'
}

# --- anchors ---

@test "an anchor present in the target resolves cleanly" {
    run_measure links "${FIXTURES_DIR}/links/anchor_found.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

@test "an anchor absent from the target is a finding" {
    run_measure links "${FIXTURES_DIR}/links/anchor_missing.md"

    assert_success
    assert_output --partial 'anchor not found in target.md: #installation-steps'
}

@test "an anchor that restates the target filename is a finding" {
    run_measure links "${FIXTURES_DIR}/links/anchor_restates.md"

    assert_success
    assert_output --partial 'anchor restates the target file: #product-catalog'
}

@test "an anchor with an empty target resolves against the citing surface" {
    run_measure links "${FIXTURES_DIR}/links/same_file_anchor.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

@test "a missing target with an anchor reports only the missing-target finding" {
    cd "${FIXTURES_DIR}/links" || fail "could not enter the links fixture directory"

    run_measure links 'missing_target_with_anchor.md'

    assert_success
    assert_line --index 0 '1 files scanned, 1 citations found, 0 resolved, 1 findings'
    assert_line --index 1 '  missing_target_with_anchor.md:3: link target does not exist: no-such-guide.md'
}

# --- anchor slug edge cases ---

@test "a heading with backticks and punctuation resolves via its computed slug" {
    run_measure links "${FIXTURES_DIR}/links/anchor_backticks_punctuation.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

@test "a heading with a trailing ATX closer resolves via its stripped slug" {
    run_measure links "${FIXTURES_DIR}/links/anchor_trailing_hash.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

@test "a heading with a trailing ATX closer followed by trailing whitespace resolves via its stripped slug" {
    run_measure links "${FIXTURES_DIR}/links/anchor_heading_trailing_space.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

@test "a heading inside a fence does not contribute an anchor" {
    run_measure links "${FIXTURES_DIR}/links/anchor_fenced_heading.md"

    assert_success
    assert_output --partial 'anchor not found in anchor_target_fenced_heading.md: #fenced-heading'
}

@test "non-ASCII characters in a heading are deleted from its slug" {
    run_measure links "${FIXTURES_DIR}/links/anchor_unicode_heading.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

# --- skipped link targets ---

@test "web and mail links are not citations" {
    run_measure links "${FIXTURES_DIR}/links/skipped_schemes.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

@test "a link to a non-markdown target is not a citation" {
    run_measure links "${FIXTURES_DIR}/links/non_md_target.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

# --- backticked bare paths ---

@test "a backticked markdown path that resolves is a finding" {
    run_measure links "${FIXTURES_DIR}/links/bare_path_resolves.md"

    assert_success
    assert_output --partial 'bare path is not a cross-reference (resolves): `target.md`'
}

@test "a backticked markdown path that does not resolve is a finding" {
    run_measure links "${FIXTURES_DIR}/links/bare_path_missing.md"

    assert_success
    assert_output --partial 'bare path is not a cross-reference (DOES NOT RESOLVE): `no-such-guide.md`'
}

@test "backticked placeholder spans are not reported as bare paths" {
    run_measure links "${FIXTURES_DIR}/links/bare_path_placeholders.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

@test "a backticked path inside a link label is not reported separately" {
    run_measure links "${FIXTURES_DIR}/links/bare_path_in_label.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

@test "a backticked bare path inside a fence is not reported" {
    run_measure links "${FIXTURES_DIR}/links/bare_path_fenced.md"

    assert_success
    assert_output --partial '1 citations found, 1 resolved, 0 findings'
}

# --- scope ---

@test "an existing file without the markdown suffix contributes no surface in links mode" {
    run_measure links "${FIXTURES_DIR}/scope/notes.txt" "${FIXTURES_DIR}/links/resolving_link.md"

    assert_success
    assert_line --index 0 '1 files scanned, 1 citations found, 1 resolved, 0 findings'
}

# --- budget flags ---

@test "budget flags are accepted and ignored by links mode" {
    run_measure links --goal 1 --limit 1 --ceiling 1 --max-index-rows 1 "${FIXTURES_DIR}/links/resolving_link.md"

    assert_success
    assert_output --partial '1 files scanned, 1 citations found, 1 resolved, 0 findings'
}

# --- known-positive fixture guard ---

@test "a scope without any citation reports the fixture failure on stderr" {
    run_measure links "${FIXTURES_DIR}/links/no_citation.md"

    assert_success
    assert_stderr_contains 'FIXTURE FAILURE: no citation matched anywhere in scope'
}

@test "a scope without any citation reports the broken-sweep finding" {
    run_measure links "${FIXTURES_DIR}/links/no_citation.md"

    assert_success
    assert_output --partial 'sweep matched nothing; the check itself is broken'
}

@test "a scope without any citation prints no summary line" {
    run_measure links "${FIXTURES_DIR}/links/no_citation.md"

    assert_success
    refute_output --partial 'files scanned'
}

@test "a scope without any citation fails under strict mode" {
    run_measure links --strict "${FIXTURES_DIR}/links/no_citation.md"

    assert_failure 1
    assert_output --partial 'sweep matched nothing; the check itself is broken'
}

@test "the broken-sweep path emits exactly one finding, printed as the exact literal line" {
    run_measure links --strict "${FIXTURES_DIR}/links/no_citation.md"

    assert_failure 1
    assert_line --index 0 '  .:0: sweep matched nothing; the check itself is broken'
    assert_equal "${#lines[@]}" 1
}

@test "a scope with a bare-path finding but no citation reports only the broken-sweep finding" {
    run_measure links --strict "${FIXTURES_DIR}/links/bare_path_no_citation.md"

    assert_failure 1
    assert_line --index 0 '  .:0: sweep matched nothing; the check itself is broken'
    refute_output --partial 'bare path is not a cross-reference'
    assert_equal "${#lines[@]}" 1
}
