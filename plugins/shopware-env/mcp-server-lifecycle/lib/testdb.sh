#!/usr/bin/env bash
# testdb_prepare tool implementation

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

tool_testdb_prepare() {
    local args="$1"

    if ! resolve_lifecycle_env "${args}"; then
        return 1
    fi

    local cmd="FORCE_INSTALL=true vendor/bin/phpunit --group=none --testsuite migration,unit,integration,devops"
    log "INFO" "testdb_prepare: ${cmd}"
    exec_command "${cmd}"
}
