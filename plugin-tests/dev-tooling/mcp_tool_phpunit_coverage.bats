#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,php
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

# --- Sample XML fixtures ---

# Two files with method lines: Bar.php (1/5 stmts covered, lines 15-17,25 uncovered, method "doStuff" uncovered),
# Qux.php (1/2 stmts covered, line 8 uncovered, no uncovered methods)
SAMPLE_TWO_FILES='<coverage generated="1234"><project timestamp="1234">
<package name="Foo">
<file name="/app/src/Foo/Bar.php">
<class name="Bar"><metrics methods="2" coveredmethods="1" statements="5" coveredstatements="3"/></class>
<line num="5" type="method" name="covered" visibility="public" complexity="1" crap="1" count="3"/>
<line num="10" type="stmt" count="5"/>
<line num="14" type="method" name="doStuff" visibility="public" complexity="2" crap="6" count="0"/>
<line num="15" type="stmt" count="0"/>
<line num="16" type="stmt" count="0"/>
<line num="17" type="stmt" count="0"/>
<line num="20" type="stmt" count="3"/>
<line num="25" type="stmt" count="0"/>
<metrics loc="30" ncloc="25" statements="5" coveredstatements="1"/>
</file>
<file name="/app/src/Baz/Qux.php">
<line num="3" type="method" name="process" visibility="public" complexity="1" crap="1" count="2"/>
<line num="5" type="stmt" count="1"/>
<line num="8" type="stmt" count="0"/>
<metrics loc="10" ncloc="8" statements="2" coveredstatements="1"/>
</file>
</package>
<metrics statements="7" coveredstatements="2"/>
</project></coverage>'

# All lines covered (1 file, fully covered)
SAMPLE_ALL_COVERED='<coverage generated="1234"><project timestamp="1234">
<package name="Foo">
<file name="/app/src/Foo/Bar.php">
<line num="10" type="stmt" count="5"/>
<line num="15" type="stmt" count="3"/>
<metrics loc="20" ncloc="15" statements="2" coveredstatements="2"/>
</file>
</package>
<metrics statements="2" coveredstatements="2"/>
</project></coverage>'

# File with method-type lines (uncovered method "doStuff", 1 uncovered stmt)
SAMPLE_METHOD_LINES='<coverage generated="1234"><project timestamp="1234">
<package name="Foo">
<file name="/app/src/Foo/Bar.php">
<line num="10" type="method" name="doStuff" visibility="public" complexity="1" crap="1" count="0"/>
<line num="11" type="stmt" count="5"/>
<line num="15" type="stmt" count="0"/>
<metrics loc="20" ncloc="15" statements="2" coveredstatements="1"/>
</file>
</package>
</project></coverage>'

# Mixed coverage: 3 files (2 with gaps, 1 fully covered) for total file count testing
SAMPLE_MIXED_COVERAGE='<coverage generated="1234"><project timestamp="1234">
<package name="Foo">
<file name="/app/src/Foo/Alpha.php">
<line num="10" type="stmt" count="5"/>
<line num="15" type="stmt" count="0"/>
<metrics loc="20" ncloc="15" statements="2" coveredstatements="1"/>
</file>
<file name="/app/src/Foo/Beta.php">
<line num="10" type="stmt" count="3"/>
<line num="11" type="stmt" count="7"/>
<metrics loc="20" ncloc="15" statements="2" coveredstatements="2"/>
</file>
<file name="/app/src/Foo/Gamma.php">
<line num="10" type="stmt" count="1"/>
<line num="15" type="stmt" count="0"/>
<line num="16" type="stmt" count="0"/>
<metrics loc="20" ncloc="15" statements="3" coveredstatements="1"/>
</file>
</package>
</project></coverage>'

setup() {
    setup_php_mcp_env "${PLUGIN_DIR}" "${PLUGIN_DIR}/mcp-server-php/lib/phpunit_coverage.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE
}

# --- Default clover_path ---

@test "coverage_gaps: default path uses coverage.xml" {
    exec_command() {
        [[ "$1" == "cat 'coverage.xml'" ]] || { echo "unexpected: $1"; return 1; }
        echo "${SAMPLE_ALL_COVERED}"
    }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
}

@test "coverage_gaps: custom clover_path is used" {
    exec_command() {
        [[ "$1" == "cat 'build/clover.xml'" ]] || { echo "unexpected: $1"; return 1; }
        echo "${SAMPLE_ALL_COVERED}"
    }
    run tool_phpunit_coverage_gaps '{"clover_path":"build/clover.xml"}'
    assert_success
}

# --- Basic parsing ---

@test "coverage_gaps: two files both appear in output" {
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
    assert_output --partial "Bar.php"
    assert_output --partial "Qux.php"
}

@test "coverage_gaps: consecutive lines grouped into ranges" {
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
    assert_output --partial "15-17"
}

@test "coverage_gaps: isolated uncovered line shown as single number" {
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
    assert_output --partial "25"
}

# --- Relative paths ---

@test "coverage_gaps: paths are relative to LINT_WORKDIR" {
    LINT_WORKDIR="/app"
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
    assert_output --partial "src/Foo/Bar.php"
    refute_output --partial "/app/src/Foo/Bar.php"
}

@test "coverage_gaps: paths unchanged when LINT_WORKDIR does not match" {
    LINT_WORKDIR="/other"
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
    assert_output --partial "/app/src/Foo/Bar.php"
}

# --- Uncovered method names ---

@test "coverage_gaps: uncovered method names appear in output" {
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
    assert_output --partial "Uncovered methods: doStuff"
}

@test "coverage_gaps: covered method names do not appear" {
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
    refute_output --partial "covered"$'\n'
    refute_output --partial "Uncovered methods: covered"
}

@test "coverage_gaps: files with no uncovered methods omit methods line" {
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{"source_filter":"Baz"}'
    assert_success
    # Qux.php has no uncovered methods (process is covered)
    refute_output --partial "Uncovered methods"
}

# --- source_filter ---

@test "coverage_gaps: source_filter includes matching files only" {
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{"source_filter":"Foo"}'
    assert_success
    assert_output --partial "Bar.php"
    refute_output --partial "Qux.php"
}

@test "coverage_gaps: source_filter no match returns empty message" {
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{"source_filter":"Nonexistent"}'
    assert_success
    assert_output --partial "No files matching filter"
}

# --- All covered ---

@test "coverage_gaps: all lines covered shows success message with file count" {
    exec_command() { echo "${SAMPLE_ALL_COVERED}"; }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
    assert_output --partial "All 1 file"
    assert_output --partial "100% statement coverage"
}

# --- Sorting ---

@test "coverage_gaps: files sorted by coverage ascending" {
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
    # Bar.php is 20.0% (1/5), Qux.php is 50.0% (1/2) — Bar should appear first
    local bar_pos qux_pos
    bar_pos=$(echo "${output}" | grep -n "Bar.php" | head -1 | cut -d: -f1)
    qux_pos=$(echo "${output}" | grep -n "Qux.php" | head -1 | cut -d: -f1)
    [[ ${bar_pos} -lt ${qux_pos} ]]
}

# --- Summary with file counts ---

@test "coverage_gaps: summary shows total file count and gap count" {
    exec_command() { echo "${SAMPLE_MIXED_COVERAGE}"; }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
    assert_output --partial "across 3 files (2 with gaps)"
}

@test "coverage_gaps: summary shows aggregate totals" {
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
    assert_output --partial "Summary:"
    assert_output --partial "2/7 statements covered"
}

# --- Error handling ---

@test "coverage_gaps: missing file returns error" {
    exec_command() { echo "cat: coverage.xml: No such file or directory"; return 1; }
    run tool_phpunit_coverage_gaps '{}'
    assert_failure
    assert_output --partial "Cannot read clover XML"
}

# --- Method-type lines ---

@test "coverage_gaps: uncovered method name surfaced from method-type line" {
    exec_command() { echo "${SAMPLE_METHOD_LINES}"; }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
    assert_output --partial "Uncovered methods: doStuff"
    assert_output --partial "1 uncovered"
    assert_output --partial "Lines: 15"
}

# --- Header formatting ---

@test "coverage_gaps: header shows file count" {
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{}'
    assert_success
    assert_output --partial "2 files below 100%"
}

@test "coverage_gaps: header shows filter when set" {
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{"source_filter":"src/"}'
    assert_success
    assert_output --partial 'filtered by "src/"'
}

@test "coverage_gaps: singular file in header" {
    exec_command() { echo "${SAMPLE_TWO_FILES}"; }
    run tool_phpunit_coverage_gaps '{"source_filter":"Baz"}'
    assert_success
    assert_output --partial "1 file below 100%"
}
