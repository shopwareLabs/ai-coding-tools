#!/usr/bin/env bats
# bats file_tags=dev-tooling,mcp-tools,php
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

setup() {
    setup_php_mcp_env "${PLUGIN_DIR}" "${PLUGIN_DIR}/mcp-server-php/lib/console.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE CONSOLE_FAKE_CMD
}

# Replace the wrapped invocation with a controlled shell snippet, so the
# file-capture path runs a real command instead of the absent bin/console.
_stub_wrapped_command() {
    CONSOLE_FAKE_CMD="$1"
    wrap_command() { printf '%s\n' "${CONSOLE_FAKE_CMD}"; }
}

# Make the wrapped invocation print the command it was handed, so the captured
# file holds the constructed bin/console line.
_echo_wrapped_command() {
    wrap_command() { printf 'printf %%s %s\n' "$(printf '%q' "$1")"; }
}

# Put one argument set through the vendored MCP validator against the real
# tools.json, the way the server does before it dispatches a tool.
_validate_console_run() {
    MCP_TOOLS_LIST_FILE="${PLUGIN_DIR}/mcp-server-php/tools.json"
    # shellcheck source=/dev/null  # sourced for validate_tool_arguments only
    source "${PLUGIN_DIR}/shared/mcpserver_core.sh"
    validate_tool_arguments "console_run" "$1"
}

# --- Basic command construction ---

@test "console: runs bin/console with command name" {
    run tool_console_run '{"command":"cache:clear"}'
    assert_success
    assert_output --partial 'bin/console "cache:clear"'
}

@test "console: missing command returns error" {
    run tool_console_run '{}'
    assert_failure
    assert_output --partial "'command' parameter is required"
}

@test "console: invalid command chars are rejected" {
    run tool_console_run '{"command":"cache:clear; rm -rf /"}'
    assert_failure
    assert_output --partial "Invalid command name format"
}

@test "console: arguments are appended after command" {
    run tool_console_run '{"command":"plugin:install","arguments":["MyPlugin"]}'
    assert_success
    assert_output --partial '"plugin:install" "MyPlugin"'
}

@test "console: argument with a pipe is quoted as one argument" {
    run tool_console_run '{"command":"plugin:install","arguments":["Foo|Bar"]}'
    assert_success
    assert_output --partial '"Foo|Bar"'
}

@test "console: argument with a space is quoted as one argument" {
    run tool_console_run '{"command":"plugin:install","arguments":["My Plugin"]}'
    assert_success
    assert_output --partial '"My Plugin"'
}

# --- Environment and verbosity ---

@test "console: env option adds --env flag" {
    run tool_console_run '{"command":"cache:clear","env":"prod"}'
    assert_success
    assert_output --partial '--env="prod"'
}

@test "console: env value outside the old enum adds --env flag" {
    run tool_console_run '{"command":"cache:clear","env":"staging"}'
    assert_success
    assert_output --partial '--env="staging"'
}

@test "console: env absent emits no --env flag" {
    run tool_console_run '{"command":"cache:clear"}'
    assert_success
    refute_output --partial '--env'
}

@test "console: configured .console.env default applies when env is absent" {
    printf '%s\n' '{"environment":"native","console":{"env":"staging"}}' > "${LINT_CONFIG_FILE}"
    run tool_console_run '{"command":"cache:clear"}'
    assert_success
    assert_output --partial '--env="staging"'
}

@test "console schema: validation accepts an env name outside the old enum" {
    run _validate_console_run '{"command":"cache:clear","env":"staging"}'
    assert_success
    assert_output ""
}

@test "console schema: validation rejects an env value carrying a shell metacharacter" {
    run _validate_console_run '{"command":"cache:clear","env":"prod; rm -rf /"}'
    assert_failure
    assert_output --partial "env"
    assert_output --partial "pattern"
}

@test "console schema: validation rejects an env value longer than 32 characters" {
    run _validate_console_run "{\"command\":\"cache:clear\",\"env\":\"$(printf 'e%.0s' {1..33})\"}"
    assert_failure
    assert_output --partial "env"
    assert_output --partial "pattern"
}

@test "console schema: validation accepts an output_file string" {
    run _validate_console_run '{"command":"cache:clear","output_file":"var/dump.txt"}'
    assert_success
    assert_output ""
}

@test "console: verbosity quiet adds -q" {
    run tool_console_run '{"command":"cache:clear","verbosity":"quiet"}'
    assert_success
    assert_output --partial "-q"
}

@test "console: verbosity very-verbose adds -vv" {
    run tool_console_run '{"command":"cache:clear","verbosity":"very-verbose"}'
    assert_success
    assert_output --partial "-vv"
}

@test "console: no_debug=true adds --no-debug flag" {
    run tool_console_run '{"command":"cache:clear","no_debug":true}'
    assert_success
    assert_output --partial "--no-debug"
}

@test "console: no_interaction=true adds --no-interaction flag" {
    run tool_console_run '{"command":"cache:clear","no_interaction":true}'
    assert_success
    assert_output --partial "--no-interaction"
}

# --- Options object types ---

@test "console: boolean option true becomes --flag" {
    run tool_console_run '{"command":"cache:clear","options":{"force":true}}'
    assert_success
    assert_output --partial -- '--"force"'
}

@test "console: boolean option false is skipped" {
    run tool_console_run '{"command":"cache:clear","options":{"force":false}}'
    assert_success
    refute_output --partial "force"
}

@test "console: string option becomes --key=value" {
    run tool_console_run '{"command":"cache:clear","options":{"output":"json"}}'
    assert_success
    assert_output --partial -- '--"output"="json"'
}

@test "console: string option value with a pipe is quoted as one argument" {
    run tool_console_run '{"command":"cache:clear","options":{"output":"a|b"}}'
    assert_success
    assert_output --partial -- '--"output"="a|b"'
}

@test "console: array option value with a space is quoted as one argument" {
    run tool_console_run '{"command":"cache:clear","options":{"tag":["my tag"]}}'
    assert_success
    assert_output --partial -- '--"tag"="my tag"'
}

# --- Values that cannot be quoted safely are refused ---

console_refuses_single_quote() {
    local payload="$1"
    run tool_console_run "${payload}"
    assert_failure
    assert_output --partial "Refusing to run"
    assert_output --partial "contains a single quote"
}

bats_test_function --description "console: argument containing a single quote is refused" \
    -- console_refuses_single_quote "{\"command\":\"plugin:install\",\"arguments\":[\"My'Plugin\"]}"
bats_test_function --description "console: env containing a single quote is refused" \
    -- console_refuses_single_quote "{\"command\":\"cache:clear\",\"env\":\"pr'od\"}"
bats_test_function --description "console: option name containing a single quote is refused" \
    -- console_refuses_single_quote "{\"command\":\"cache:clear\",\"options\":{\"out'put\":\"json\"}}"
bats_test_function --description "console: string option value containing a single quote is refused" \
    -- console_refuses_single_quote "{\"command\":\"cache:clear\",\"options\":{\"output\":\"js'on\"}}"
bats_test_function --description "console: array option value containing a single quote is refused" \
    -- console_refuses_single_quote "{\"command\":\"cache:clear\",\"options\":{\"tag\":[\"my'tag\"]}}"

# --- Line breaks cannot be embedded in a single command ---

console_refuses_linebreak() {
    local payload="$1"
    run tool_console_run "${payload}"
    assert_failure
    assert_output --partial "Refusing to run: arguments contain a line break, which cannot be embedded in a single command."
}

bats_test_function --description "console: argument containing an interior line break is refused" \
    -- console_refuses_linebreak "{\"command\":\"plugin:install\",\"arguments\":[\"My\\nPlugin\"]}"
bats_test_function --description "console: array option value containing an interior line break is refused" \
    -- console_refuses_linebreak "{\"command\":\"cache:clear\",\"options\":{\"tag\":[\"my\\ntag\"]}}"
bats_test_function --description "console: env containing a trailing line break is refused" \
    -- console_refuses_linebreak "{\"command\":\"cache:clear\",\"env\":\"prod\\n\"}"
bats_test_function --description "console: option name containing a line break is refused" \
    -- console_refuses_linebreak "{\"command\":\"cache:clear\",\"options\":{\"bad\\nkey\":\"x\"}}"

# --- Malformed top-level arguments are refused, not silently defaulted ---

@test "console: malformed top-level JSON is refused rather than defaulting silently" {
    run tool_console_run '{not valid json'
    assert_failure
    assert_output --partial "Refusing to run: could not parse arguments as JSON"
}

# --- output_file: stdout captured to a file ---

@test "console: output_file receives the command's stdout verbatim" {
    _stub_wrapped_command 'printf "line one\nline two\n"'
    local target="${BATS_TEST_TMPDIR}/cap/dump.txt"
    run tool_console_run "{\"command\":\"debug:container\",\"output_file\":\"${target}\"}"
    assert_success
    run cat "${target}"
    assert_output $'line one\nline two'
}

@test "console: output_file response carries the summary and not the payload" {
    _stub_wrapped_command 'printf "PAYLOAD-MARKER\n"'
    local target="${BATS_TEST_TMPDIR}/dump.txt"
    run tool_console_run "{\"command\":\"debug:container\",\"output_file\":\"${target}\"}"
    assert_success
    assert_output --partial "Wrote stdout to ${target}"
    assert_output --partial "Bytes written: 15"
    assert_output --partial "Exit status: 0"
    refute_output --partial "PAYLOAD-MARKER"
}

@test "console: output_file keeps stderr in the response" {
    _stub_wrapped_command 'printf "payload\n"; printf "a warning\n" >&2'
    local target="${BATS_TEST_TMPDIR}/dump.txt"
    run tool_console_run "{\"command\":\"debug:container\",\"output_file\":\"${target}\"}"
    assert_success
    assert_output --partial "a warning"
}

@test "console: output_file applies the noise filter to stderr" {
    _stub_wrapped_command 'printf "payload\n"; printf "Xdebug: [Step Debug] Could not connect to debugging client.\nreal warning\n" >&2'
    local target="${BATS_TEST_TMPDIR}/dump.txt"
    run tool_console_run "{\"command\":\"debug:container\",\"output_file\":\"${target}\"}"
    assert_success
    assert_output --partial "real warning"
    refute_output --partial "Step Debug"
}

@test "console: an existing regular output_file is overwritten on success" {
    local target="${BATS_TEST_TMPDIR}/dump.txt"
    printf 'earlier run\n' > "${target}"
    _stub_wrapped_command 'printf "fresh\n"'
    run tool_console_run "{\"command\":\"debug:container\",\"output_file\":\"${target}\"}"
    assert_success
    run cat "${target}"
    assert_output "fresh"
}

@test "console: a failed command leaves a pre-existing output_file untouched" {
    local target="${BATS_TEST_TMPDIR}/dump.txt"
    printf 'earlier run\n' > "${target}"
    _stub_wrapped_command 'printf "partial\n"; exit 3'
    run tool_console_run "{\"command\":\"debug:container\",\"output_file\":\"${target}\"}"
    assert_failure 3
    run cat "${target}"
    assert_output "earlier run"
}

@test "console: a failed command leaves no temporary file beside the target" {
    local dir="${BATS_TEST_TMPDIR}/cap"
    mkdir -p "${dir}"
    printf 'earlier run\n' > "${dir}/dump.txt"
    _stub_wrapped_command 'printf "partial\n"; exit 3'
    run tool_console_run "{\"command\":\"debug:container\",\"output_file\":\"${dir}/dump.txt\"}"
    assert_failure 3
    run ls "${dir}"
    assert_output "dump.txt"
}

@test "console: a failed command returns its stdout in the response" {
    local target="${BATS_TEST_TMPDIR}/dump.txt"
    _stub_wrapped_command 'printf "diagnostic line\n"; exit 4'
    run tool_console_run "{\"command\":\"debug:container\",\"output_file\":\"${target}\"}"
    assert_failure 4
    assert_output --partial "diagnostic line"
    assert_output --partial "was not written"
}

@test "console: a failed command keeps stdout and stderr on separate lines" {
    local target="${BATS_TEST_TMPDIR}/dump.txt"
    _stub_wrapped_command 'printf "no trailing newline"; printf "stderr line\n" >&2; exit 6'
    run tool_console_run "{\"command\":\"debug:container\",\"output_file\":\"${target}\"}"
    assert_failure 6
    assert_line "no trailing newline"
    assert_line "stderr line"
}

@test "console: output_file pointing at a symlink is refused" {
    local target="${BATS_TEST_TMPDIR}/link.txt"
    ln -s "${BATS_TEST_TMPDIR}/elsewhere.txt" "${target}"
    run tool_console_run "{\"command\":\"debug:container\",\"output_file\":\"${target}\"}"
    assert_failure
    assert_output --partial "\"${target}\" exists as a symbolic link"
}

@test "console: output_file pointing at a directory is refused" {
    local target="${BATS_TEST_TMPDIR}/adir"
    mkdir -p "${target}"
    run tool_console_run "{\"command\":\"debug:container\",\"output_file\":\"${target}\"}"
    assert_failure
    assert_output --partial "\"${target}\" exists as a directory"
}

@test "console: a relative output_file resolves against the working directory" {
    cd "${BATS_TEST_TMPDIR}"
    _stub_wrapped_command 'printf "ok\n"'
    run tool_console_run '{"command":"debug:container","output_file":"nested/dump.txt"}'
    assert_success
    assert_output --partial "Wrote stdout to ${BATS_TEST_TMPDIR}/nested/dump.txt"
    run cat "${BATS_TEST_TMPDIR}/nested/dump.txt"
    assert_output "ok"
}

@test "console: an output_file beginning with a dash is pinned to the working directory" {
    cd "${BATS_TEST_TMPDIR}"
    _stub_wrapped_command 'printf "ok\n"'
    run tool_console_run '{"command":"debug:container","output_file":"-dash.txt"}'
    assert_success
    assert_output --partial "Wrote stdout to ${BATS_TEST_TMPDIR}/./-dash.txt"
    run cat -- "${BATS_TEST_TMPDIR}/-dash.txt"
    assert_output "ok"
}

@test "console: an output_file longer than 4096 bytes is refused" {
    local long
    long="${BATS_TEST_TMPDIR}/$(printf 'a%.0s' {1..4097})"
    run tool_console_run "{\"command\":\"debug:container\",\"output_file\":\"${long}\"}"
    assert_failure
    assert_output --partial '"output_file" is longer than 4096 bytes'
}

@test "console: an output_file at exactly 4096 bytes passes the length cap" {
    # No host can create a 4096-byte path, so only the cap's boundary is
    # asserted here: this value must not be the one the cap rejects.
    local at_cap
    at_cap="${BATS_TEST_TMPDIR}/$(printf 'a%.0s' $(seq 1 $(( 4095 - ${#BATS_TEST_TMPDIR} ))))"
    run tool_console_run "{\"command\":\"debug:container\",\"output_file\":\"${at_cap}\"}"
    refute_output --partial "is longer than 4096 bytes"
}

@test "console: an empty output_file behaves as an absent parameter" {
    run tool_console_run '{"command":"cache:clear","output_file":""}'
    assert_success
    assert_output 'bin/console "cache:clear"'
}

@test "console: env and output_file compose in one call" {
    _echo_wrapped_command
    local target="${BATS_TEST_TMPDIR}/dump.txt"
    run tool_console_run "{\"command\":\"debug:container\",\"env\":\"staging\",\"output_file\":\"${target}\"}"
    assert_success
    run cat "${target}"
    assert_output --partial '--env="staging"'
}

# --- feature_all: FEATURE_ALL inside the wrapped command ---

# Route the constructed command through the real wrap_command from
# shared/environment.sh, so the assertion sees the string the target
# environment's shell finally receives rather than the unwrapped input.
_wrap_with_real_environment() {
    exec_command() { wrap_command "$1"; }
}

# Stand in for the docker-compose resolvers, which query a running compose
# project at call time; _compose_wrap_command itself stays real.
_stub_compose_resolution() {
    source "${PLUGIN_DIR}/shared/docker-compose.sh"
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() { printf '%s\n' "shop"; }
    _compose_resolve_workdir() { printf '%s\n' "/var/www/html"; }
}

@test "console: feature_all opens the wrapped command under the native environment" {
    _wrap_with_real_environment
    LINT_ENV="native"
    run tool_console_run '{"command":"cache:clear","feature_all":"major"}'
    assert_success
    assert_output 'FEATURE_ALL=major bin/console "cache:clear"'
}

@test "console: feature_all opens the containerized command under docker-compose" {
    _wrap_with_real_environment
    _stub_compose_resolution
    LINT_ENV="docker-compose"
    run tool_console_run '{"command":"cache:clear","feature_all":"major"}'
    assert_success
    assert_output --partial "bash -c 'cd /var/www/html && FEATURE_ALL=major bin/console \"cache:clear\"'"
}

@test "console: feature_all absent leaves the command free of FEATURE_ALL" {
    _wrap_with_real_environment
    LINT_ENV="native"
    run tool_console_run '{"command":"cache:clear"}'
    assert_success
    assert_output 'bin/console "cache:clear"'
}

@test "console: feature_all value outside the enum is refused by the tool" {
    run tool_console_run '{"command":"cache:clear","feature_all":"minor"}'
    assert_failure
    assert_output --partial 'Invalid feature_all value'
}

@test "console schema: validation rejects a feature_all value outside the enum" {
    run _validate_console_run '{"command":"cache:clear","feature_all":"minor"}'
    assert_failure
    assert_output --partial "feature_all"
    assert_output --partial "allowed: major, true"
}

@test "console schema: validation accepts feature_all \"major\"" {
    run _validate_console_run '{"command":"cache:clear","feature_all":"major"}'
    assert_success
    assert_output ""
}

@test "console: feature_all, env and output_file compose in one call" {
    _echo_wrapped_command
    local target="${BATS_TEST_TMPDIR}/dump.txt"
    run tool_console_run "{\"command\":\"debug:container\",\"feature_all\":\"major\",\"env\":\"staging\",\"output_file\":\"${target}\"}"
    assert_success
    run cat "${target}"
    assert_output 'FEATURE_ALL=major bin/console "debug:container" --env="staging"'
}

# --- Console list ---

@test "console list: non-llm format passes --format to bin/console" {
    run tool_console_list '{"format":"json"}'
    assert_success
    assert_output --partial 'bin/console list --format="json"'
}

@test "console list: namespace is quoted as one argument" {
    run tool_console_list '{"namespace":"cache","format":"json"}'
    assert_success
    assert_output --partial 'bin/console list "cache" --format="json"'
}

@test "console list: format containing a trailing line break is refused" {
    run tool_console_list "{\"format\":\"json\\n\"}"
    assert_failure
    assert_output --partial "Refusing to run: arguments contain a line break, which cannot be embedded in a single command."
}

@test "console list: malformed top-level JSON is refused rather than defaulting silently" {
    run tool_console_list '{not valid json'
    assert_failure
    assert_output --partial "Refusing to run: could not parse arguments as JSON"
}
