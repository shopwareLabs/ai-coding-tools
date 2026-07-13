#!/usr/bin/env bash
# build-run-script.sh — produce a flat, top-level runnable copy of the committed
# team-review workflow with the run manifest spliced in.
#
# The committed workflow reads its manifest from the harness `args` global via the
# single line `const manifest = args;`. The workflow runtime has no filesystem and
# `args` carries no file channel, so a large (~160 KB) manifest cannot be delivered
# inline. This helper rewrites that one line to define `manifest` directly from a
# JSON file assembled on disk, and emits a runnable .mjs the skill launches via the
# Workflow tool's `scriptPath` (no `args`). Running the committed orchestration at
# top level keeps its `phase()` waves visible — a nested `workflow()` child would
# collapse all waves into one display group.
#
# Usage: build-run-script.sh <args.json> <out.mjs> [workflow.mjs]
#   args.json     assembled manifest object (validated with `jq empty`)
#   out.mjs       destination for the generated flat script (caller-owned, e.g. a
#                 mktemp path OUTSIDE the repo; this helper never writes in-tree)
#   workflow.mjs  committed source (default: sibling team-review.workflow.mjs)
#
# Sourcing this file defines the functions without running main, so the bats suite
# exercises the guards directly. The functions use explicit `|| return 1` so they
# fail correctly whether or not errexit is active in the sourcing shell.

# The exact line the committed workflow uses to read its manifest. Matched whole;
# if the committed file ever changes this line the build fails loudly rather than
# emitting a silently-broken script.
MANIFEST_MARKER='const manifest = args;'

# assert_single_marker <workflow_file>
# Fail (return 1) unless exactly one line of the committed workflow is the marker.
assert_single_marker() {
    local workflow_file="$1"
    if [[ ! -f "${workflow_file}" ]]; then
        printf 'build-run-script: committed workflow not found: %s\n' "${workflow_file}" >&2
        return 1
    fi
    local count
    count=$(grep -F -c -- "${MANIFEST_MARKER}" "${workflow_file}" || true)
    if [[ "${count}" != "1" ]]; then
        # shellcheck disable=SC2016  # backticks are literal message decoration, not command substitution
        printf 'build-run-script: expected exactly one `%s` line in %s, found %s — refusing to splice\n' \
            "${MANIFEST_MARKER}" "${workflow_file}" "${count}" >&2
        return 1
    fi
}

# assert_valid_args <args_file>
# Fail (return 1) unless the assembled args file is valid JSON, so the spliced
# literal is valid JS. jq prints the parse error to stderr.
assert_valid_args() {
    local args_file="$1"
    if [[ ! -f "${args_file}" ]]; then
        printf 'build-run-script: args file not found: %s\n' "${args_file}" >&2
        return 1
    fi
    if ! jq empty "${args_file}"; then
        printf 'build-run-script: args file is not valid JSON: %s\n' "${args_file}" >&2
        return 1
    fi
}

# build_run_script <args_file> <out_file> <workflow_file>
# Splice the manifest into a copy of the committed workflow and write <out_file>
# atomically. Every line but the single marker line is left byte-identical.
build_run_script() {
    local args_file="$1" out_file="$2" workflow_file="$3"
    assert_single_marker "${workflow_file}" || return 1
    assert_valid_args "${args_file}" || return 1
    # awk fires on the same line-containment predicate the guard counted, so the
    # one line the guard found is the one line that gets replaced.
    local tmp
    tmp=$(mktemp "${out_file}.XXXXXX") || return 1
    if ! awk -v marker="${MANIFEST_MARKER}" -v argsfile="${args_file}" '
        index($0, marker) {
            printf "const manifest = "
            while ((getline line < argsfile) > 0) print line
            close(argsfile)
            print ";"
            next
        }
        { print }
    ' "${workflow_file}" > "${tmp}"; then
        rm -f "${tmp}"
        return 1
    fi
    mv "${tmp}" "${out_file}" || { rm -f "${tmp}"; return 1; }
}

main() {
    set -euo pipefail
    local args_file="${1:-}" out_file="${2:-}" workflow_file="${3:-}"
    if [[ -z "${args_file}" || -z "${out_file}" ]]; then
        printf 'usage: build-run-script.sh <args.json> <out.mjs> [workflow.mjs]\n' >&2
        return 2
    fi
    if [[ -z "${workflow_file}" ]]; then
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        workflow_file="${script_dir}/team-review.workflow.mjs"
    fi
    build_run_script "${args_file}" "${out_file}" "${workflow_file}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
