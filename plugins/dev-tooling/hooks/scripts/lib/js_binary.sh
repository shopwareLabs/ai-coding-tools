#!/bin/bash
# Matches a direct run of a JS tool binary or an npm script, for the Admin and
# Storefront JS hooks; each hook decides which binaries and scripts it checks.
# Owned by dev-tooling, not templated like common.sh.
#
# Public:
#   COMMAND_POSITION    ERE prefix: start of command or after `;`, `&&`, `||`
#                       or `|`, then any number of `NAME=value` assignments
#   NAME_END            ERE suffix: what may follow an exact binary or script name
#   NPM_RUN             npm with its flags, `run` or `run-script`, and flags
#   COMPOSER_RUN        composer with its global options and `run` or `run-script`
#   runs_binary <name>  COMMAND runs the binary <name>
#   runs_npm_script <name-re>
#                       COMMAND runs the npm script whose whole name matches <name-re>
#
# A binary is matched at a command position: `npx`, `npm exec` or `npm x`
# followed by flags that take no value and an optional `--`; a node_modules/.bin
# path, optionally run through `node`; and the -c / --call string of those
# runners, at its start or after `;`, `&&` or `|`.
# A bare binary name is not matched: it also sits at a command position inside
# quoted text such as a commit message, which would then be blocked. For the
# same reason COMMAND_POSITION has no `(`: `-m "fix (npx eslint)"` is text.
# A flag that takes a value is not skipped, because its value would read as the
# binary; before -c it is, because there the string names what runs.

COMMAND_POSITION='(^|;|&&|\|)\s*([A-Za-z_][A-Za-z0-9_]*=\S*\s+)*'

# `:` and `-` are absent, so `lint` never matches `lint:fix`, `lint--x` or `lintx`.
NAME_END='([[:space:];&|<>)]|$)'

BINARY_INVOCATION="${COMMAND_POSITION}((npm\s+(exec|x)|npx)(\s+(-y|--yes|--no|--no-install|-q|--quiet|--silent|--))*\s+|(node\s+)?\S*node_modules/\.bin/)"

CALL_INVOCATION="${COMMAND_POSITION}(npm\s+(exec|x)|npx)(\s+(-y|--yes|--no|--no-install|-q|--quiet|--silent|(--package|--workspace|-p|-w)(=|\s+)[^[:space:]\"';&|]+))*\s+(-c|--call)(\s+|=)[\"']?\s*([^\"';&|]*(;|&&|\|)\s*)*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]\"';&|]*\s+)*"

# npm, its flags (`--prefix` with its value), `run` or `run-script`, then flags
# before the script name. The detectors in the hooks use it unanchored.
NPM_RUN='npm(\s+(--?[A-Za-z][-A-Za-z]*|--prefix\s+\S+))*\s+run(-script)?(\s+--?[A-Za-z][-A-Za-z]*)*\s+'

# Composer's script runner: composer, then its global options (`-d` and
# `--working-dir` with their value, and any other flag that takes none), then an
# optional `run` or `run-script` before the script name. Each hook prefixes it
# with COMMAND_POSITION where it needs the match anchored to a command.
# shellcheck disable=SC2034  # read by check-php-tools.sh when it sources this file
COMPOSER_RUN='composer\s+((-d|--working-dir)(=|\s+)?\S+\s+|-\S+\s+)*(run(-script)?\s+)?'

# Globals: reads COMMAND, set by parse_hook_input in common.sh
# Args: $1 = binary name
# Returns: 0 when COMMAND runs the binary in one of the forms above
runs_binary() {
    echo "$COMMAND" | grep -qE "${BINARY_INVOCATION}$1(@\S+)?${NAME_END}" \
        || echo "$COMMAND" | grep -qE "${CALL_INVOCATION}$1(@\S+)?([[:space:];&|<>)\"']|\$)"
}

# Globals: reads COMMAND, set by parse_hook_input in common.sh
# Args: $1 = ERE matching the whole script name, e.g. 'lint' or 'unit:components(:watch)?'
# Returns: 0 when COMMAND runs that npm script at a command position
runs_npm_script() {
    echo "$COMMAND" | grep -qE "${COMMAND_POSITION}${NPM_RUN}($1)${NAME_END}"
}
