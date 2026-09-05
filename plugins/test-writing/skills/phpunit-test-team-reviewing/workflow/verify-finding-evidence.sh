#!/usr/bin/env bash
# verify-finding-evidence.sh — deterministic check that every kept finding
# quotes code that exists.
#
# A persisted review-stage result's `files[]` entries carry findings in
# `errors`/`warnings`/`informational` (collectively "kept" — the consensus-
# stage or adversarial-stage disposition) and `contested`. This script checks
# every kept finding whose `current` is non-empty against the reviewed file's
# actual content: whitespace-normalize both (collapse whitespace runs to a
# single space, trim), then test literal substring containment. A finding that
# fails the check is moved from its kept bucket into `contested`, tagged with
# an `outcome` field naming the failed match — the same field the merge uses
# to record why a contested finding did not reach consensus (see
# report-format.md's Contested Findings render: "arbiter refuted: reasoning").
# A finding with empty or absent `current` is exempt (nothing to verify).
#
# Every kept finding also sits, in the same review-stage result, inside its
# file's `adversarial_input.kept` (the raw, unbucketed payload the campaign's
# adversarial stage consumes to build args-adversarial.json) — the same
# records `errors`/`warnings`/`informational` bucket by enforce level. A
# demotion is therefore synced there by `finding_id`, not re-checked: a
# finding demoted from the top-level buckets is also removed from
# `adversarial_input.kept` and appended to `adversarial_input.contested`, so
# it never reaches the red team either. A file entry with no `adversarial_input`
# field is left without one.
#
# Usage: verify-finding-evidence.sh <result.json> <repo_root>
#   result.json  a persisted review/adversarial-stage result JSON
#                 (shard-k.result.json or adversarial.result.json), carrying
#                 a top-level `files` array
#   repo_root    repo root of the project under review; each file entry's
#                 `path` is resolved relative to it
#
# Writes the corrected result JSON to stdout. Writes one line per demotion to
# stderr: "verify-finding-evidence: demoted <finding_id> in <path>: current
# block not found under whitespace normalization". Exit 0 on success (a
# demotion is a successful run, not a partial one). Non-zero, with a message
# on stderr, when a file entry naming a kept finding to verify does not exist
# on disk, or when the input is not valid JSON.
#
# Sourcing this file defines the functions without running main, so a bats
# suite can exercise them directly. Functions use explicit `|| return 1` so
# they fail correctly whether or not errexit is active in the sourcing shell.

# The jq program applied per file entry. Reads $entry (the file's JSON object),
# $content (the raw target-file text, via --rawfile), and $path (the entry's
# `path`, for the outcome message). Emits { updated, demotions }: `updated` is
# the file entry with demoted findings moved into `contested`; `demotions` is
# a list of { finding_id, path } for the stderr log lines.
_VERIFY_FINDING_EVIDENCE_JQ_PROGRAM=$(cat <<'EOF'
def norm: gsub("[[:space:]]+"; " ") | gsub("^ +| +$"; "");
def checkBucket(arr):
  reduce arr[] as $f ({kept: [], demoted: []};
    if (($f.current // "") == "") then
      .kept += [$f]
    elif (($content | norm) | contains($f.current | norm)) then
      .kept += [$f]
    else
      .demoted += [$f]
    end
  );
def tagOutcome: . + {outcome: ("evidence check: current block not found in " + $path + " under whitespace normalization")};
($entry.errors // []) as $errs
| ($entry.warnings // []) as $warns
| ($entry.informational // []) as $infos
| checkBucket($errs) as $E
| checkBucket($warns) as $W
| checkBucket($infos) as $I
| ($E.demoted + $W.demoted + $I.demoted) as $demoted
| ($demoted | map(.finding_id)) as $demotedIds
| ($demoted | map(tagOutcome)) as $demotedTagged
| ($entry.adversarial_input.kept // []) as $aiKeptOrig
| ($entry.adversarial_input.contested // []) as $aiContestedOrig
| ($aiKeptOrig | map(select(.finding_id as $fid | $demotedIds | index($fid)))) as $aiDemoted
| ($aiKeptOrig | map(select(.finding_id as $fid | ($demotedIds | index($fid)) | not))) as $aiKeptRemaining
| ($entry
    | .errors = $E.kept
    | .warnings = $W.kept
    | .informational = $I.kept
    | .contested = (($entry.contested // []) + $demotedTagged)
    | if ($entry | has("adversarial_input")) then
        .adversarial_input.kept = $aiKeptRemaining
        | .adversarial_input.contested = ($aiContestedOrig + ($aiDemoted | map(tagOutcome)))
      else . end
  ) as $updated
| {updated: $updated, demotions: [$demotedTagged[] | {finding_id: (.finding_id // "unknown"), path: $path}]}
EOF
)

# The jq program applied to the whole result document by assert_valid_file_entries. Emits one
# line per invalid `files[]` entry: "entry <index> (<path or '<no path>'>): <violation>; ...".
# Checks only what the emitted result shape guarantees (report-format.md / the workflow's
# `bucketFile`/`contestedView`): `errors`/`warnings`/`informational`/`contested` are always
# present arrays in both mode=review and mode=adversarial output, so absence itself is not
# flagged here — only a present-but-wrongly-typed bucket or finding is. `adversarial_input`
# is present only in mode=review output, so it is checked only when present.
_VERIFY_FINDING_EVIDENCE_ENTRY_CHECK_JQ=$(cat <<'EOF'
def path_errors($v):
  if ($v | has("path") | not) then ["path missing"]
  elif ($v.path | type) != "string" then ["path is not a string"]
  elif ($v.path | length) == 0 then ["path is empty"]
  else [] end;
def bucket_type_errors($v; $field):
  if ($v | has($field) | not) then []
  elif ($v[$field] | type) != "array" then ["\($field) is not an array"]
  else [] end;
def finding_errors($v; $field):
  if ($v | has($field) | not) then []
  elif ($v[$field] | type) != "array" then []
  else
    [ ($v[$field] | to_entries[]) as $e
      | ($e.value) as $f
      | (
          (if ($f | has("finding_id") | not) then ["\($field)[\($e.key)].finding_id missing"]
           elif ($f.finding_id | type) != "string" then ["\($field)[\($e.key)].finding_id is not a string"]
           else [] end)
          +
          (if ($f | has("current")) and (($f.current | type) != "string") then ["\($field)[\($e.key)].current is not a string"]
           else [] end)
        )[]
    ]
  end;
def adversarial_input_errors($v):
  if ($v | has("adversarial_input") | not) then []
  else
    (bucket_type_errors($v.adversarial_input; "kept") | map("adversarial_input." + .))
    + (bucket_type_errors($v.adversarial_input; "contested") | map("adversarial_input." + .))
  end;
.files
| to_entries[] as $e
| ($e.key) as $idx | ($e.value) as $v
| (
    path_errors($v)
    + bucket_type_errors($v; "errors") + bucket_type_errors($v; "warnings")
    + bucket_type_errors($v; "informational") + bucket_type_errors($v; "contested")
    + finding_errors($v; "errors") + finding_errors($v; "warnings") + finding_errors($v; "informational")
    + adversarial_input_errors($v)
  ) as $errs
| select(($errs | length) > 0)
| "entry \($idx) (\($v.path // "<no path>")): " + ($errs | join("; "))
EOF
)

# assert_valid_file_entries <result_file>
# Fail (return 1) unless every `files[]` entry has a non-empty string `path`;
# `errors`/`warnings`/`informational`/`contested`, when present, are arrays;
# every finding inside the three kept buckets has a string `finding_id` (and a
# string `current` when present); and, when present, `adversarial_input.kept`
# and `adversarial_input.contested` are arrays. A wrongly-typed bucket (e.g.
# `errors: {}`) means the result is corrupted — this is a hard failure, never
# a silent pass-through.
assert_valid_file_entries() {
    local result_file="$1"
    local violations
    violations=$(jq -r "${_VERIFY_FINDING_EVIDENCE_ENTRY_CHECK_JQ}" -- "${result_file}") || return 1
    if [[ -n "${violations}" ]]; then
        local line
        while IFS= read -r line; do
            printf 'verify-finding-evidence: invalid result file entry: %s\n' "${line}" >&2
        done <<< "${violations}"
        return 1
    fi
}

# assert_valid_result <result_file>
# Fail (return 1) unless the file exists, is valid JSON, and carries a
# top-level `files` array — a syntactically valid document missing or
# misshaping `files` (e.g. `{}` or `{"files":{}}`) would otherwise pass
# `jq empty`, iterate zero times below, and print back unchanged as if every
# finding had been evidence-checked.
assert_valid_result() {
    local result_file="$1"
    if [[ ! -f "${result_file}" ]]; then
        printf 'verify-finding-evidence: result file not found: %s\n' "${result_file}" >&2
        return 1
    fi
    if ! jq empty -- "${result_file}" 2>/dev/null; then
        printf 'verify-finding-evidence: result file is not valid JSON: %s\n' "${result_file}" >&2
        return 1
    fi
    if [[ "$(jq -r '.files | type' -- "${result_file}")" != "array" ]]; then
        printf 'verify-finding-evidence: result file has no top-level "files" array: %s\n' "${result_file}" >&2
        return 1
    fi
}

# verify_finding_evidence <result_file> <repo_root>
# Check every kept finding's `current` against its file's real content and
# print the corrected result JSON to stdout.
verify_finding_evidence() {
    local result_file="$1" repo_root="$2"
    assert_valid_result "${result_file}" || return 1
    assert_valid_file_entries "${result_file}" || return 1

    local result_json file_count
    result_json=$(cat -- "${result_file}") || return 1
    file_count=$(printf '%s' "${result_json}" | jq '.files | length') || return 1

    local i
    for ((i = 0; i < file_count; i++)); do
        local entry path candidate_count full_path check_result updated demotions_line fid
        entry=$(printf '%s' "${result_json}" | jq -c ".files[${i}]") || return 1
        path=$(printf '%s' "${entry}" | jq -r '.path') || return 1
        candidate_count=$(printf '%s' "${entry}" \
            | jq '[.errors[]?, .warnings[]?, .informational[]?] | map(select((.current // "") != "")) | length') || return 1
        if [[ "${candidate_count}" -eq 0 ]]; then
            continue
        fi
        full_path="${repo_root}/${path}"
        if [[ ! -f "${full_path}" ]]; then
            printf 'verify-finding-evidence: target file not found: %s (referenced by a kept finding requiring evidence check)\n' "${full_path}" >&2
            return 1
        fi
        check_result=$(jq -n \
            --argjson entry "${entry}" \
            --rawfile content "${full_path}" \
            --arg path "${path}" \
            "${_VERIFY_FINDING_EVIDENCE_JQ_PROGRAM}") || return 1
        updated=$(printf '%s' "${check_result}" | jq -c '.updated') || return 1
        while IFS= read -r demotions_line; do
            [[ -n "${demotions_line}" ]] || continue
            fid=$(printf '%s' "${demotions_line}" | jq -r '.finding_id') || return 1
            printf 'verify-finding-evidence: demoted %s in %s: current block not found under whitespace normalization\n' "${fid}" "${path}" >&2
        done < <(printf '%s' "${check_result}" | jq -c '.demotions[]')
        result_json=$(printf '%s' "${result_json}" | jq --argjson upd "${updated}" --argjson idx "${i}" '.files[$idx] = $upd') || return 1
    done

    printf '%s\n' "${result_json}"
}

main() {
    set -euo pipefail
    local result_file="${1:-}" repo_root="${2:-}"
    if [[ -z "${result_file}" || -z "${repo_root}" ]]; then
        printf 'usage: verify-finding-evidence.sh <result.json> <repo_root>\n' >&2
        return 2
    fi
    verify_finding_evidence "${result_file}" "${repo_root}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
