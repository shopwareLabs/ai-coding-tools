#!/usr/bin/env bash
# Measure Markdown documentation surfaces against size budgets and
# cross-reference rules. Reports only; never modifies a file.
set -euo pipefail

# Byte-deterministic awk: length() and character classes are locale-dependent,
# and raw sizes are measured in bytes (wc -c), so awk must count bytes too.
export LC_ALL=C

TAB=$'\t'

MODE=''
STRICT=0
GOAL=5000
LIMIT=6500
CEILING=10000
MAX_INDEX_ROWS=20
RUN_TMP=''
TOTAL_FINDINGS=0
ANCHOR_CACHE_KEY=''

usage() {
    printf '%s\n' \
        'usage: measure.sh <mode> [flags] PATH [PATH ...]' \
        '  mode    size | links | all' \
        '  flags   --strict --goal N --limit N --ceiling N --max-index-rows N' >&2
    exit 2
}

# shellcheck disable=SC2329  # invoked from the EXIT trap set in main
cleanup() {
    if [[ -n "${RUN_TMP}" ]] && [[ -d "${RUN_TMP}" ]]; then
        rm -rf -- "${RUN_TMP}"
    fi
}

# --- shared awk helpers -----------------------------------------------------
#
# Portable awk only: no gensub, no capture-group array from match(), no
# regex intervals. Sub-expressions are recovered with index()/substr().

AWK_LIB='
function slug(text,   t) {
    t = text
    gsub(/`/, "", t)
    sub(/^[ \t]+/, "", t)
    sub(/[ \t]+$/, "", t)
    t = tolower(t)
    gsub(/[^a-z0-9_ \t-]/, "", t)
    gsub(/[ \t]+/, "-", t)
    return t
}

# Sets HEAD_OK to 1 and returns the anchor slug when line is an ATX heading.
function heading_slug(line,   n, t) {
    HEAD_OK = 0
    if (line !~ /^#+[ \t]/) { return "" }
    n = 0
    while (substr(line, n + 1, 1) == "#") { n = n + 1 }
    if (n > 6) { return "" }
    t = substr(line, n + 1)
    sub(/[ \t]+$/, "", t)
    sub(/#+$/, "", t)
    sub(/^[ \t]+/, "", t)
    sub(/[ \t]+$/, "", t)
    HEAD_OK = 1
    return slug(t)
}

# Finds the first Markdown link in s at or after position from.
# Sets G_START, G_LEN, G_TARGET, G_ANCHOR. Returns 1 when one was found.
function find_link(s, from,   rest, inner, p, hashpos) {
    G_START = 0
    G_LEN = 0
    G_TARGET = ""
    G_ANCHOR = ""
    rest = substr(s, from)
    if (match(rest, /\[[^]]*\]\([ \t]*[^) \t#]*(#[^) \t]*)?[ \t]*\)/) == 0) { return 0 }
    G_START = from + RSTART - 1
    G_LEN = RLENGTH
    inner = substr(rest, RSTART, RLENGTH)
    p = index(inner, "](")
    inner = substr(inner, p + 2, length(inner) - p - 2)
    sub(/^[ \t]+/, "", inner)
    sub(/[ \t]+$/, "", inner)
    hashpos = index(inner, "#")
    if (hashpos > 0) {
        G_TARGET = substr(inner, 1, hashpos - 1)
        G_ANCHOR = substr(inner, hashpos + 1)
    } else {
        G_TARGET = inner
    }
    return 1
}

function strip_links(s,   out, pos) {
    out = ""
    pos = 1
    while (pos <= length(s) && find_link(s, pos)) {
        out = out substr(s, pos, G_START - pos)
        pos = G_START + G_LEN
    }
    return out substr(s, pos)
}

function has_md_link(line,   pos) {
    pos = 1
    while (pos <= length(line) && find_link(line, pos)) {
        if (G_TARGET ~ /\.md$/) { return 1 }
        pos = G_START + G_LEN
    }
    return 0
}

# A list item or table row carrying one Markdown link plus at most one sentence.
function is_routing_row(line,   prose, hits) {
    if (line !~ /^[ \t]*([-*+][ \t]+|[0-9]+\.[ \t]+|\|)/) { return 0 }
    if (!has_md_link(line)) { return 0 }
    prose = strip_links(line)
    gsub(/[-|*+`]/, " ", prose)
    sub(/^[ \t]+/, "", prose)
    sub(/[ \t]+$/, "", prose)
    prose = prose " "
    hits = gsub(/[.!?][ \t]/, "", prose)
    return (hits <= 1)
}
'

# shellcheck disable=SC2016  # awk source: $0 and backticks are awk syntax
AWK_SIZE='
function scan_markers(   rest, c, term_pos, consumer) {
    if (!exempt && match($0, /<!--[ \t]*size-exempt:[ \t]*/)) {
        rest = substr($0, RSTART + RLENGTH)
        term_pos = index(rest, "-->")
        if (term_pos > 0) {
            consumer = substr(rest, 1, term_pos - 1)
            sub(/[ \t]+$/, "", consumer)
            if (consumer != "") { exempt = 1 }
        }
    }
    if (crit == "" && match($0, /<!--[ \t]*size-allowance:[ \t]*/)) {
        rest = substr($0, RSTART + RLENGTH)
        c = ""
        if (rest ~ /^lookup([^a-zA-Z0-9_]|$)/) { c = "lookup" }
        else if (rest ~ /^contiguous([^a-zA-Z0-9_]|$)/) { c = "contiguous" }
        else if (rest ~ /^atomic([^a-zA-Z0-9_]|$)/) { c = "atomic" }
        if (c != "" && index(substr(rest, length(c) + 1), "-->") > 0) { crit = c }
    }
}
BEGIN { fenced = 0; rows = 0; delta = 0; exempt = 0; crit = "" }
{
    if ($0 ~ /^[ \t]*```/) { fenced = 1 - fenced; next }
    if (fenced) { next }
    scan_markers()
    if (is_routing_row($0)) {
        rows = rows + 1
        delta = delta + length($0) + 1
    }
}
END { printf "%d %d %d %s\n", rows, delta, exempt, crit }
'

# shellcheck disable=SC2016  # awk source: $0 and backticks are awk syntax
AWK_LINKS='
function scan_bare(s, lineno,   pos, rest, span, bare) {
    pos = 1
    while (pos <= length(s)) {
        rest = substr(s, pos)
        if (match(rest, /`[^`]*\.md`/) == 0) { return }
        span = substr(rest, RSTART, RLENGTH)
        bare = substr(span, 2, length(span) - 2)
        pos = pos + RSTART + RLENGTH - 1
        if (bare ~ /[<>*{}]/ || bare ~ /[ \t]/) { continue }
        printf "B\t%d\t%s\t\n", lineno, bare
    }
}
BEGIN { fenced = 0 }
{
    if ($0 ~ /^[ \t]*```/) { fenced = 1 - fenced; next }
    if (fenced) { next }
    pos = 1
    while (pos <= length($0) && find_link($0, pos)) {
        pos = G_START + G_LEN
        if (G_TARGET ~ /^https?:\/\//) { continue }
        if (G_TARGET ~ /^mailto:/) { continue }
        if (G_TARGET != "" && G_TARGET !~ /\.md$/) { continue }
        printf "L\t%d\t%s\t%s\n", NR, G_TARGET, G_ANCHOR
    }
    scan_bare(strip_links($0), NR)
}
'

# shellcheck disable=SC2016  # awk source: $0 is an awk field reference
AWK_ANCHORS='
BEGIN { fenced = 0 }
{
    if ($0 ~ /^[ \t]*```/) { fenced = 1 - fenced; next }
    if (fenced) { next }
    found = heading_slug($0)
    if (HEAD_OK) { print found }
}
'

# shellcheck disable=SC2016  # awk source: $0 is an awk field reference
AWK_SLUG='
{ print slug($0) }
'

# --- argument parsing -------------------------------------------------------

require_number() {
    case "${1:-}" in
        '' | *[!0-9]*) usage ;;
    esac
}

parse_args() {
    [[ "$#" -ge 1 ]] || usage
    MODE="$1"
    shift
    case "${MODE}" in
        size | links | all) ;;
        *) usage ;;
    esac

    local paths
    paths=()
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --strict)
                STRICT=1
                shift
                ;;
            --goal)
                shift
                require_number "${1:-}"
                GOAL=$((10#$1))
                shift
                ;;
            --limit)
                shift
                require_number "${1:-}"
                LIMIT=$((10#$1))
                shift
                ;;
            --ceiling)
                shift
                require_number "${1:-}"
                CEILING=$((10#$1))
                shift
                ;;
            --max-index-rows)
                shift
                require_number "${1:-}"
                MAX_INDEX_ROWS=$((10#$1))
                shift
                ;;
            --)
                shift
                while [[ "$#" -gt 0 ]]; do
                    paths+=("$1")
                    shift
                done
                ;;
            -*)
                usage
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done

    [[ "${#paths[@]}" -gt 0 ]] || usage

    local missing
    missing=''
    local candidate
    for candidate in "${paths[@]}"; do
        if [[ ! -e "${candidate}" ]]; then
            if [[ -n "${missing}" ]]; then
                missing="${missing}, ${candidate}"
            else
                missing="${candidate}"
            fi
        fi
    done
    if [[ -n "${missing}" ]]; then
        printf 'path does not exist: %s\n' "${missing}" >&2
        exit 2
    fi

    for candidate in "${paths[@]}"; do
        if [[ -f "${candidate}" ]]; then
            case "${candidate}" in
                *.md) printf '%s\n' "${candidate}" >> "${RUN_TMP}/scope" ;;
            esac
        else
            local scan_root="${candidate}"
            case "${scan_root}" in
                -*) scan_root="./${scan_root}" ;;
            esac
            find "${scan_root}" -type f -name '*.md' | LC_ALL=C sort >> "${RUN_TMP}/scope"
        fi
    done
}

# --- size mode --------------------------------------------------------------

size_mode() {
    local rows_file="${RUN_TMP}/size_rows"
    local findings_file="${RUN_TMP}/size_findings"
    local order_file="${RUN_TMP}/size_order"
    : > "${rows_file}"
    : > "${findings_file}"

    local index=0
    local surfaces=0
    local file
    while IFS= read -r file; do
        index=$((index + 1))
        surfaces=$((surfaces + 1))

        local raw
        raw="$(wc -c < "${file}" | tr -d ' ')"

        local parsed
        parsed="$(awk "${AWK_LIB}${AWK_SIZE}" < "${file}")"
        local rows delta exempt criterion
        # criterion is last so an empty value cannot swallow another field.
        read -r rows delta exempt criterion <<< "${parsed}"
        criterion="${criterion:-}"

        local base
        base="$(basename -- "${file}")"
        local counted
        if [[ "${base}" == 'AGENTS.md' ]] || [[ "${base}" == 'CLAUDE.md' ]]; then
            counted="${raw}"
        else
            counted=$((raw - delta))
        fi

        local verdict
        local finding_seq=0
        if [[ "${exempt}" -eq 1 ]]; then
            verdict='exempt'
            # An allowance criterion, when the file also carries one, outranks
            # the bare `parsed` marker of an exemption.
            if [[ -z "${criterion}" ]]; then
                criterion='parsed'
            fi
        elif [[ "${counted}" -le "${GOAL}" ]]; then
            verdict='goal'
        elif [[ "${counted}" -le "${LIMIT}" ]]; then
            verdict='allowed'
        elif [[ "${counted}" -le "${CEILING}" ]]; then
            verdict='allowance'
            if [[ -z "${criterion}" ]]; then
                finding_seq=$((finding_seq + 1))
                printf '%s\t%s\t%s\t%s chars above the %s limit with no allowance marker\n' \
                    "${index}" "${finding_seq}" "${file}" "${counted}" "${LIMIT}" >> "${findings_file}"
            fi
        else
            verdict='over'
            finding_seq=$((finding_seq + 1))
            printf '%s\t%s\t%s\t%s chars above the %s ceiling; splits regardless of any marker\n' \
                "${index}" "${finding_seq}" "${file}" "${counted}" "${CEILING}" >> "${findings_file}"
        fi

        if [[ "${rows}" -gt "${MAX_INDEX_ROWS}" ]]; then
            finding_seq=$((finding_seq + 1))
            printf '%s\t%s\t%s\t%s routing rows above the %s maximum\n' \
                "${index}" "${finding_seq}" "${file}" "${rows}" "${MAX_INDEX_ROWS}" >> "${findings_file}"
        fi

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "${counted}" "${index}" "${raw}" "${rows}" "${verdict}" "${criterion}" "${file}" >> "${rows_file}"
    done < "${RUN_TMP}/scope"

    printf '%8s %8s %5s  %-10s %-11s %s\n' 'counted' 'raw' 'rows' 'verdict' 'criterion' 'path'
    sort -t"${TAB}" -k1,1nr -k2,2n "${rows_file}" > "${order_file}"
    awk -F'\t' '{ printf "%8s %8s %5s  %-10s %-11s %s\n", $1, $3, $4, $5, $6, $7 }' "${order_file}"

    local finding_count
    finding_count="$(wc -l < "${findings_file}" | tr -d ' ')"

    local plural='s'
    if [[ "${surfaces}" -eq 1 ]]; then
        plural=''
    fi
    printf '\n%s surface%s measured, %s findings\n' "${surfaces}" "${plural}" "${finding_count}"

    if [[ -s "${findings_file}" ]]; then
        cut -d"${TAB}" -f2 "${order_file}" > "${RUN_TMP}/size_rank"
        awk -F'\t' 'NR == FNR { rank[$1] = FNR; next } { print rank[$1] "\t" $2 "\t" $3 "\t" $4 }' \
            "${RUN_TMP}/size_rank" "${findings_file}" \
            | sort -t"${TAB}" -k1,1n -k2,2n \
            | awk -F'\t' '{ printf "  %s: %s\n", $3, $4 }'
    fi

    TOTAL_FINDINGS=$((TOTAL_FINDINGS + finding_count))
}

# --- links mode -------------------------------------------------------------

load_anchors() {
    local destination="$1"
    if [[ "${destination}" == "${ANCHOR_CACHE_KEY}" ]]; then
        return 0
    fi
    awk "${AWK_LIB}${AWK_ANCHORS}" < "${destination}" > "${RUN_TMP}/anchors"
    ANCHOR_CACHE_KEY="${destination}"
}

slug_of() {
    printf '%s\n' "$1" | awk "${AWK_LIB}${AWK_SLUG}"
}

links_mode() {
    local findings_file="${RUN_TMP}/link_findings"
    : > "${findings_file}"
    local scanned=0
    local seen=0
    local resolved=0

    local file
    while IFS= read -r file; do
        scanned=$((scanned + 1))
        local dir
        dir="$(dirname -- "${file}")"

        awk "${AWK_LIB}${AWK_LINKS}" < "${file}" > "${RUN_TMP}/link_records"

        local record kind lineno first second rest
        # Split on tabs by hand: a tab is IFS whitespace, so `read` would
        # collapse the empty target of a same-file anchor into its neighbour.
        while IFS= read -r record; do
            kind="${record%%"${TAB}"*}"
            rest="${record#*"${TAB}"}"
            lineno="${rest%%"${TAB}"*}"
            rest="${rest#*"${TAB}"}"
            first="${rest%%"${TAB}"*}"
            second="${rest#*"${TAB}"}"

            if [[ "${kind}" == 'B' ]]; then
                local where='DOES NOT RESOLVE'
                if [[ -f "${dir}/${first}" ]]; then
                    where='resolves'
                fi
                # shellcheck disable=SC2016  # the backticks are literal report text
                printf '  %s:%s: bare path is not a cross-reference (%s): `%s`\n' \
                    "${file}" "${lineno}" "${where}" "${first}" >> "${findings_file}"
                continue
            fi

            seen=$((seen + 1))
            local destination
            if [[ -z "${first}" ]]; then
                destination="${file}"
            else
                destination="${dir}/${first}"
            fi
            if [[ ! -f "${destination}" ]]; then
                printf '  %s:%s: link target does not exist: %s\n' \
                    "${file}" "${lineno}" "${first}" >> "${findings_file}"
                continue
            fi
            resolved=$((resolved + 1))

            if [[ -z "${second}" ]]; then
                continue
            fi
            load_anchors "${destination}"
            if ! grep -qxF -- "${second}" "${RUN_TMP}/anchors"; then
                printf '  %s:%s: anchor not found in %s: #%s\n' \
                    "${file}" "${lineno}" "${first}" "${second}" >> "${findings_file}"
                continue
            fi
            if [[ -z "${first}" ]]; then
                continue
            fi
            local stem
            stem="$(basename -- "${destination}")"
            stem="${stem%.md}"
            stem="${stem//-/ }"
            local stem_slug
            stem_slug="$(slug_of "${stem}")"
            if [[ "${second}" == "${stem_slug}" ]]; then
                printf '  %s:%s: anchor restates the target file: #%s\n' \
                    "${file}" "${lineno}" "${second}" >> "${findings_file}"
            fi
        done < "${RUN_TMP}/link_records"
    done < "${RUN_TMP}/scope"

    # Known-positive guard: zero citations seen means the sweep itself is broken,
    # which no clean tree can be distinguished from.
    if [[ "${seen}" -eq 0 ]]; then
        printf 'FIXTURE FAILURE: no citation matched anywhere in scope\n' >&2
        printf '  .:0: sweep matched nothing; the check itself is broken\n'
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + 1))
        return 0
    fi

    local finding_count
    finding_count="$(wc -l < "${findings_file}" | tr -d ' ')"
    printf '%s files scanned, %s citations found, %s resolved, %s findings\n' \
        "${scanned}" "${seen}" "${resolved}" "${finding_count}"
    if [[ -s "${findings_file}" ]]; then
        cat "${findings_file}"
    fi

    TOTAL_FINDINGS=$((TOTAL_FINDINGS + finding_count))
}

# --- entry point ------------------------------------------------------------

main() {
    trap cleanup EXIT
    RUN_TMP="$(mktemp -d "${TMPDIR:-/tmp}/measure-sh.XXXXXX")"
    : > "${RUN_TMP}/scope"

    parse_args "$@"

    case "${MODE}" in
        size)
            size_mode
            ;;
        links)
            links_mode
            ;;
        all)
            size_mode
            printf '\n'
            links_mode
            ;;
    esac

    if [[ "${STRICT}" -eq 1 ]] && [[ "${TOTAL_FINDINGS}" -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
