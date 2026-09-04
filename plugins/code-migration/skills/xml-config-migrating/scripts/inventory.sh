#!/usr/bin/env bash
# Enumerate Symfony-loaded XML config under an extension source tree and
# classify each file by type and the environments it applies to.
#
# Usage: inventory.sh <extension-src-root>
# Output: TSV to stdout, one line per file: path<TAB>type<TAB>envs
#   type: services | routes | packages
#   envs: comma-list, e.g. "default" or "default,test"
# A file the basename and location rules do not know is classified by its own
# Symfony namespace; an XML that carries neither is out of scope, and is
# announced on stderr and skipped rather than ending the run.
# Exit code: 0 = ok (an empty result is a valid "nothing to migrate" answer),
#            2 = usage error, the given root does not exist, or a scan failure
#                (an unreadable file or directory).
set -euo pipefail

usage() {
    printf 'usage: %s <extension-src-root>\n' "$(basename -- "$0")" >&2
    exit 2
}

if [ $# -ne 1 ]; then
    usage
fi

root="$1"
case "$root" in
    -*) root="./${root}" ;;
esac

if [ ! -d "$root" ]; then
    printf '%s: not a directory\n' "$root" >&2
    exit 2
fi

# Shopware-native formats that are never Symfony-loaded config; keep as XML.
readonly EXCLUDE_PATTERN='^(config|custom-fields|flow|rule-conditions|manifest)\.xml$'

# ERE for a <when env="X"> block; capture group 1 is the env name.
readonly WHEN_ENV_PATTERN='<when[[:space:]]+env="([A-Za-z0-9_]+)"'

classify_type() {
    # classify_type <path> <basename>
    local path="$1" base="$2"

    case "$path" in
        */packages/*) printf 'packages\n'; return ;;
    esac
    case "$path" in
        */routes/*) printf 'routes\n'; return ;;
    esac
    case "$base" in
        routes*.xml) printf 'routes\n'; return ;;
        services*.xml) printf 'services\n'; return ;;
    esac
    printf 'unclassified\n'
}

classify_by_content() {
    # classify_by_content <path> — the type implied by the XML's own Symfony
    # namespace, for a file whose basename and location say nothing. A manually
    # loaded DI or routing file may carry any basename, and a Shopware-native
    # schema file may sit in the same directory. Prints "services", "routes",
    # or nothing at all when the file is neither. Every stage's exit status is
    # checked explicitly so this function fails loudly regardless of the
    # caller's context.
    local file="$1" status

    status=0
    grep -qF -e 'http://symfony.com/schema/dic/services' -- "$file" || status=$?
    if [ "$status" -eq 0 ]; then
        printf 'services\n'
        return 0
    fi
    if [ "$status" -gt 1 ]; then
        printf 'inventory: grep failed for %s\n' "$file" >&2
        return 2
    fi

    status=0
    grep -qF -e 'http://symfony.com/schema/routing' -- "$file" || status=$?
    if [ "$status" -eq 0 ]; then
        printf 'routes\n'
        return 0
    fi
    if [ "$status" -gt 1 ]; then
        printf 'inventory: grep failed for %s\n' "$file" >&2
        return 2
    fi

    printf '\n'
}

filename_env() {
    # filename_env <basename> — the env implied by a services_<env>.xml or
    # routes_<env>.xml suffix. routes_overwrite.xml is not an env suffix.
    local base="$1" stem env

    case "$base" in
        services_*.xml)
            stem="${base#services_}"
            env="${stem%.xml}"
            printf '%s\n' "$env"
            return
            ;;
        routes_*.xml)
            stem="${base#routes_}"
            env="${stem%.xml}"
            if [ "$env" = "overwrite" ]; then
                printf 'default\n'
            else
                printf '%s\n' "$env"
            fi
            return
            ;;
    esac
    printf 'default\n'
}

when_envs() {
    # when_envs <file> — every env named in a <when env="X"> block, one per
    # line. Every stage's exit status is checked explicitly so this function
    # fails loudly regardless of the caller's context — a caller invoking it
    # inside a conditional (if/&&/||/!) disables errexit for this function's
    # entire body, so it cannot rely on set -e to catch a failing sed or grep.
    local file="$1" when_matches grep_status sed_status

    if ! when_matches=$(mktemp "${TMPDIR:-/tmp}/inventory-when.XXXXXX"); then
        printf 'inventory: failed to create temporary when-env file\n' >&2
        return 2
    fi

    if grep -oE "$WHEN_ENV_PATTERN" -- "$file" > "$when_matches"; then
        grep_status=0
    else
        grep_status=$?
    fi

    if [ "$grep_status" -gt 1 ]; then
        rm -f -- "$when_matches"
        printf 'inventory: grep failed for %s\n' "$file" >&2
        return 2
    fi

    if sed -E 's/^.*env="//; s/"$//' "$when_matches"; then
        sed_status=0
    else
        sed_status=$?
    fi
    rm -f -- "$when_matches"

    if [ "$sed_status" -ne 0 ]; then
        printf 'inventory: sed failed for %s\n' "$file" >&2
        return 2
    fi
}

directory_env() {
    # directory_env <path> — the env implied by a first-level subdirectory of
    # routes/ or packages/ (relative to that file's Resources/config
    # directory), one or more levels below it. Empty when the file sits
    # directly in routes/ or packages/, or under neither.
    local path="$1" rest seg

    case "$path" in
        */Resources/config/routes/*/*)
            rest="${path#*/Resources/config/routes/}"
            seg="${rest%%/*}"
            printf '%s\n' "$seg"
            return
            ;;
        */Resources/config/packages/*/*)
            rest="${path#*/Resources/config/packages/}"
            seg="${rest%%/*}"
            printf '%s\n' "$seg"
            return
            ;;
    esac
    printf '\n'
}

results=()

if ! find_output=$(mktemp "${TMPDIR:-/tmp}/inventory-find.XXXXXX"); then
    printf 'inventory: failed to create temporary find list\n' >&2
    exit 2
fi

if ! find "$root" -type f -path '*/Resources/config/*' -name '*.xml' -print0 > "$find_output"; then
    rm -f -- "$find_output"
    printf 'inventory: find failed for %s\n' "$root" >&2
    exit 2
fi
trap 'rm -f -- "$find_output"' EXIT

exec 3< "$find_output"
while IFS= read -r -d '' file; do
    base=$(basename -- "$file")
    dir=$(dirname -- "$file")

    # The exclusion keys on the parent directory being any */Resources/config
    # — a nested bundle's own Resources/config is such a directory too, so a
    # native basename there is excluded the same as at the top level. Only a
    # subdirectory below Resources/config (packages/, routes/) stays in
    # scope for that basename.
    if [[ "$base" =~ $EXCLUDE_PATTERN ]]; then
        case "$dir" in
            */Resources/config) continue ;;
        esac
    fi

    type=$(classify_type "$file" "$base")
    content_classified=0
    if [ "$type" = "unclassified" ]; then
        # An unknown basename is a question, not an error. Plain assignment,
        # not a conditional call: under set -e an unreadable file aborts the
        # script here with its own message and exit code.
        type=$(classify_by_content "$file")
        if [ -z "$type" ]; then
            printf 'inventory: skipped (not Symfony DI or routing XML): %s\n' "$file" >&2
            continue
        fi
        content_classified=1
    fi

    # Location decides which rule applies: a file directly in Resources/config
    # takes its env from a filename suffix; a file under a routes/ or
    # packages/ subdirectory takes its env from that subdirectory (or
    # "default" when there is no subdirectory level), and the filename
    # contributes nothing there. A file the namespace classified is loaded by
    # hand under any name, so neither source applies and it starts at default.
    if [ "$content_classified" -eq 1 ]; then
        base_env="default"
    else
        case "$dir" in
            */Resources/config)
                base_env=$(filename_env "$base")
                ;;
            *)
                base_env=$(directory_env "$file")
                if [ -z "$base_env" ]; then
                    base_env="default"
                fi
                ;;
        esac
    fi

    envs=("$base_env")
    # Plain assignment, not a conditional call: under set -e a failing
    # when_envs aborts the script here (with its own stderr message and exit
    # code) instead of silently continuing with an incomplete env list.
    when_output=$(when_envs "$file")
    while IFS= read -r extra_env; do
        [ -n "$extra_env" ] || continue
        already=0
        for e in "${envs[@]}"; do
            if [ "$e" = "$extra_env" ]; then
                already=1
                break
            fi
        done
        if [ "$already" -eq 0 ]; then
            envs+=("$extra_env")
        fi
    done <<< "$when_output"

    envs_csv=$(printf '%s\n' "${envs[@]}" | sort -u | paste -sd, -)

    results+=("${file}"$'\t'"${type}"$'\t'"${envs_csv}")
done <&3

exec 3<&-
rm -f -- "$find_output"
trap - EXIT

if [ "${#results[@]}" -eq 0 ]; then
    exit 0
fi

printf '%s\n' "${results[@]}" | sort
