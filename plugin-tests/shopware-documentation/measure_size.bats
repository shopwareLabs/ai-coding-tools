#!/usr/bin/env bats
# bats file_tags=shopware-documentation,measure-size
# `size` mode: budget verdicts, routing-row subtraction, size markers, and the
# fixed-width report format.
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

setup() {
    cd "${BATS_TEST_TMPDIR}" || fail "could not enter ${BATS_TEST_TMPDIR}"
}

# --- verdicts at the default budget boundaries ---

@test "a surface exactly at the goal is verdict goal" {
    make_counted_md 'surface.md' 5000

    run_measure size 'surface.md'

    assert_success
    assert_output --partial '    0  goal'
}

@test "a surface one character above the goal is verdict allowed" {
    make_counted_md 'surface.md' 5001

    run_measure size 'surface.md'

    assert_success
    assert_output --partial '    0  allowed'
}

@test "a surface exactly at the limit is verdict allowed" {
    make_counted_md 'surface.md' 6500

    run_measure size 'surface.md'

    assert_success
    assert_output --partial '    0  allowed'
}

@test "a surface one character above the limit is verdict allowance" {
    make_counted_md 'surface.md' 6501

    run_measure size 'surface.md'

    assert_success
    assert_output --partial '    0  allowance'
}

@test "a surface exactly at the ceiling is verdict allowance" {
    make_counted_md 'surface.md' 10000

    run_measure size 'surface.md'

    assert_success
    assert_output --partial '    0  allowance'
}

@test "a surface one character above the ceiling is verdict over" {
    make_counted_md 'surface.md' 10001

    run_measure size 'surface.md'

    assert_success
    assert_output --partial '    0  over'
}

# --- budget flags ---

@test "a raised goal brings an allowance-sized surface back to goal" {
    make_counted_md 'surface.md' 7000

    run_measure size --goal 8000 'surface.md'

    assert_success
    assert_output --partial '    0  goal'
}

@test "a raised limit brings an allowance-sized surface down to allowed" {
    make_counted_md 'surface.md' 7000

    run_measure size --limit 8000 'surface.md'

    assert_success
    assert_output --partial '    0  allowed'
}

@test "a lowered ceiling pushes an allowance-sized surface over" {
    make_counted_md 'surface.md' 7000

    run_measure size --ceiling 6000 'surface.md'

    assert_success
    assert_output --partial '    0  over'
}

@test "routing rows above the configured maximum are a finding" {
    make_two_row_index 'index.md'

    run_measure size --max-index-rows 1 'index.md'

    assert_success
    assert_output --partial '2 routing rows above the 1 maximum'
}

@test "a pointer file exceeding the routing-row maximum still yields the finding" {
    make_two_row_index 'AGENTS.md'

    run_measure size --max-index-rows 1 'AGENTS.md'

    assert_success
    assert_output --partial '2 routing rows above the 1 maximum'
}

@test "with no --max-index-rows flag, twenty-one routing rows produce the default-maximum finding" {
    make_n_row_index 'index.md' 21

    run_measure size 'index.md'

    assert_success
    assert_output --partial '21 routing rows above the 20 maximum'
}

@test "with no --max-index-rows flag, twenty routing rows produce no routing-rows finding" {
    make_n_row_index 'index.md' 20

    run_measure size 'index.md'

    assert_success
    assert_output --partial '1 surface measured, 0 findings'
}

# --- routing rows ---

@test "routing rows are subtracted from a regular surface's counted total" {
    make_two_row_index 'index.md'

    run_measure size 'index.md'

    assert_success
    assert_line --index 1 '       9       47     2  goal                   index.md'
}

@test "a pointer file counts its routing rows toward its total" {
    make_two_row_index 'AGENTS.md'

    run_measure size 'AGENTS.md'

    assert_success
    assert_line --index 1 '      47       47     2  goal                   AGENTS.md'
}

@test "CLAUDE.md is recognised as a pointer file" {
    make_two_row_index 'CLAUDE.md'

    run_measure size 'CLAUDE.md'

    assert_success
    assert_line --index 1 '      47       47     2  goal                   CLAUDE.md'
}

@test "every routing-row marker form is tallied" {
    run_measure size --max-index-rows 0 "${FIXTURES_DIR}/rows/all_markers.md"

    assert_success
    assert_output --partial '5 routing rows above the 0 maximum'
}

@test "a link in running prose is not a routing row" {
    run_measure size --max-index-rows 0 "${FIXTURES_DIR}/rows/plain_paragraph.md"

    assert_success
    assert_output --partial '1 surface measured, 0 findings'
}

@test "a list item whose only link is not markdown is not a routing row" {
    run_measure size --max-index-rows 0 "${FIXTURES_DIR}/rows/non_md_link.md"

    assert_success
    assert_output --partial '1 surface measured, 0 findings'
}

@test "a list item carrying two sentences of prose is not a routing row" {
    run_measure size --max-index-rows 0 "${FIXTURES_DIR}/rows/two_sentences.md"

    assert_success
    assert_output --partial '1 surface measured, 0 findings'
}

@test "a list item inside a fence is not a routing row" {
    run_measure size --max-index-rows 0 "${FIXTURES_DIR}/rows/fenced_row.md"

    assert_success
    assert_output --partial '1 surface measured, 0 findings'
}

# --- size markers ---

@test "a size-exempt marker makes the surface exempt" {
    make_counted_md 'surface.md' 10001 '<!-- size-exempt: storefront-team -->'

    run_measure size 'surface.md'

    assert_success
    assert_output --partial 'exempt     parsed'
}

@test "a size-allowance marker with the lookup criterion justifies the allowance" {
    make_counted_md 'surface.md' 7000 '<!-- size-allowance: lookup -->'

    run_measure size 'surface.md'

    assert_success
    assert_output --partial 'allowance  lookup'
}

@test "a size-allowance marker with the contiguous criterion justifies the allowance" {
    make_counted_md 'surface.md' 7000 '<!-- size-allowance: contiguous -->'

    run_measure size 'surface.md'

    assert_success
    assert_output --partial 'allowance  contiguous'
}

@test "a size-allowance marker with the atomic criterion justifies the allowance" {
    make_counted_md 'surface.md' 7000 '<!-- size-allowance: atomic -->'

    run_measure size 'surface.md'

    assert_success
    assert_output --partial 'allowance  atomic'
}

@test "a size-allowance marker with trailing content after the criterion is recognised" {
    make_counted_md 'surface.md' 7000 '<!-- size-allowance: lookup - one entry per item -->'

    run_measure size 'surface.md'

    assert_success
    assert_output --partial 'allowance  lookup'
}

@test "the first size-allowance marker in the file wins" {
    make_counted_md 'surface.md' 7000 \
        '<!-- size-allowance: lookup -->' '<!-- size-allowance: atomic -->'

    run_measure size 'surface.md'

    assert_success
    assert_output --partial 'allowance  lookup'
}

@test "a size-allowance marker split across two lines is not recognised" {
    make_counted_md 'surface.md' 7000 '<!-- size-allowance:' 'atomic -->'

    run_measure size 'surface.md'

    assert_success
    assert_output --partial '7000 chars above the 6500 limit with no allowance marker'
}

@test "a size-exempt marker split across two lines is not recognised" {
    make_counted_md 'surface.md' 10001 '<!-- size-exempt:' 'storefront-team -->'

    run_measure size 'surface.md'

    assert_success
    assert_output --partial '10001 chars above the 10000 ceiling; splits regardless of any marker'
}

@test "a surface in the allowance band without a marker is a finding" {
    make_counted_md 'surface.md' 7000

    run_measure size 'surface.md'

    assert_success
    assert_output --partial '7000 chars above the 6500 limit with no allowance marker'
}

@test "a surface above the ceiling is a finding despite an allowance marker" {
    make_counted_md 'surface.md' 10001 '<!-- size-allowance: atomic -->'

    run_measure size 'surface.md'

    assert_success
    assert_output --partial '10001 chars above the 10000 ceiling; splits regardless of any marker'
}

@test "a surface with both an exempt marker and an allowance marker is exempt with the allowance criterion" {
    make_counted_md 'surface.md' 10001 \
        '<!-- size-exempt: storefront-team -->' '<!-- size-allowance: lookup -->'

    run_measure size 'surface.md'

    assert_success
    assert_line --index 1 '   10001    10001     0  exempt     lookup      surface.md'
}

@test "size markers inside a fenced block are not recognised" {
    make_counted_md 'surface.md' 10001 \
        '```' '<!-- size-exempt: storefront-team -->' '<!-- size-allowance: lookup -->' '```'

    run_measure size 'surface.md'

    assert_success
    assert_output --partial '    0  over'
    assert_output --partial '10001 chars above the 10000 ceiling; splits regardless of any marker'
}

@test "a size-exempt marker with empty consumer text is not recognised" {
    make_counted_md 'surface.md' 10001 '<!-- size-exempt: -->'

    run_measure size 'surface.md'

    assert_success
    assert_output --partial '    0  over'
    assert_output --partial '10001 chars above the 10000 ceiling; splits regardless of any marker'
}

@test "a size-allowance marker on a surface within the goal band still shows its criterion" {
    make_counted_md 'surface.md' 5000 '<!-- size-allowance: lookup -->'

    run_measure size 'surface.md'

    assert_success
    assert_line --index 1 '    5000     5000     0  goal       lookup      surface.md'
}

# --- report format ---

@test "the report opens with the column header" {
    make_counted_md 'surface.md' 5000

    run_measure size 'surface.md'

    assert_success
    assert_line --index 0 ' counted      raw  rows  verdict    criterion   path'
}

@test "surfaces are listed by descending counted total" {
    make_counted_md 'small.md' 5000
    make_counted_md 'large.md' 6000

    run_measure size 'small.md' 'large.md'

    assert_success
    assert_line --index 1 --partial 'large.md'
    assert_line --index 2 --partial 'small.md'
}

@test "a scope of one surface is summarised in the singular" {
    make_counted_md 'surface.md' 5000

    run_measure size 'surface.md'

    assert_success
    assert_line --index 3 '1 surface measured, 0 findings'
    assert_equal "${#lines[@]}" 4
}

@test "a scope of several surfaces is summarised in the plural" {
    make_counted_md 'small.md' 5000
    make_counted_md 'large.md' 6000

    run_measure size 'small.md' 'large.md'

    assert_success
    assert_line --index 4 '2 surfaces measured, 0 findings'
    assert_equal "${#lines[@]}" 5
}

@test "findings are listed indented under the summary" {
    make_counted_md 'oversized.md' 10001

    run_measure size 'oversized.md'

    assert_success
    assert_line --index 4 '  oversized.md: 10001 chars above the 10000 ceiling; splits regardless of any marker'
}

@test "the criterion column is exactly 11 characters wide for a non-empty criterion" {
    make_counted_md 'surface.md' 7000 '<!-- size-allowance: lookup -->'

    run_measure size 'surface.md'

    assert_success
    assert_line --index 1 '    7000     7000     0  allowance  lookup      surface.md'
}

@test "findings from multiple files are ordered by row then by each file's own finding order" {
    make_counted_md 'big.md' 10100 '- [link](target.md)'
    make_counted_md 'small.md' 7020 '- [link](target.md)'

    run_measure size --max-index-rows 0 'big.md' 'small.md'

    assert_success
    assert_line --index 4 '2 surfaces measured, 4 findings'
    assert_line --index 5 '  big.md: 10080 chars above the 10000 ceiling; splits regardless of any marker'
    assert_line --index 6 '  big.md: 1 routing rows above the 0 maximum'
    assert_line --index 7 '  small.md: 7000 chars above the 6500 limit with no allowance marker'
    assert_line --index 8 '  small.md: 1 routing rows above the 0 maximum'
}
