#!/bin/bash
# Matches a direct run of a JS tool binary, for the Admin and Storefront JS
# hooks; each hook decides which binaries it checks. Owned by dev-tooling, not
# templated like common.sh.
#
# Matched at a command position: `npx`, `npm exec` or `npm x` followed by flags
# that take no value and an optional `--`; a node_modules/.bin path; and the
# -c / --call string of those runners, at its start or after `;`, `&&` or `|`.
# A bare binary name is not matched: it also sits at a command position inside
# quoted text such as a commit message, which would then be blocked.
# A flag that takes a value is not skipped, because its value would read as the
# binary; before -c it is, because there the string names what runs.

BINARY_INVOCATION='(^|;|&&|\|)\s*((npm\s+(exec|x)|npx)(\s+(-y|--yes|--no|--no-install|-q|--quiet|--silent|--))*\s+|\S*node_modules/\.bin/)'

CALL_INVOCATION="(^|;|&&|\|)\s*(npm\s+(exec|x)|npx)(\s+(-y|--yes|--no|--no-install|-q|--quiet|--silent|(--package|--workspace|-p|-w)(=|\s+)[^[:space:]\"';&|]+))*\s+(-c|--call)(\s+|=)[\"']?\s*([^\"';&|]*(;|&&|\|)\s*)*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]\"';&|]*\s+)*"

# Globals: reads COMMAND, set by parse_hook_input in common.sh
# Args: $1 = binary name
# Returns: 0 when COMMAND runs the binary in one of the forms above
runs_binary() {
    echo "$COMMAND" | grep -qE "${BINARY_INVOCATION}$1(@\S+)?(\s|\$)" \
        || echo "$COMMAND" | grep -qE "${CALL_INVOCATION}$1(@\S+)?(\s|\$|[\"'])"
}
