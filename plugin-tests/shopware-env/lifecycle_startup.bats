#!/usr/bin/env bats
# bats file_tags=shopware-env,config
bats_require_minimum_version 1.11.0

# Starts the real lifecycle server against a project directory. Its config is
# optional: a project with none starts and its tools take the environment from
# their arguments. A config that is present but cannot be loaded is not "none".

load 'test_helper/common_setup'

INITIALIZE='{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"bats","version":"1"}}}'

setup() {
    # A copy, so the server's log lands outside the checkout.
    SERVER_COPY="${BATS_TEST_TMPDIR}/plugin"
    mkdir -p "${SERVER_COPY}"
    cp -R "${PLUGIN_DIR}/shared" "${PLUGIN_DIR}/mcp-server-lifecycle" "${SERVER_COPY}/"
    rm -f "${SERVER_COPY}/mcp-server-lifecycle/server.log"

    PROJECT="${BATS_TEST_TMPDIR}/project"
    mkdir -p "${PROJECT}"
}

# Runs the server in PROJECT over one initialize request.
_start_server() {
    # shellcheck disable=SC2016  # the inner bash expands its own positional parameters
    run --separate-stderr bash -c 'cd "$1" && PROJECT_ROOT="$1" "$2" <<< "$3"' _ \
        "${PROJECT}" "${SERVER_COPY}/mcp-server-lifecycle/server.sh" "${INITIALIZE}"
}

@test "a project holding no config starts the server" {
    _start_server

    assert_success
    run jq -r 'select(.id == 0) | .result.serverInfo.name' <<< "${output}"
    assert_output "lifecycle-tooling"
}

@test "a second config file that is not valid JSON stops the server, naming the file" {
    mkdir -p "${PROJECT}/.claude"
    printf '{"environment":"native"}\n' > "${PROJECT}/.mcp-php-tooling.json"
    printf '{bad\n' > "${PROJECT}/.claude/.mcp-php-tooling.json"

    _start_server

    assert_failure 1
    assert_output ""
    # This bats-assert has no assert_stderr; asserted through output for its diff.
    output="${stderr}"
    assert_output --partial "${PROJECT}/.claude/.mcp-php-tooling.json is not valid JSON"
}

@test "a config override naming a missing file stops the server, naming the file" {
    export MCP_PHP_TOOLING_CONFIG="${BATS_TEST_TMPDIR}/missing.json"

    _start_server

    assert_failure 1
    assert_output ""
    output="${stderr}"
    assert_output --partial "${MCP_PHP_TOOLING_CONFIG}"
}
