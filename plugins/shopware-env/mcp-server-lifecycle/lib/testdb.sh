#!/usr/bin/env bash
# testdb_prepare tool implementation

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# Prepare the test database by forcing a reinstall through a full PHPUnit run.
# Globals:
#   Reads the environment resolve_lifecycle_env resolves.
# Arguments:
#   $1 - tool arguments as JSON: the environment arguments
#        resolve_lifecycle_env reads
# Outputs:
#   The command's output on stdout
# Returns:
#   0 when the run succeeded, 1 on a failed command or an unresolvable
#   environment
tool_testdb_prepare() {
    local args="$1"

    if ! resolve_lifecycle_env "${args}"; then
        return 1
    fi

    local cmd="FORCE_INSTALL=true vendor/bin/phpunit --group=none --testsuite migration,unit,integration,devops"
    log "INFO" "testdb_prepare: ${cmd}"
    exec_command "${cmd}"
}
