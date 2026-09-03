#!/usr/bin/env bash
# Closing-sweep wrapper for the researching-code skill. Runs a fixed ugrep
# ERE search and appends a tool-computed count so callers neither assemble
# ugrep flags nor tally results by reading the listing.
#
# Usage: sweep.sh [-n] [-g GLOB]... PATTERN PATH...
#   default  list files containing a match; count = number of files
#   -n       list matches as file:line:text; count = number of matching lines
#   -g GLOB  restrict to files whose name matches GLOB (repeatable)
#
# The pattern is always ERE: write alternation as "a|b", never "a\|b".
# Output: the matches, a "---" separator, then "count: N".
# Exit 0 on success including zero matches; non-zero only on real errors.

set -euo pipefail

mode="files"
includes=()

while getopts ":ng:" opt; do
  case "$opt" in
    n) mode="lines" ;;
    g) includes+=("--include=$OPTARG") ;;
    \?) echo "sweep.sh: unknown option -$OPTARG" >&2; exit 2 ;;
    :) echo "sweep.sh: option -$OPTARG requires an argument" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

if [ "$#" -lt 2 ]; then
  echo "usage: sweep.sh [-n] [-g GLOB]... PATTERN PATH..." >&2
  exit 2
fi

pattern="$1"
shift

flags=(-r -E)
if [ "$mode" = "files" ]; then
  flags+=(-l)
else
  flags+=(-n)
fi

# ugrep exits 1 on zero matches, which is a valid sweep result, not an error.
set +e
matches="$(ugrep "${flags[@]}" ${includes[@]+"${includes[@]}"} -e "$pattern" -- "$@")"
status=$?
set -e

if [ "$status" -gt 1 ]; then
  exit "$status"
fi

count=0
if [ -n "$matches" ]; then
  printf '%s\n' "$matches"
  count="$(printf '%s\n' "$matches" | wc -l | tr -d '[:space:]')"
fi
echo "---"
echo "count: $count"
