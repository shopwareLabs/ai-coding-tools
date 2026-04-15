#!/usr/bin/env bash
# phpactor-specific launcher helper.
#
# phpactor is invoked as `phpactor language-server` (no extra flags) for stdio
# LSP mode. This file exists as a hook point: if a future phpactor release
# requires additional CLI args (`--no-cache`, `--config=...`, etc.), set them
# here by modifying LSP_BINARY or emitting a PHPACTOR_EXTRA_ARGS variable.
#
# For now, no overrides are needed. The file is deliberately near-empty so the
# pattern is established for future expansion without requiring a dispatcher edit.

: "${LSP_BINARY:?LSP_BINARY must be set by lsp_bootstrap.sh}"
