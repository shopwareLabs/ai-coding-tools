#!/usr/bin/env bats

# Tests for shared/lsp_bootstrap.sh.
# The bootstrap is sourced by lsp-server-<lang>/lsp.sh files. It reads
# .lsp-<prefix>-tooling.json and decides between: null stub, direct exec, or
# python proxy.
#
# These tests exercise the decision logic by:
#  1. Creating a temp project dir with a test config file
#  2. Sourcing the bootstrap in a subshell with PROJECT_ROOT pointing at the temp dir
#  3. Asserting that `lsp_run_or_null_stub` dispatches to the expected target

setup() {
    SHARED_DIR="$(cd "${BATS_TEST_DIRNAME}/../../plugins/dev-tooling/shared" && pwd)"
    TMPDIR_PROJECT=$(mktemp -d)
    export TMPDIR_PROJECT
}

teardown() {
    rm -rf "${TMPDIR_PROJECT}"
}

_write_config() {
    local json="$1"
    mkdir -p "${TMPDIR_PROJECT}/.claude"
    printf '%s' "$json" > "${TMPDIR_PROJECT}/.claude/.lsp-php-tooling.json"
}

# Common preamble for the `bash -c` block of every test. Keeps the bootstrap
# contract (SCRIPT_DIR, SHARED_DIR, PROJECT_ROOT, CONFIG_*, LSP_DEFAULT_BINARY,
# silent log stub, dry-run flag) in one place so tests only contain what's
# unique to them.
_bootstrap_preamble() {
    printf '%s\n' \
        "set -uo pipefail" \
        "SCRIPT_DIR='${SHARED_DIR}/../lsp-server-php'" \
        "SHARED_DIR='${SHARED_DIR}'" \
        "PROJECT_ROOT='${TMPDIR_PROJECT}'" \
        "CONFIG_PREFIX='php-tooling'" \
        "CONFIG_FILE_PREFIX='.lsp-'" \
        "CONFIG_ENV_VAR_PREFIX='LSP'" \
        "LSP_DEFAULT_BINARY='phpactor'" \
        "log() { :; }; export -f log" \
        "export LSP_DISPATCH_DRY_RUN=1"
}

@test "missing config file -> LSP_DISPATCH_TARGET=null-stub" {
    # No config written.
    run bash -c "
$(_bootstrap_preamble)
source '${SHARED_DIR}/lsp_bootstrap.sh'
lsp_run_or_null_stub 'phpactor language-server'
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"target=null-stub"* ]]
}

@test "enabled=false -> null-stub" {
    _write_config '{"environment":"native","enabled":false,"binary":"phpactor"}'
    run bash -c "
$(_bootstrap_preamble)
source '${SHARED_DIR}/lsp_bootstrap.sh'
lsp_run_or_null_stub 'phpactor language-server'
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"target=null-stub"* ]]
}

@test "enabled=true + environment=native -> direct-exec with binary" {
    _write_config '{"environment":"native","enabled":true,"binary":"phpactor"}'
    run bash -c "
$(_bootstrap_preamble)
source '${SHARED_DIR}/lsp_bootstrap.sh'
lsp_run_or_null_stub 'phpactor language-server'
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"target=direct-exec"* ]]
    [[ "$output" == *"cmd=phpactor language-server"* ]]
}

@test "enabled=true + environment missing -> hard fail with message" {
    _write_config '{"enabled":true,"binary":"phpactor"}'
    # Override the silent log stub so detect_environment's error reaches $output.
    run bash -c "
$(_bootstrap_preamble)
log() { printf '[%s] %s\n' \"\$1\" \"\${*:2}\"; }; export -f log
source '${SHARED_DIR}/lsp_bootstrap.sh'
lsp_run_or_null_stub 'phpactor language-server'
"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Missing 'environment' field"* ]]
}

@test "binary override is read from config" {
    _write_config '{"environment":"native","enabled":true,"binary":"/opt/phpactor/bin/phpactor"}'
    run bash -c "
$(_bootstrap_preamble)
source '${SHARED_DIR}/lsp_bootstrap.sh'
echo \"LSP_BINARY=\${LSP_BINARY}\"
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"LSP_BINARY=/opt/phpactor/bin/phpactor"* ]]
}

@test "containerized + preflight passes -> python-proxy" {
    # Write a docker-compose config. The bootstrap will call
    # _lsp_preflight_container_binary to verify the binary inside the container.
    # We override that function to return 0, simulating a passing preflight
    # without needing docker to be installed on the test host. We also override
    # _compose_resolve_workdir so the test doesn't depend on the real function
    # finding COMPOSE_WORKDIR_OVERRIDE in environment.sh's config parsing.
    _write_config '{"environment":"docker-compose","docker-compose":{"service":"web","workdir":"/var/www/html"},"enabled":true,"binary":"phpactor"}'
    run bash -c "
$(_bootstrap_preamble)
source '${SHARED_DIR}/lsp_bootstrap.sh'
_lsp_preflight_container_binary() { return 0; }
_compose_resolve_workdir() { echo '/var/www/html'; }
wrap_command() { echo \"docker compose exec -T web \$1\"; }
lsp_run_or_null_stub 'phpactor language-server'
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"target=python-proxy"* ]]
    [[ "$output" == *"wrapped=docker compose exec -T web phpactor language-server"* ]]
}

@test "containerized + preflight fails -> null-stub" {
    _write_config '{"environment":"docker-compose","docker-compose":{"service":"web","workdir":"/var/www/html"},"enabled":true,"binary":"phpactor"}'
    run bash -c "
$(_bootstrap_preamble)
source '${SHARED_DIR}/lsp_bootstrap.sh'
_lsp_preflight_container_binary() { return 1; }  # force fail
wrap_command() { echo \"docker compose exec -T web \$1\"; }
lsp_run_or_null_stub 'phpactor language-server'
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"target=null-stub"* ]]
    [[ "$output" == *"preflight failed"* ]]
}

@test "docker-compose workdir is resolved to real container path before proxy exec" {
    # Regression: _lsp_exec_proxy was called with LINT_WORKDIR still set to
    # the lazy sentinel "(resolved at call time)" in docker-compose mode,
    # poisoning lsp_proxy.py's --container-root and breaking URI rewriting.
    # lsp_run_or_null_stub must call _compose_resolve_workdir and reassign
    # LINT_WORKDIR to the real path before dispatching.
    _write_config '{"environment":"docker-compose","docker-compose":{"service":"web","workdir":"/var/www/html"},"enabled":true,"binary":"phpactor"}'
    run bash -c "
$(_bootstrap_preamble)
source '${SHARED_DIR}/lsp_bootstrap.sh'
_lsp_preflight_container_binary() { return 0; }
_compose_resolve_workdir() { echo '/resolved/container/path'; }
wrap_command() { echo \"stub \$1\"; }
# Observe LINT_WORKDIR at the moment the proxy would be exec'd.
_lsp_exec_proxy() { echo \"observed_container_root=\${LINT_WORKDIR}\"; exit 0; }
lsp_run_or_null_stub 'phpactor language-server'
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"observed_container_root=/resolved/container/path"* ]]
    [[ "$output" != *"(resolved at call time)"* ]]
}

@test "docker-compose workdir resolution failure falls back to null stub" {
    # If _compose_resolve_workdir fails (e.g. service not running), the
    # dispatcher must route to the null stub rather than passing a broken
    # workdir to the proxy.
    _write_config '{"environment":"docker-compose","docker-compose":{"service":"web","workdir":"/var/www/html"},"enabled":true,"binary":"phpactor"}'
    run bash -c "
$(_bootstrap_preamble)
source '${SHARED_DIR}/lsp_bootstrap.sh'
_lsp_preflight_container_binary() { return 0; }
_compose_resolve_workdir() { echo 'simulated resolve error'; return 1; }
wrap_command() { echo \"stub \$1\"; }
lsp_run_or_null_stub 'phpactor language-server'
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"target=null-stub"* ]]
    [[ "$output" == *"failed to resolve docker-compose workdir"* ]]
}

@test "preflight does not consume bytes from the LSP client stdin pipe" {
    # Regression: _lsp_preflight_container_binary used \`docker exec -i ...\`
    # which inherits the script's stdin. Claude Code writes the initialize
    # request into the LSP pipe eagerly, and docker-exec-i would siphon those
    # bytes into the preflight subprocess, which discards them — causing the
    # real LSP server to wait forever for bytes that were already consumed.
    # Preflight must redirect its stdin from /dev/null.
    #
    # We simulate docker-exec-i's stdin-eating behavior with a plain 'cat'
    # in the wrap_command override: cat reads until EOF. If preflight runs
    # without </dev/null, cat eats the whole pipe and the bytes are gone.
    _write_config '{"environment":"native","enabled":true,"binary":"phpactor"}'
    run bash -c "
$(_bootstrap_preamble)
source '${SHARED_DIR}/lsp_bootstrap.sh'
wrap_command() { echo 'cat'; }  # simulate docker-exec-i stdin forwarding
_lsp_preflight_container_binary 'phpactor' || true
# Whatever preflight did NOT eat should still be on our stdin.
remaining=\$(cat)
echo \"remaining=\${remaining}\"
" <<< 'INITIALIZE_REQUEST_PAYLOAD'
    [ "$status" -eq 0 ]
    [[ "$output" == *"remaining=INITIALIZE_REQUEST_PAYLOAD"* ]]
}

@test "malformed JSON config falls back to null stub" {
    # Write syntactically invalid JSON.
    mkdir -p "${TMPDIR_PROJECT}/.claude"
    printf '{broken json not valid' > "${TMPDIR_PROJECT}/.claude/.lsp-php-tooling.json"
    run bash -c "
$(_bootstrap_preamble)
source '${SHARED_DIR}/lsp_bootstrap.sh'
lsp_run_or_null_stub 'phpactor language-server'
"
    [ "$status" -eq 0 ]
    # Malformed JSON -> jq returns an error -> our `|| echo "false"` fallback
    # kicks in, LSP_ENABLED becomes "false", dispatcher routes to null stub.
    [[ "$output" == *"target=null-stub"* ]]
}
