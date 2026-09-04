#!/usr/bin/env bash
# Verify a before/after dump set is complete and identical (or only inertly
# different), and that no XML config was left behind after migration.
#
# Usage: verify-dumps.sh <dump-dir> <extension-src-root> <envs-csv>
# Prints a markdown verification table plus coexistence, leftover-reference and
# inert-diff result lines to stdout. The whole block is what the report pastes
# verbatim, so every line below the table is emitted here rather than left for
# the report author to compose.
# Exit code: 0 = every pair identical or inert, and checks (c)/(d) clean,
#            1 = a pair DIFFERS or a check found something,
#            2 = usage error, jq not found, missing dump-dir/src-root, a dump
#                from the required set missing, a dump that is not valid JSON,
#                a missing before/after counterpart, a params dump recording no
#                kernel.environment, or a recorded kernel environment that
#                contradicts its counterpart or the env its filename claims.
set -euo pipefail

temp_files=()

# Invoked via `trap` below, not a direct call -- this tool's reachability
# analysis loses track of the trap call site.
# shellcheck disable=SC2329
on_exit() {
    rm -f -- "${temp_files[@]+"${temp_files[@]}"}"
}
trap on_exit EXIT

usage() {
    printf 'usage: %s <dump-dir> <extension-src-root> <envs-csv>\n' "$(basename -- "$0")" >&2
    exit 2
}

if [ $# -ne 3 ]; then
    usage
fi

dump_dir="$1"
src_root="$2"
envs_csv="$3"
case "$dump_dir" in
    -*) dump_dir="./${dump_dir}" ;;
esac
case "$src_root" in
    -*) src_root="./${src_root}" ;;
esac

if ! command -v jq >/dev/null 2>&1; then
    printf 'jq is required but was not found in PATH\n' >&2
    exit 2
fi

# An empty csv, a leading or trailing comma, and a doubled comma all name an
# empty environment, which no dump filename can carry. `read -r -a` drops a
# trailing empty field, so the shape is rejected on the string itself.
case "$envs_csv" in
    ''|,*|*,|*,,*) usage ;;
esac

IFS=',' read -r -a envs <<< "$envs_csv"

if [ ! -d "$dump_dir" ]; then
    printf '%s: not a directory\n' "$dump_dir" >&2
    exit 2
fi

if [ ! -d "$src_root" ]; then
    printf '%s: not a directory\n' "$src_root" >&2
    exit 2
fi

# An anonymous inline service id the XML loader hoists, e.g. ".3_App\\Foo~a1b2".
readonly INERT_PATTERN='\.[0-9]+_([A-Za-z0-9_\\]+)~[a-zA-Z0-9._]+'
readonly INERT_REPLACEMENT='.@_\1~@'
# The Shopware-native filenames, boundary-anchored so e.g. "workflow.xml" or
# "old_config.xml" is never mistaken for "flow.xml" / "config.xml".
readonly NATIVE_XML_PATTERN='(^|[^A-Za-z0-9_])(config|custom-fields|flow|rule-conditions|manifest)\.xml'
readonly NATIVE_XML_BASENAME_PATTERN='^(config|custom-fields|flow|rule-conditions|manifest)\.xml$'
# The four dumps taken per environment, in report order.
readonly ARTIFACTS=(services hidden params routes)

mask_inert_ids() {
    sed -E "s/${INERT_PATTERN}/${INERT_REPLACEMENT}/g" "$1"
}

normalize_dump() {
    # normalize_dump <source-dump> <target-file>
    # The dumps arrive as raw console output; sorting object keys here is what
    # makes a before/after diff deterministic. Array order (tags, arguments)
    # is behavior and is left as emitted.
    local source_file="$1" target_file="$2"

    if jq -S . < "$source_file" > "$target_file"; then
        return 0
    fi

    printf 'verify-dumps: %s is not valid JSON\n' "$source_file" >&2
    return 2
}

find_list() {
    # find_list <path> <output-file> <find-arguments...>
    local path="$1" output_file="$2"
    shift 2

    if find "$path" "$@" > "$output_file"; then
        return 0
    fi

    printf 'verify-dumps: find failed for %s\n' "$path" >&2
    return 2
}

read_kernel_env() {
    # read_kernel_env <params-dump> — print the kernel.environment parameter the
    # dump recorded. The raw dump is read directly; a single key lookup needs no
    # normalization. Every stage's status is checked explicitly so this function
    # fails loudly regardless of the caller's context — a caller invoking it
    # inside a conditional (if/&&/||/!) disables errexit for the whole body.
    #
    # Two dump shapes are accepted, each named explicitly:
    #   1. a flat top-level map of parameter name to value, which is what the
    #      console's json parameters descriptor emits;
    #   2. the same map nested under a "parameters" key.
    # Anything else — a non-object document, or a document carrying the key in
    # neither place — is a rejection, not a default.
    local file="$1" value jq_status

    jq_status=0
    value=$(jq -r '
        if type != "object" then ""
        elif has("kernel.environment")
            and ((.["kernel.environment"] | type) != "null")
            then (.["kernel.environment"] | tostring)
        elif (.parameters | type) == "object"
            and (.parameters | has("kernel.environment"))
            and ((.parameters["kernel.environment"] | type) != "null")
            then (.parameters["kernel.environment"] | tostring)
        else ""
        end
    ' < "$file") || jq_status=$?

    if [ "$jq_status" -ne 0 ]; then
        printf 'verify-dumps: failed to read kernel.environment from %s (jq exit %s)\n' \
            "$file" "$jq_status" >&2
        return 2
    fi

    if [ -z "$value" ]; then
        printf 'verify-dumps: %s records no kernel.environment parameter; a container parameters dump always carries one\n' \
            "$file" >&2
        return 2
    fi

    printf '%s\n' "$value"
}

# --- (a0) the csv's envs each need all eight dumps of the required set ---

required_missing=()

for env in "${envs[@]}"; do
    for artifact in "${ARTIFACTS[@]}"; do
        for phase in before after; do
            required_dump="${dump_dir}/${phase}-${artifact}-${env}.json"
            [ -f "$required_dump" ] || required_missing+=("$required_dump")
        done
    done
done

if [ "${#required_missing[@]}" -gt 0 ]; then
    printf 'missing required dump: %s\n' "${required_missing[@]}" >&2
    exit 2
fi

# --- (a1) each pair's params dumps must record the environment their filename
# claims. Only the csv's envs are gated: a stray discovered pair carries no
# filename-claimed contract to check against.

for env in "${envs[@]}"; do
    before_params="${dump_dir}/before-params-${env}.json"
    after_params="${dump_dir}/after-params-${env}.json"

    if ! before_kernel_env=$(read_kernel_env "$before_params"); then
        exit 2
    fi
    if ! after_kernel_env=$(read_kernel_env "$after_params"); then
        exit 2
    fi

    if [ "$before_kernel_env" != "$after_kernel_env" ]; then
        printf 'verify-dumps: %s records kernel.environment "%s" but %s records "%s"; both dumps of a pair must come from the same environment\n' \
            "$before_params" "$before_kernel_env" "$after_params" "$after_kernel_env" >&2
        exit 2
    fi

    if [ "$env" = "default" ]; then
        # "default" is a filename label for "no environment selected", not an
        # environment name. The kernel nonetheless accepts "default" as a
        # literal name: it boots an environment nothing else configures, loads
        # no env-specific config, and exits 0 — so a dump recording
        # kernel.environment "default" certifies a container no request uses.
        if [ "$before_kernel_env" = "default" ]; then
            printf 'verify-dumps: %s and %s record kernel.environment "default"; the default row means the console ran with no environment selected, so these dumps were taken with the literal environment name "default", which boots a nonexistent environment that loads no env-specific config\n' \
                "$before_params" "$after_params" >&2
            exit 2
        fi
    else
        for params_file in "$before_params" "$after_params"; do
            if ! recorded_kernel_env=$(read_kernel_env "$params_file"); then
                exit 2
            fi
            if [ "$recorded_kernel_env" != "$env" ]; then
                printf 'verify-dumps: %s records kernel.environment "%s" but the filename claims env "%s"\n' \
                    "$params_file" "$recorded_kernel_env" "$env" >&2
                exit 2
            fi
        done
    fi
done

# --- (a) every before-*.json needs a matching after-*.json, and vice versa ---

missing=()

if ! before_files=$(mktemp "${TMPDIR:-/tmp}/verify-dumps-before-files.XXXXXX"); then
    printf 'verify-dumps: failed to create before dump list\n' >&2
    exit 2
fi
temp_files+=("$before_files")
if ! find_list "$dump_dir" "$before_files" -maxdepth 1 -type f -name 'before-*.json' -print0; then
    rm -f -- "$before_files"
    exit 2
fi
while IFS= read -r -d '' f; do
    base=$(basename -- "$f")
    suffix="${base#before-}"
    counterpart="${dump_dir}/after-${suffix}"
    [ -f "$counterpart" ] || missing+=("$counterpart")
done < "$before_files"
rm -f -- "$before_files"

if ! after_files=$(mktemp "${TMPDIR:-/tmp}/verify-dumps-after-files.XXXXXX"); then
    printf 'verify-dumps: failed to create after dump list\n' >&2
    exit 2
fi
temp_files+=("$after_files")
if ! find_list "$dump_dir" "$after_files" -maxdepth 1 -type f -name 'after-*.json' -print0; then
    rm -f -- "$after_files"
    exit 2
fi
while IFS= read -r -d '' f; do
    base=$(basename -- "$f")
    suffix="${base#after-}"
    counterpart="${dump_dir}/before-${suffix}"
    [ -f "$counterpart" ] || missing+=("$counterpart")
done < "$after_files"
rm -f -- "$after_files"

if [ "${#missing[@]}" -gt 0 ]; then
    printf 'missing counterpart dump: %s\n' "${missing[@]}" >&2
    exit 2
fi

# --- (b) diff every before/after pair and classify ---

pairs=()
declare -A seen_pairs

if ! pair_files=$(mktemp "${TMPDIR:-/tmp}/verify-dumps-pair-files.XXXXXX"); then
    printf 'verify-dumps: failed to create pair dump list\n' >&2
    exit 2
fi
temp_files+=("$pair_files")
if ! find_list "$dump_dir" "$pair_files" -maxdepth 1 -type f -name 'before-*.json' -print0; then
    rm -f -- "$pair_files"
    exit 2
fi
while IFS= read -r -d '' f; do
    base=$(basename -- "$f")
    suffix="${base#before-}"
    suffix="${suffix%.json}"
    if [ -z "${seen_pairs[$suffix]:-}" ]; then
        pairs+=("$suffix")
        seen_pairs["$suffix"]=1
    fi
done < "$pair_files"
rm -f -- "$pair_files"

declare -A env_set
if [ "${#pairs[@]}" -gt 0 ]; then
    for p in "${pairs[@]}"; do
        env_set["${p#*-}"]=1
    done
fi

envs_sorted=()
if [ -n "${env_set[default]:-}" ]; then
    envs_sorted+=(default)
    unset 'env_set[default]'
fi
if [ "${#env_set[@]}" -gt 0 ]; then
    while IFS= read -r e; do
        [ -n "$e" ] || continue
        envs_sorted+=("$e")
    done < <(printf '%s\n' "${!env_set[@]}" | sort)
fi

overall_ok=true
declare -A cells
# The changed-line count of every cell classified inert, keyed like `cells`.
# The report's `Inert diffs:` line is rendered from this, so the classification
# and the line naming it can never disagree.
declare -A inert_counts

if [ "${#pairs[@]}" -gt 0 ]; then
    for p in "${pairs[@]}"; do
        artifact="${p%%-*}"
        env="${p#*-}"
        before_file="${dump_dir}/before-${p}.json"
        after_file="${dump_dir}/after-${p}.json"

        if ! norm_before=$(mktemp "${TMPDIR:-/tmp}/verify-dumps-norm-before.XXXXXX"); then
            printf 'verify-dumps: failed to create normalized before dump\n' >&2
            exit 2
        fi
        temp_files+=("$norm_before")
        if ! norm_after=$(mktemp "${TMPDIR:-/tmp}/verify-dumps-norm-after.XXXXXX"); then
            rm -f -- "$norm_before"
            printf 'verify-dumps: failed to create normalized after dump\n' >&2
            exit 2
        fi
        temp_files+=("$norm_after")

        if ! normalize_dump "$before_file" "$norm_before"; then
            rm -f -- "$norm_before" "$norm_after"
            exit 2
        fi
        if ! normalize_dump "$after_file" "$norm_after"; then
            rm -f -- "$norm_before" "$norm_after"
            exit 2
        fi

        raw_diff_status=0
        raw_diff_output=$(diff -- "$norm_before" "$norm_after") || raw_diff_status=$?

        if [ "$raw_diff_status" -gt 1 ]; then
            rm -f -- "$norm_before" "$norm_after"
            printf 'verify-dumps: diff failed comparing %s and %s (exit %s)\n' \
                "$before_file" "$after_file" "$raw_diff_status" >&2
            exit 2
        fi

        if [ -z "$raw_diff_output" ]; then
            rm -f -- "$norm_before" "$norm_after"
            cells["${artifact}:${env}"]="identical"
            continue
        fi

        if ! masked_before=$(mktemp "${TMPDIR:-/tmp}/verify-dumps-before.XXXXXX"); then
            rm -f -- "$norm_before" "$norm_after"
            printf 'verify-dumps: failed to create masked before dump\n' >&2
            exit 2
        fi
        temp_files+=("$masked_before")
        if ! masked_after=$(mktemp "${TMPDIR:-/tmp}/verify-dumps-after.XXXXXX"); then
            rm -f -- "$norm_before" "$norm_after" "$masked_before"
            printf 'verify-dumps: failed to create masked after dump\n' >&2
            exit 2
        fi
        temp_files+=("$masked_after")

        if ! mask_inert_ids "$norm_before" > "$masked_before"; then
            rm -f -- "$norm_before" "$norm_after" "$masked_before" "$masked_after"
            printf 'verify-dumps: failed to mask %s\n' "$before_file" >&2
            exit 2
        fi
        if ! mask_inert_ids "$norm_after" > "$masked_after"; then
            rm -f -- "$norm_before" "$norm_after" "$masked_before" "$masked_after"
            printf 'verify-dumps: failed to mask %s\n' "$after_file" >&2
            exit 2
        fi

        masked_diff_status=0
        masked_diff_output=$(diff -- "$masked_before" "$masked_after") || masked_diff_status=$?

        if [ "$masked_diff_status" -gt 1 ]; then
            rm -f -- "$norm_before" "$norm_after" "$masked_before" "$masked_after"
            printf 'verify-dumps: diff failed comparing masked %s and %s (exit %s)\n' \
                "$before_file" "$after_file" "$masked_diff_status" >&2
            exit 2
        fi

        if [ -z "$masked_diff_output" ]; then
            count_status=0
            changed_line_count=$(printf '%s\n' "$raw_diff_output" | grep -cE '^[<>] ') || count_status=$?
            if [ "$count_status" -gt 1 ]; then
                rm -f -- "$norm_before" "$norm_after" "$masked_before" "$masked_after"
                printf 'verify-dumps: grep failed counting changed lines for %s\n' "$before_file" >&2
                exit 2
            fi
            cells["${artifact}:${env}"]="inert (${changed_line_count} changed lines)"
            inert_counts["${artifact}:${env}"]="$changed_line_count"
        else
            cells["${artifact}:${env}"]="DIFFERS"
            overall_ok=false
        fi

        rm -f -- "$norm_before" "$norm_after" "$masked_before" "$masked_after"
    done
fi

# --- (c) coexistence: no directory may keep XML with a same-basename replacement ---

coexist_findings=()

if ! xml_files=$(mktemp "${TMPDIR:-/tmp}/verify-dumps-xml-files.XXXXXX"); then
    printf 'verify-dumps: failed to create XML config list\n' >&2
    exit 2
fi
temp_files+=("$xml_files")
if ! find_list "$src_root" "$xml_files" -type f -path '*/Resources/config/*.xml' -print0; then
    rm -f -- "$xml_files"
    exit 2
fi
while IFS= read -r -d '' xmlfile; do
    dir=$(dirname -- "$xmlfile")
    base=$(basename -- "$xmlfile")
    stem="${base%.xml}"
    # The exclusion keys on the parent directory being any */Resources/config
    # — a nested bundle's own Resources/config is such a directory too, so a
    # native basename there is excluded the same as at the top level. Only a
    # subdirectory below Resources/config (packages/, routes/) stays in
    # scope for that basename.
    if [[ "$base" =~ $NATIVE_XML_BASENAME_PATTERN ]]; then
        case "$dir" in
            */Resources/config) continue ;;
        esac
    fi
    for replacement_extension in php yaml yml; do
        replacement_file="${dir}/${stem}.${replacement_extension}"
        if [ -f "$replacement_file" ]; then
            coexist_findings+=("$replacement_file alongside $xmlfile")
        fi
    done
done < "$xml_files"
rm -f -- "$xml_files"

if [ "${#coexist_findings[@]}" -gt 0 ]; then
    overall_ok=false
fi

# --- (d) leftover .xml references in migrated PHP ---

if ! leftover_matches=$(mktemp "${TMPDIR:-/tmp}/verify-dumps-leftover-matches.XXXXXX"); then
    printf 'verify-dumps: failed to create leftover reference list\n' >&2
    exit 2
fi
temp_files+=("$leftover_matches")
if ! leftover_filtered=$(mktemp "${TMPDIR:-/tmp}/verify-dumps-leftover-filtered.XXXXXX"); then
    rm -f -- "$leftover_matches"
    printf 'verify-dumps: failed to create filtered leftover reference list\n' >&2
    exit 2
fi
temp_files+=("$leftover_filtered")

if grep -rn --include='*.php' '\.xml' -- "$src_root" > "$leftover_matches"; then
    grep_status=0
else
    grep_status=$?
fi
if [ "$grep_status" -gt 1 ]; then
    rm -f -- "$leftover_matches" "$leftover_filtered"
    printf 'verify-dumps: grep failed for %s\n' "$src_root" >&2
    exit 2
fi

if grep -vE "$NATIVE_XML_PATTERN" "$leftover_matches" > "$leftover_filtered"; then
    filter_status=0
else
    filter_status=$?
fi
if [ "$filter_status" -gt 1 ]; then
    rm -f -- "$leftover_matches" "$leftover_filtered"
    printf 'verify-dumps: grep failed while filtering %s\n' "$src_root" >&2
    exit 2
fi

leftover_findings=$(< "$leftover_filtered")
rm -f -- "$leftover_matches" "$leftover_filtered"

if [ -n "$leftover_findings" ]; then
    overall_ok=false
fi

# --- inert-diff summary, in the table's own order: artifact rows outer,
# environment columns inner ---

inert_cells=()

for artifact in "${ARTIFACTS[@]}"; do
    if [ "${#envs_sorted[@]}" -gt 0 ]; then
        for e in "${envs_sorted[@]}"; do
            inert_count="${inert_counts[${artifact}:${e}]:-}"
            [ -n "$inert_count" ] || continue
            inert_cells+=("${artifact}/${e} (${inert_count} changed lines)")
        done
    fi
done

inert_summary="none"
if [ "${#inert_cells[@]}" -gt 0 ]; then
    inert_summary=""
    for inert_cell in "${inert_cells[@]}"; do
        if [ -z "$inert_summary" ]; then
            inert_summary="$inert_cell"
        else
            inert_summary="${inert_summary}, ${inert_cell}"
        fi
    done
fi

# --- report ---

{
    printf '| Artifact |'
    if [ "${#envs_sorted[@]}" -gt 0 ]; then
        for e in "${envs_sorted[@]}"; do
            printf ' %s |' "$e"
        done
    fi
    printf '\n|---|'
    if [ "${#envs_sorted[@]}" -gt 0 ]; then
        for _ in "${envs_sorted[@]}"; do
            printf -- '---|'
        done
    fi
    printf '\n'

    for artifact in "${ARTIFACTS[@]}"; do
        printf '| %s |' "$artifact"
        if [ "${#envs_sorted[@]}" -gt 0 ]; then
            for e in "${envs_sorted[@]}"; do
                cell="${cells[${artifact}:${e}]:-n/a}"
                printf ' %s |' "$cell"
            done
        fi
        printf '\n'
    done

    if [ "${#coexist_findings[@]}" -gt 0 ]; then
        printf 'Coexistence check: FINDINGS\n'
        printf -- '- %s\n' "${coexist_findings[@]}"
    else
        printf 'Coexistence check: clean\n'
    fi

    if [ -n "$leftover_findings" ]; then
        printf 'Leftover XML references: FINDINGS\n'
        printf '%s\n' "$leftover_findings" | sed 's/^/- /'
    else
        printf 'Leftover XML references: clean\n'
    fi

    printf 'Inert diffs: %s\n' "$inert_summary"
}

if [ "$overall_ok" = true ]; then
    exit 0
fi
exit 1
