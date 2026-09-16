#!/bin/bash
# Core test fixtures shared across all plugin hook tests

# Calculate repo root by walking up until we find .bats/ directory
_get_repo_root() {
    local test_dir="${BATS_TEST_DIRNAME}"
    while [[ ! -d "${test_dir}/.bats" ]] && [[ "${test_dir}" != "/" ]]; do
        test_dir="$(dirname "$test_dir")"
    done
    printf '%s\n' "$test_dir"
}

REPO_ROOT="$(_get_repo_root)"

# Load BATS helper libraries
load "${REPO_ROOT}/.bats/bats-support/load"
load "${REPO_ROOT}/.bats/bats-assert/load"

# Run a hook script with a command and capture output
# Note: SCRIPTS_DIR must be set by the plugin-specific helper
run_hook() {
    local script="$1"
    local command="$2"

    if [[ -z "${SCRIPTS_DIR:-}" ]]; then
        fail "SCRIPTS_DIR must be set before calling run_hook"
    fi

    local payload
    payload=$(jq -cn --arg cmd "$command" '{tool_input: {command: $cmd}}')

    run bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload" "${SCRIPTS_DIR}/${script}"
}

# Assert that a hook script blocks a command and suggests a specific MCP tool
# Args: $1=script name, $2=bash command, $3=expected suggestion substring
assert_hook_blocks() {
    local script="$1" command="$2" suggestion="$3"
    run_hook "$script" "$command"
    assert_failure 2
    assert_output --partial "$suggestion"
}

# Put a refusing stand-in for every container CLI ahead of the real ones on
# PATH. No suite may execute docker, docker-compose, vagrant or ddev — a
# container command is only ever constructed as a string and inspected — so a
# call that reaches one is a defect in the fixture, and this makes it loud
# rather than dependent on whether the binary happens to be installed.
#
# PATH is the level that matters, not a shell function: a stub that falls
# through with `command docker "$@"` bypasses a function by design, and a
# machine with docker installed then runs the real CLI while a machine without
# it sees a command-not-found that the wrapper swallows — the suite passes in
# both cases and asserts nothing about either. Under this, both are the same
# loud failure naming the invocation.
#
# A test that means to drive a container CLI installs its own stub in front —
# a shell function answers before PATH is consulted, which leaves the
# deliberate `command docker "$@"` fallthroughs working as written.
# Globals: sets CONTAINER_CLI_LOG to a file recording every rejected invocation
container_cli_refuse_real() {
    local bin_dir="${BATS_TEST_TMPDIR}/container-cli-refused"
    mkdir -p "${bin_dir}"

    CONTAINER_CLI_LOG="${BATS_TEST_TMPDIR}/container-cli-invocations"
    : > "${CONTAINER_CLI_LOG}"
    export CONTAINER_CLI_LOG

    local binary
    for binary in docker docker-compose vagrant ddev; do
        cat > "${bin_dir}/${binary}" <<'REFUSED'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "${CONTAINER_CLI_LOG}"
printf 'Refusing to run: this suite constructed a container command and is not allowed to execute one.\n' >&2
exit 97
REFUSED
        chmod +x "${bin_dir}/${binary}"
    done

    PATH="${bin_dir}:${PATH}"
    export PATH
}

# True when a container CLI was reached since container_cli_refuse_real ran.
# A suite that drives a container path asserts this where the path must not
# execute anything, which turns "the command string looks right" into "and no
# binary was run to produce it".
# Returns: 0 when something was invoked, 1 when nothing was
container_cli_was_invoked() {
    [[ -s "${CONTAINER_CLI_LOG:-}" ]]
}
