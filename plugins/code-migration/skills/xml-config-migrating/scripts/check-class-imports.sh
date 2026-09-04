#!/usr/bin/env bash
# Check that every bare `Foo::class` in a PHP config file has a matching
# `use` import. A missing import resolves silently against the file's own
# namespace and yields a wrong service id instead of an error.
#
# Usage: check-class-imports.sh <file.php> [<file.php> ...]
# Exit code: 0 = all imports present, 1 = missing imports, 2 = usage error, an
#            argument that does not exist or cannot be read, or an aborted or
#            failed scan. An unreadable argument is a scan failure, never a
#            finding: it exits 2 at that argument without scanning the rest, so
#            a caller reading the exit code can never mistake a wrong path for
#            "this file is missing imports".
set -euo pipefail

if [ $# -lt 1 ]; then
    printf 'usage: %s <file.php> [<file.php> ...]\n' "$(basename -- "$0")" >&2
    exit 2
fi

if ! tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/check-class-imports.XXXXXX"); then
    printf 'check-class-imports: failed to create temporary directory\n' >&2
    exit 2
fi

# A trapped HUP/INT/TERM does not, by itself, terminate the script -- bash
# keeps running past the interrupted command once the trap returns. Force
# the exit here so an unanticipated signal aborts the scan instead of
# letting it resume and potentially exit 0. It exits 2, not 1: exit 1 is
# reserved for the finding "this file is missing imports", and an aborted
# scan found nothing.
# Invoked via `trap` below, not a direct call — this tool's reachability
# analysis loses track of the trap call site once the script's final
# statement is `exit` with a variable exit code.
# shellcheck disable=SC2329
on_signal() {
    rm -rf -- "$tmp_dir"
    exit 2
}
trap on_signal HUP INT TERM
trap 'rm -rf -- "$tmp_dir"' EXIT

grep_matches() {
    # grep_matches <source-label> <output-file> <grep-arguments...>
    local source_label="$1" output_file="$2" grep_status
    shift 2

    if grep "$@" > "$output_file"; then
        return 0
    else
        grep_status=$?
    fi

    if [ "$grep_status" -eq 1 ]; then
        : > "$output_file"
        return 0
    fi

    printf 'check-class-imports: grep failed for %s\n' "$source_label" >&2
    return 2
}

status=0
for file in "$@"; do
    case "$file" in
        -*) file="./${file}" ;;
    esac

    # A path that is not there, or is there and unreadable, is a broken
    # invocation rather than a result about the file's imports. Stop at the
    # first one: scanning the remaining arguments would produce findings from a
    # run whose argument list is already known to be wrong.
    if [ ! -f "$file" ]; then
        printf '%s: not found\n' "$file" >&2
        exit 2
    fi

    if [ ! -r "$file" ]; then
        printf '%s: not readable\n' "$file" >&2
        exit 2
    fi

    known_file="${tmp_dir}/known.$RANDOM"
    plain_uses="${tmp_dir}/plain-uses.$RANDOM"
    alias_uses="${tmp_dir}/alias-uses.$RANDOM"
    group_uses="${tmp_dir}/group-uses.$RANDOM"
    raw_classes="${tmp_dir}/raw-classes.$RANDOM"
    candidate_classes="${tmp_dir}/candidate-classes.$RANDOM"
    bare_classes="${tmp_dir}/bare-classes.$RANDOM"
    non_exempt_classes="${tmp_dir}/non-exempt-classes.$RANDOM"
    known_nonempty="${tmp_dir}/known-nonempty.$RANDOM"
    missing_file="${tmp_dir}/missing.$RANDOM"

    : > "$known_file"
    if ! grep_matches "$file" "$plain_uses" -oE '^use [A-Za-z0-9_\\]+;' -- "$file"; then
        exit 2
    fi
    sed -E 's/^use ([A-Za-z0-9_]+\\)*//; s/;$//' "$plain_uses" >> "$known_file"

    if ! grep_matches "$file" "$alias_uses" -oE '^use [A-Za-z0-9_\\]+ as [A-Za-z0-9_]+;' -- "$file"; then
        exit 2
    fi
    sed -E 's/^.* as //; s/;$//' "$alias_uses" >> "$known_file"

    if ! grep_matches "$file" "$group_uses" -E '^use [A-Za-z0-9_\\]+\\{[^}]+\};' -- "$file"; then
        exit 2
    fi
    while IFS= read -r group_use; do
        group_members="${group_use#*\{}"
        group_members="${group_members%\};}"
        IFS=',' read -r -a group_member_list <<< "$group_members"
        for group_member in "${group_member_list[@]}"; do
            group_member=$(printf '%s' "$group_member" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
            case "$group_member" in
                function\ *|const\ *) continue ;;
            esac
            if [[ "$group_member" == *' as '* ]]; then
                printf '%s\n' "${group_member##* as }" >> "$known_file"
            else
                printf '%s\n' "${group_member##*\\}" >> "$known_file"
            fi
        done
    done < "$group_uses"

    if ! grep_matches "$file" "$raw_classes" -oE '[A-Za-z0-9_\\]+::class' -- "$file"; then
        exit 2
    fi
    sed 's/::class$//' "$raw_classes" | sort -u > "$candidate_classes"
    if ! grep_matches "$file" "$bare_classes" -xE '[A-Za-z0-9_]+' "$candidate_classes"; then
        exit 2
    fi
    if ! grep_matches "$file" "$non_exempt_classes" -vxE 'self|static|parent|ContainerConfigurator' "$bare_classes"; then
        exit 2
    fi
    sed '/^$/d' "$known_file" > "$known_nonempty"
    if ! grep_matches "$file" "$missing_file" -vxF -f "$known_nonempty" "$non_exempt_classes"; then
        exit 2
    fi
    missing=$(< "$missing_file")

    if [ -n "$missing" ]; then
        printf '%s: missing use import for: %s\n' "$file" "$(printf '%s\n' "$missing" | tr '\n' ' ')" >&2
        status=1
    fi
done
exit $status
