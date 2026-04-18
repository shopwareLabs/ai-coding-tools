#!/usr/bin/env bash
# PHP LSP dispatcher for the dev-tooling plugin.
#
# Invoked by Claude Code when a .php file is opened (via .lsp.json entry).
# Thin entry: sets the caller-contract variables expected by shared/lsp_bootstrap.sh,
# sources the bootstrap, then delegates dispatch.

set -uo pipefail
shopt -s inherit_errexit 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "${SCRIPT_DIR}/../shared" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

# Required by shared/config.sh + shared/lsp_bootstrap.sh
CONFIG_PREFIX="php-tooling"
CONFIG_FILE_PREFIX=".lsp-"
CONFIG_ENV_VAR_PREFIX="LSP"
LSP_DEFAULT_BINARY="phpactor"

export SCRIPT_DIR SHARED_DIR PROJECT_ROOT
export CONFIG_PREFIX CONFIG_FILE_PREFIX CONFIG_ENV_VAR_PREFIX LSP_DEFAULT_BINARY

source "${SHARED_DIR}/lsp_bootstrap.sh"

# Per-LSP launcher may adjust LSP_BINARY or append args.
source "${SCRIPT_DIR}/lib/phpactor.sh"

lsp_run_or_null_stub "${LSP_BINARY} language-server"
