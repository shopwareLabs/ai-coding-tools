#!/usr/bin/env bash
# PHPUnit coverage gap analysis tool for MCP server
# Parses Clover XML reports to identify uncovered lines and methods

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

# tool_phpunit_coverage_gaps - MCP tool function
# Args: $1 = JSON arguments
# Returns: Human-readable coverage gap report
tool_phpunit_coverage_gaps() {
    local args="$1"

    local parsed
    parsed=$(echo "${args}" | jq -c '{
        clover_path: (.clover_path // "coverage.xml"),
        source_filter: (.source_filter // "")
    }' 2>/dev/null || echo '{"clover_path":"coverage.xml","source_filter":""}')

    local clover_path source_filter
    clover_path=$(echo "${parsed}" | jq -r '.clover_path')
    source_filter=$(echo "${parsed}" | jq -r '.source_filter')

    log "INFO" "Coverage gaps: clover_path='${clover_path}' source_filter='${source_filter}'"

    # Read clover XML via exec_command (handles Docker/Vagrant/DDEV)
    local xml_content exit_code=0
    xml_content=$(exec_command "cat '${clover_path}'") || exit_code=$?

    if [[ ${exit_code} -ne 0 ]]; then
        echo "Error: Cannot read clover XML at '${clover_path}'"
        [[ -n "${xml_content}" ]] && echo "${xml_content}"
        return 1
    fi

    # Parse clover XML with awk.
    # FS='"' splits on double-quote so attribute values land at even field positions.
    # For <line num="37" type="stmt" count="0"/>: $2=37, $4=stmt, $6=0
    # For <line num="42" type="method" name="foo" ... count="0"/>: $4=method, $6=name, $14=count
    # For <file name="/path">: $2=/path
    # For <metrics ... statements="N" coveredstatements="M" ...>: iterate fields
    # Outputs pipe-delimited gap lines: pct|uncov_count|stmts|covered|filepath|ranges|methods
    # Outputs summary line prefixed with #: #total_files|total_stmts|total_covered
    local awk_output
    awk_output=$(echo "${xml_content}" | awk -v filter="${source_filter}" -v workdir="${LINT_WORKDIR}" '
BEGIN {
    FS = "\""
    file = ""
    total_files = 0
    grand_stmts = 0
    grand_covered = 0
}

/<file name=/ {
    file = $2
    sub("^" workdir "/", "", file)
    uncov_count = 0
    uncov_lines = ""
    uncov_methods = ""
    stmts = 0
    covered = 0
}

/<line / && file != "" {
    if ($4 == "stmt" && $6 == "0") {
        uncov_count++
        if (uncov_lines != "") uncov_lines = uncov_lines "," $2
        else uncov_lines = $2
    } else if ($4 == "method" && $14 == "0") {
        if (uncov_methods != "") uncov_methods = uncov_methods ", " $6
        else uncov_methods = $6
    }
}

/<metrics / && file != "" {
    for (i = 1; i <= NF; i++) {
        if ($i ~ /coveredstatements=/) { covered = $(i+1) + 0 }
        else if ($i ~ / statements=/) { stmts = $(i+1) + 0 }
    }
}

/<\/file>/ && file != "" {
    if (filter == "" || index(file, filter) > 0) {
        if (stmts > 0) {
            total_files++
            grand_stmts += stmts
            grand_covered += covered

            if (covered < stmts) {
                pct = covered / stmts * 100

                # Group consecutive line numbers into ranges
                n = split(uncov_lines, parts, ",")
                ranges = ""
                if (n > 0) {
                    rs = parts[1] + 0
                    re = rs
                    for (j = 2; j <= n; j++) {
                        val = parts[j] + 0
                        if (val == re + 1) {
                            re = val
                        } else {
                            if (ranges != "") ranges = ranges ", "
                            if (rs == re) ranges = ranges rs
                            else ranges = ranges rs "-" re
                            rs = val
                            re = val
                        }
                    }
                    if (ranges != "") ranges = ranges ", "
                    if (rs == re) ranges = ranges rs
                    else ranges = ranges rs "-" re
                }

                printf "%.1f|%d|%d|%d|%s|%s|%s\n", pct, uncov_count, stmts, covered, file, ranges, uncov_methods
            }
        }
    }
    file = ""
}

END {
    printf "#%d|%d|%d\n", total_files, grand_stmts, grand_covered
}
')

    # Separate summary metadata (line starting with #) from gap lines
    local parsed_lines summary_line
    summary_line=$(echo "${awk_output}" | tail -1)
    parsed_lines=$(echo "${awk_output}" | sed '$d')

    # Parse summary metadata: #total_files|total_stmts|total_covered
    local awk_total_files awk_total_stmts awk_total_covered
    awk_total_files=$(echo "${summary_line}" | cut -d'|' -f1 | tr -d '#')
    awk_total_stmts=$(echo "${summary_line}" | cut -d'|' -f2)
    awk_total_covered=$(echo "${summary_line}" | cut -d'|' -f3)

    # Handle empty results (no files with gaps)
    if [[ -z "${parsed_lines}" ]]; then
        if [[ -n "${source_filter}" ]] && [[ "${awk_total_files}" -eq 0 ]]; then
            echo "No files matching filter '${source_filter}'."
        elif [[ "${awk_total_files}" -gt 0 ]]; then
            local file_word="files"
            [[ "${awk_total_files}" -eq 1 ]] && file_word="file"
            echo "All ${awk_total_files} ${file_word} have 100% statement coverage."
        else
            echo "No files with uncovered lines."
        fi
        return 0
    fi

    # Sort by coverage % ascending (worst first) and format output
    local file_count=0
    local output=""

    while IFS='|' read -r pct uncov stmts covered filepath ranges methods; do
        file_count=$((file_count + 1))
        output+=$(printf "\n%6.1f%% (%2d uncovered)  %s\n" "${pct}" "${uncov}" "${filepath}")
        [[ -n "${methods}" ]] && output+=$(printf "   Uncovered methods: %s\n" "${methods}")
        output+=$(printf "   Lines: %s\n" "${ranges}")
    done < <(echo "${parsed_lines}" | sort -t'|' -k1,1n)

    # Header
    local header="Coverage Gaps (${file_count} file"
    [[ ${file_count} -ne 1 ]] && header+="s"
    header+=" below 100%"
    [[ -n "${source_filter}" ]] && header+=", filtered by \"${source_filter}\""
    header+=")"

    echo "${header}"
    echo "${output}"

    # Summary
    local total_pct="0.0"
    if [[ ${awk_total_stmts} -gt 0 ]]; then
        total_pct=$(awk "BEGIN { printf \"%.1f\", ${awk_total_covered}/${awk_total_stmts}*100 }")
    fi
    echo ""
    echo "Summary: ${awk_total_covered}/${awk_total_stmts} statements covered (${total_pct}%) across ${awk_total_files} files (${file_count} with gaps)"
}
