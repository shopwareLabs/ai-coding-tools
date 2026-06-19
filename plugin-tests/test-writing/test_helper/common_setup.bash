#!/bin/bash
# Test fixtures for the test-writing test-rules MCP server

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

PLUGIN_DIR="${REPO_ROOT}/plugins/test-writing"
TEST_RULES_LIB_DIR="${PLUGIN_DIR}/mcp-server-test-rules/lib"
RULES_DIR="${PLUGIN_DIR}/rules"
REVIEW_UNIT_VALIDATOR="${REPO_ROOT}/.github/scripts/validate-review-unit.sh"

# Write a minimal rule fixture under <dir>/unit/<id>.md.
# Omits the review-unit line when $3 is empty; otherwise writes the given value
# verbatim (callers may pass trailing whitespace to exercise trimming).
write_rule() {
    local dir="$1" id="$2" review_unit="${3:-}"
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
        echo "---"
        echo ""
        echo "## ${id}"
    } > "${dir}/unit/${id}.md"
}
