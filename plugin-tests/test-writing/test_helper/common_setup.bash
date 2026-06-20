#!/bin/bash
# Test fixtures for the test-writing test-rules MCP server

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

PLUGIN_DIR="${REPO_ROOT}/plugins/test-writing"
TEST_RULES_LIB_DIR="${PLUGIN_DIR}/mcp-server-test-rules/lib"
RULES_DIR="${PLUGIN_DIR}/rules"
REVIEW_UNIT_VALIDATOR="${REPO_ROOT}/.github/scripts/validate-review-unit.sh"

# Write a minimal rule fixture under <dir>/unit/<id>.md.
# review-unit ($3): omitted when empty; written verbatim otherwise (callers may
#   pass trailing whitespace to exercise trimming).
# scoped-review ($4): defaults to a valid "include" when the arg is NOT supplied,
#   so review-unit-focused fixtures don't trip the scoped-review fail-hard. Pass
#   "" explicitly to omit the line, or an invalid value to exercise its guard.
write_rule() {
    local dir="$1" id="$2" review_unit="${3:-}" scoped_review
    if [[ $# -ge 4 ]]; then
        scoped_review="$4"
    else
        scoped_review="include"
    fi
    mkdir -p "${dir}/unit"
    {
        echo "---"
        echo "id: ${id}"
        echo "title: ${id} fixture"
        echo "group: unit"
        echo "enforce: must-fix"
        echo "test-types: unit"
        echo "test-categories: A"
        echo "scope: phpunit"
        [[ -n "${review_unit}" ]] && echo "review-unit: ${review_unit}"
        [[ -n "${scoped_review}" ]] && echo "scoped-review: ${scoped_review}"
        echo "---"
        echo ""
        echo "## ${id}"
    } > "${dir}/unit/${id}.md"
}
