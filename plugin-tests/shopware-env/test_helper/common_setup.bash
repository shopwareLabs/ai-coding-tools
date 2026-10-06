#!/bin/bash
# Test fixtures for shopware-env hook and tool testing

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

PLUGIN_DIR="${REPO_ROOT}/plugins/shopware-env"
SCRIPTS_DIR="${PLUGIN_DIR}/hooks/scripts"

setup_config() {
    local prefix="$1"
    local content="$2"
    export CLAUDE_PROJECT_DIR="${BATS_TEST_TMPDIR}"
    printf '%s\n' "$content" > "${BATS_TEST_TMPDIR}/.mcp-${prefix}.json"
}

# Run a PreToolUse hook script with the hook input's cwd set. Codex sets no
# CLAUDE_PROJECT_DIR, so the cwd is how it names the project.
# Args: $1 = script name, $2 = bash command, $3 = cwd
run_hook_with_cwd() {
    local payload
    payload=$(jq -cn --arg cmd "$2" --arg cwd "$3" '{tool_input: {command: $cmd}, cwd: $cwd}')
    run bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload" "${SCRIPTS_DIR}/$1"
}

# Create a project directory holding an MCP config of the given environment,
# distinct from the one setup_config writes at BATS_TEST_TMPDIR.
# Args: $1 = config prefix, $2 = environment
# Stdout: the project directory
make_cwd_project() {
    local dir="${BATS_TEST_TMPDIR}/cwd-project"
    mkdir -p "$dir"
    jq -n --arg env "$2" '{environment: $env}' > "${dir}/.mcp-${1}.json"
    printf '%s\n' "$dir"
}

# Setup for MCP lifecycle tool tests.
# Stubs log/exec_command, sources environment.sh + resolve_env.sh, then
# sources the given tool library.
# Args: $1=library path to source
setup_lifecycle_mcp_env() {
    local lib_path="$1"
    printf '%s\n' '{"environment":"native"}' > "${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    LIFECYCLE_HAS_CONFIG="true"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    log() { :; }
    source "${PLUGIN_DIR}/shared/environment.sh"
    exec_command() { printf '%s\n' "$1"; }
    source "${PLUGIN_DIR}/mcp-server-lifecycle/lib/resolve_env.sh"
    # shellcheck source=/dev/null  # lib_path is caller-supplied at runtime; each test passes a different tool library
    source "${lib_path}"
}

setup() {
    setup_config "php-tooling" '{"environment": "native"}'
}

teardown() {
    unset CLAUDE_PROJECT_DIR
}
