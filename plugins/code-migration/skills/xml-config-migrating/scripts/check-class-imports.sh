#!/usr/bin/env bash
# Check that every bare `Foo::class` in a PHP config file has a matching
# `use` import. A missing import resolves silently against the file's own
# namespace and yields a wrong service id instead of an error.
#
# Usage: check-class-imports.sh <file.php> [<file.php> ...]
# Exit code: 0 = all imports present, 1 = missing imports, 2 = usage error.
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "usage: $(basename "$0") <file.php> [<file.php> ...]" >&2
    exit 2
fi

status=0
for file in "$@"; do
    if [ ! -f "$file" ]; then
        echo "$file: not found" >&2
        status=1
        continue
    fi

    known=$(
        # `use Foo\Bar;` imports Bar; `use Foo\Bar as Baz;` imports Baz
        { grep -oE '^use [A-Za-z0-9_\\]+;' "$file" || true; } | sed -E 's/^use ([A-Za-z0-9_]+\\)*//; s/;$//'
        { grep -oE '^use [A-Za-z0-9_\\]+ as [A-Za-z0-9_]+;' "$file" || true; } | sed -E 's/^.* as //; s/;$//'
    )

    missing=$(
        # bare names only: qualified/leading-backslash refs resolve on their own
        grep -oE '[A-Za-z0-9_\\]+::class' "$file" | sed 's/::class$//' | sort -u \
            | grep -xE '[A-Za-z0-9_]+' \
            | grep -vxE 'self|static|parent|ContainerConfigurator' \
            | grep -vxF -f <(printf '%s\n' "$known" | sed '/^$/d') || true
    )

    if [ -n "$missing" ]; then
        printf '%s: missing use import for: %s\n' "$file" "$(echo "$missing" | tr '\n' ' ')" >&2
        status=1
    fi
done
exit $status
