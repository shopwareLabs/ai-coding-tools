#!/bin/bash
# Fixtures for the shopware-documentation measure.sh suite.

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

MEASURE_SH="${REPO_ROOT}/plugins/shopware-documentation/skills/structuring-documentation/scripts/measure.sh"
FIXTURES_DIR="${BATS_TEST_DIRNAME}/fixtures"

# Invoke measure.sh, keeping stdout and stderr apart so that usage and
# path errors can be asserted on the stream the contract names.
# Sets: $status, $output (stdout), $stderr
run_measure() {
    run --keep-empty-lines --separate-stderr "${MEASURE_SH}" "$@"
}

# Assert that the captured stderr contains a substring.
assert_stderr_contains() {
    local expected="$1"

    if [[ "${stderr}" != *"${expected}"* ]]; then
        printf 'expected stderr to contain: %s\n' "${expected}"
        printf 'actual stderr: %s\n' "${stderr}"
        fail "stderr did not contain the expected text"
    fi
}

# Write a markdown file whose character count is exactly ${total}.
#
#   make_counted_md <target> <total> [extra_line ...]
#
# The file is a heading, a blank line, each extra_line verbatim, then a single
# padding line of 'x' characters sized so the total lands on ${total}. Extra
# lines carry markers or citations when a test needs them. None of the
# generated lines is a routing row, so counted equals total for regular files.
#
# Fails the test loudly when the requested total cannot be produced or when the
# file on disk does not have the requested byte count.
make_counted_md() {
    local target="$1"
    local total="$2"
    shift 2

    local prelude='# Sized surface

'
    local extra_line
    for extra_line in "$@"; do
        prelude="${prelude}${extra_line}"$'\n'
    done

    local filler_len=$(( total - ${#prelude} - 1 ))
    if [[ "${filler_len}" -lt 0 ]]; then
        fail "make_counted_md: total ${total} is too small for the ${#prelude} chars already required by ${target}"
    fi

    {
        printf '%s' "${prelude}"
        printf '%*s' "${filler_len}" '' | tr ' ' 'x'
        printf '\n'
    } > "${target}"

    local actual
    actual="$(wc -c < "${target}" | tr -d ' ')"
    if [[ "${actual}" -ne "${total}" ]]; then
        fail "make_counted_md: wrote ${actual} chars to ${target}, expected ${total}"
    fi
}

# Write a two-row index file: 47 raw characters, 2 routing rows of 19 and 17
# characters, so counted is 47 - 20 - 18 = 9 for a regular file.
make_two_row_index() {
    local target="$1"

    printf '%s\n' '# Index' '' '- [Alpha](alpha.md)' '- [Beta](beta.md)' > "${target}"

    local actual
    actual="$(wc -c < "${target}" | tr -d ' ')"
    if [[ "${actual}" -ne 47 ]]; then
        fail "make_two_row_index: wrote ${actual} chars to ${target}, expected 47"
    fi
}

# Write an index file with exactly ${count} routing rows: a heading, a blank
# line, then ${count} list-item rows, each a distinct one-link citation with
# no sentence-ending punctuation, so every row qualifies as a routing row.
make_n_row_index() {
    local target="$1"
    local count="$2"

    {
        printf '%s\n' '# Index' ''
        local i=1
        while [[ "${i}" -le "${count}" ]]; do
            printf -- '- [Item %d](item-%d.md)\n' "${i}" "${i}"
            i=$((i + 1))
        done
    } > "${target}"
}
