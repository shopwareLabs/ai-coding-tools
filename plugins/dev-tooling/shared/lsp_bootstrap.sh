#!/usr/bin/env bash
# Common bootstrap for LSP dispatchers in lsp-server-<lang>/lsp.sh.
#
# Caller contract (must set before sourcing):
#   - SCRIPT_DIR, SHARED_DIR, PROJECT_ROOT
#   - CONFIG_PREFIX (e.g., "php-tooling")
#   - CONFIG_FILE_PREFIX=".lsp-"
#   - CONFIG_ENV_VAR_PREFIX="LSP"
#   - LSP_DEFAULT_BINARY (e.g., "phpactor")
#
# After sourcing, exposes:
#   - LINT_ENV, LINT_WORKDIR (from shared/environment.sh)
#   - LSP_ENABLED ("true" or "false")
#   - LSP_BINARY (from config, defaulting to LSP_DEFAULT_BINARY)
#   - Function `lsp_run_or_null_stub <binary-cmd>`
#
# The function exec's into one of three targets:
#   1. shared/lsp_null.sh         (disabled, config missing, or preflight failed)
#   2. <binary-cmd> directly       (environment: native)
#   3. python3 shared/lsp_proxy.py (containerized environment)
#
# Test hook: when LSP_DISPATCH_DRY_RUN is set, the function prints the
# target decision to stdout instead of exec'ing. Used by BATS tests.

set -uo pipefail
shopt -s inherit_errexit 2>/dev/null || true

: "${SCRIPT_DIR:?SCRIPT_DIR required}"
: "${SHARED_DIR:?SHARED_DIR required}"
: "${PROJECT_ROOT:?PROJECT_ROOT required}"
: "${CONFIG_PREFIX:?CONFIG_PREFIX required}"
: "${CONFIG_FILE_PREFIX:?CONFIG_FILE_PREFIX required}"
: "${CONFIG_ENV_VAR_PREFIX:?CONFIG_ENV_VAR_PREFIX required}"
: "${LSP_DEFAULT_BINARY:?LSP_DEFAULT_BINARY required}"

# shared/config.sh needs `log` from mcpserver_core.sh. We don't want the full
# MCP server runtime loaded for an LSP, so provide a minimal log stub that
# writes to stderr.
if ! declare -f log >/dev/null 2>&1; then
    log() {
        local level="$1"
        shift
        printf '[lsp-%s] %s\n' "${level,,}" "$*" >&2
    }
    export -f log
fi

# Function definitions come BEFORE any `source` call that could fall back into
# them. Bash does not hoist functions, so defining them later would make the
# fallback paths in `source config.sh` and `load_config` fail with
# "command not found" at the exact moment the null stub is supposed to fire.

_lsp_exec_null_stub() {
    local reason="${1:-}"
    if [[ -n "$reason" ]]; then
        log "INFO" "dispatching to null stub: $reason"
    fi
    if [[ "${LSP_DISPATCH_DRY_RUN:-}" == "1" ]]; then
        echo "target=null-stub reason=${reason:-unknown}"
        exit 0
    fi
    exec bash "${SHARED_DIR}/lsp_null.sh"
}

_lsp_exec_direct() {
    local cmd="$1"
    if [[ "${LSP_DISPATCH_DRY_RUN:-}" == "1" ]]; then
        echo "target=direct-exec cmd=${cmd}"
        exit 0
    fi
    # shellcheck disable=SC2086
    exec ${cmd}
}

_lsp_exec_proxy() {
    local wrapped="$1"
    if [[ "${LSP_DISPATCH_DRY_RUN:-}" == "1" ]]; then
        echo "target=python-proxy wrapped=${wrapped}"
        exit 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        log "ERROR" "python3 not found on PATH; required for containerized LSP"
        log "ERROR" "install python3 or change environment to 'native' in the LSP config"
        exit 1
    fi
    exec python3 "${SHARED_DIR}/lsp_proxy.py" \
        --host-root "${PROJECT_ROOT}" \
        --container-root "${LINT_WORKDIR}" \
        --wrapper "${wrapped}"
}

_lsp_preflight_container_binary() {
    local binary="$1"
    # Use wrap_command to build `<env-wrapper> command -v <binary>` and exec it.
    # Exit code != 0 means binary not available in the containerized context.
    #
    # CRITICAL: redirect stdin from /dev/null. The wrapped command uses
    # `docker exec -i` which forwards host stdin into the container. Our
    # stdin is the LSP client's pipe, and it may already contain the
    # initialize request. Without </dev/null, docker exec silently consumes
    # those bytes and hands them to `command -v`, which discards them — the
    # LSP server then waits forever for bytes that were eaten by preflight.
    local check_cmd
    check_cmd=$(wrap_command "command -v ${binary}")
    if ! eval "${check_cmd}" </dev/null >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# shared/config.sh reads CONFIG_FILE_PREFIX and CONFIG_ENV_VAR_PREFIX.
# If config can't be loaded, fall back to the null stub silently.
if ! source "${SHARED_DIR}/config.sh" 2>/dev/null; then
    _lsp_exec_null_stub "config.sh failed to source"
fi

# Load config. If load_config fails (file missing/unreadable), fall back to stub.
if ! load_config "${PROJECT_ROOT}" 2>/dev/null; then
    _lsp_exec_null_stub "no .lsp-${CONFIG_PREFIX}.json found"
fi

# shared/environment.sh is reused unchanged.
# shellcheck source=/dev/null
source "${SHARED_DIR}/environment.sh"

# Read LSP settings from the config file.
LSP_ENABLED=$(jq -r '.enabled // false' "${LINT_CONFIG_FILE}" 2>/dev/null || echo "false")
LSP_BINARY=$(jq -r ".binary // \"${LSP_DEFAULT_BINARY}\"" "${LINT_CONFIG_FILE}" 2>/dev/null || echo "${LSP_DEFAULT_BINARY}")
export LSP_ENABLED LSP_BINARY

if [[ "${LSP_ENABLED}" != "true" ]]; then
    _lsp_exec_null_stub "enabled=${LSP_ENABLED}"
fi

# detect_environment hard-fails if `environment` is missing, which is what we want.
detect_environment "${PROJECT_ROOT}"

lsp_run_or_null_stub() {
    local binary_cmd="$1"

    case "${LINT_ENV}" in
        native)
            _lsp_exec_direct "${binary_cmd}"
            ;;
        docker|docker-compose|vagrant|ddev)
            if ! _lsp_preflight_container_binary "${LSP_BINARY}"; then
                _lsp_exec_null_stub "preflight failed: ${LSP_BINARY} not found in ${LINT_ENV} context"
            fi
            # docker-compose sets LINT_WORKDIR to a lazy sentinel; resolve it now
            # so the proxy's URI rewriter receives the real container path.
            if [[ "${LINT_ENV}" == "docker-compose" ]]; then
                LINT_WORKDIR=$(_compose_resolve_workdir) || {
                    log "ERROR" "failed to resolve docker-compose workdir: ${LINT_WORKDIR}"
                    _lsp_exec_null_stub "failed to resolve docker-compose workdir"
                }
            fi
            local wrapped
            wrapped=$(wrap_command "${binary_cmd}")
            _lsp_exec_proxy "${wrapped}"
            ;;
        *)
            log "ERROR" "unsupported environment: ${LINT_ENV}"
            _lsp_exec_null_stub "unsupported environment"
            ;;
    esac
}
