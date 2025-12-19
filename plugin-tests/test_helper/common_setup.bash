#!/bin/bash
# Core test fixtures shared across all plugin hook tests

# Calculate repo root by walking up until we find .bats/ directory
_get_repo_root() {
    local test_dir="${BATS_TEST_DIRNAME}"
    while [[ ! -d "${test_dir}/.bats" ]] && [[ "${test_dir}" != "/" ]]; do
        test_dir="$(dirname "$test_dir")"
    done
    echo "$test_dir"
}

REPO_ROOT="$(_get_repo_root)"

# Load BATS helper libraries
load "${REPO_ROOT}/.bats/bats-support/load"
load "${REPO_ROOT}/.bats/bats-assert/load"

# Create JSON input for hook scripts
make_hook_input() {
    local command="$1"
    printf '{"tool_input": {"command": "%s"}}' "$command"
}

# Run a hook script with a command and capture output
# Note: SCRIPTS_DIR must be set by the plugin-specific helper
run_hook() {
    local script="$1"
    local command="$2"

    if [[ -z "${SCRIPTS_DIR:-}" ]]; then
        fail "SCRIPTS_DIR must be set before calling run_hook"
    fi

    run bash -c 'printf '"'"'{"tool_input": {"command": "%s"}}'"'"' "$1" | bash "$2"' \
        _ "$command" "${SCRIPTS_DIR}/${script}"
}
