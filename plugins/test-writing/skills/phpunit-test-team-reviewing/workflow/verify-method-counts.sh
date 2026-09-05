#!/usr/bin/env bash
# verify-method-counts.sh — deterministic re-count of a Phase-1 manifest-core's
# test methods before the manifest freezes.
#
# The per-file extraction subagents (input-resolution.md §Per-File Extraction)
# self-report `method_count` and `test_methods` by reading their own file — a
# subagent-produced count is provisional, not a source of truth. This script
# re-derives both fields deterministically by grepping the file on disk for
# every `public function test*` declaration, in file order, and REPLACES a
# mismatching entry's `method_count`/`test_methods` with the extracted values.
# A corrected entry is a successful run, not a partial one; only a missing
# entry file or invalid input JSON is a hard failure.
#
# Usage: verify-method-counts.sh <manifest.json> <repo_root>
#   manifest.json  Phase-1 manifest-core JSON: an array of entries, each with
#                   at least `path`, `method_count`, `test_methods`
#   repo_root      repo root of the project under review; entry `path` values
#                   are resolved relative to it
#
# Writes the corrected manifest JSON to stdout. Writes one line per corrected
# entry to stderr: "verify-method-counts: <path>: method_count <old> -> <new>".
# Exit 0 on success (corrected mismatches included). Non-zero, with a message
# on stderr, when an entry's file is missing or the input is not valid JSON —
# never a silent skip and never a best-guess count.
#
# Sourcing this file defines the functions without running main, so a bats
# suite can exercise them directly. Functions use explicit `|| return 1` so
# they fail correctly whether or not errexit is active in the sourcing shell.

# assert_valid_manifest <manifest_file>
# Fail (return 1) unless the file exists, is valid JSON, and its top level is
# an array — a syntactically valid non-array (e.g. `{}`) would otherwise pass
# `jq empty`, iterate zero times below, and print back unchanged as if it were
# a valid empty manifest.
assert_valid_manifest() {
    local manifest_file="$1"
    if [[ ! -f "${manifest_file}" ]]; then
        printf 'verify-method-counts: manifest file not found: %s\n' "${manifest_file}" >&2
        return 1
    fi
    if ! jq empty -- "${manifest_file}" 2>/dev/null; then
        printf 'verify-method-counts: manifest file is not valid JSON: %s\n' "${manifest_file}" >&2
        return 1
    fi
    if [[ "$(jq -r 'type' -- "${manifest_file}")" != "array" ]]; then
        printf 'verify-method-counts: manifest file top level is not an array: %s\n' "${manifest_file}" >&2
        return 1
    fi
}

# The jq program applied to the whole manifest array by assert_valid_manifest_entries. Emits
# one line per invalid entry: "entry <index> (<path or '<no path>'>): <field violation>; ...".
# `path`/`method_count`/`test_methods` come from an extraction contract that fixes their
# types; a wrongly-typed field means the manifest is corrupted, not merely miscounted.
_VERIFY_METHOD_COUNTS_ENTRY_CHECK_JQ=$(cat <<'EOF'
def path_errors($v):
  if ($v | has("path") | not) then ["path missing"]
  elif ($v.path | type) != "string" then ["path is not a string"]
  elif ($v.path | length) == 0 then ["path is empty"]
  else [] end;
def method_count_errors($v):
  if ($v | has("method_count") | not) then ["method_count missing"]
  elif ($v.method_count | type) != "number" then ["method_count is not a number"]
  else [] end;
def test_methods_errors($v):
  if ($v | has("test_methods") | not) then ["test_methods missing"]
  elif ($v.test_methods | type) != "array" then ["test_methods is not an array"]
  elif ([$v.test_methods[] | type != "string"] | any) then ["test_methods contains a non-string element"]
  else [] end;
to_entries[] as $e
| ($e.key) as $idx | ($e.value) as $v
| (path_errors($v) + method_count_errors($v) + test_methods_errors($v)) as $errs
| select(($errs | length) > 0)
| "entry \($idx) (\($v.path // "<no path>")): " + ($errs | join("; "))
EOF
)

# assert_valid_manifest_entries <manifest_file>
# Fail (return 1) unless every entry has a non-empty string `path`, a numeric
# `method_count`, and a `test_methods` array of strings. A wrongly-typed field
# (e.g. `method_count: "three"`) means the manifest is corrupted — this is a
# hard failure, never a silent "correction".
assert_valid_manifest_entries() {
    local manifest_file="$1"
    local violations
    violations=$(jq -r "${_VERIFY_METHOD_COUNTS_ENTRY_CHECK_JQ}" -- "${manifest_file}") || return 1
    if [[ -n "${violations}" ]]; then
        local line
        while IFS= read -r line; do
            printf 'verify-method-counts: invalid manifest entry: %s\n' "${line}" >&2
        done <<< "${violations}"
        return 1
    fi
}

# extract_test_methods_json <file>
# Print the file's `public function test*` method names, in file order, as a
# JSON array of strings. Pattern-based (no PHP parsing), matching the same
# `public function test*` convention input-resolution.md defines for the
# subagent extraction this script re-checks.
# `grep` exits 1 on a legitimate zero-match file (e.g. a data-provider-only
# helper) and >1 on a real read error (unreadable file, I/O failure) — the two
# are distinguished explicitly so a read error fails hard instead of silently
# producing a false `method_count: 0`.
extract_test_methods_json() {
    local file="$1"
    local raw grep_status names
    raw=$(grep -oE 'public[[:space:]]+function[[:space:]]+test[A-Za-z0-9_]+' -- "${file}") && grep_status=0 || grep_status=$?
    if [[ "${grep_status}" -gt 1 ]]; then
        printf 'verify-method-counts: grep failed reading %s (exit %s)\n' "${file}" "${grep_status}" >&2
        return 1
    fi
    names=$(printf '%s' "${raw}" | sed -E 's/^public[[:space:]]+function[[:space:]]+//') || return 1
    printf '%s' "${names}" | jq -R -s 'split("\n") | map(select(length > 0))' || return 1
}

# verify_method_counts <manifest_file> <repo_root>
# Re-count every entry and print the corrected manifest JSON to stdout.
verify_method_counts() {
    local manifest_file="$1" repo_root="$2"
    assert_valid_manifest "${manifest_file}" || return 1
    assert_valid_manifest_entries "${manifest_file}" || return 1

    local manifest_json entry_count
    manifest_json=$(cat -- "${manifest_file}") || return 1
    entry_count=$(printf '%s' "${manifest_json}" | jq 'length') || return 1

    local i
    for ((i = 0; i < entry_count; i++)); do
        local entry path full_path old_count new_methods_json new_count matches updated
        entry=$(printf '%s' "${manifest_json}" | jq -c ".[${i}]") || return 1
        path=$(printf '%s' "${entry}" | jq -r '.path') || return 1
        full_path="${repo_root}/${path}"
        if [[ ! -f "${full_path}" ]]; then
            printf 'verify-method-counts: entry file not found: %s\n' "${full_path}" >&2
            return 1
        fi
        old_count=$(printf '%s' "${entry}" | jq '.method_count') || return 1
        new_methods_json=$(extract_test_methods_json "${full_path}") || return 1
        new_count=$(printf '%s' "${new_methods_json}" | jq 'length') || return 1
        matches=$(jq -n \
            --argjson entry "${entry}" \
            --argjson newm "${new_methods_json}" \
            --argjson newc "${new_count}" \
            '(($entry.test_methods // []) == $newm) and ($entry.method_count == $newc)') || return 1
        if [[ "${matches}" != "true" ]]; then
            printf 'verify-method-counts: %s: method_count %s -> %s\n' "${path}" "${old_count}" "${new_count}" >&2
            updated=$(jq -n \
                --argjson entry "${entry}" \
                --argjson newm "${new_methods_json}" \
                --argjson newc "${new_count}" \
                '$entry | .method_count = $newc | .test_methods = $newm') || return 1
        else
            updated="${entry}"
        fi
        manifest_json=$(printf '%s' "${manifest_json}" | jq --argjson upd "${updated}" --argjson idx "${i}" '.[$idx] = $upd') || return 1
    done

    printf '%s\n' "${manifest_json}"
}

main() {
    set -euo pipefail
    local manifest_file="${1:-}" repo_root="${2:-}"
    if [[ -z "${manifest_file}" || -z "${repo_root}" ]]; then
        printf 'usage: verify-method-counts.sh <manifest.json> <repo_root>\n' >&2
        return 2
    fi
    verify_method_counts "${manifest_file}" "${repo_root}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
