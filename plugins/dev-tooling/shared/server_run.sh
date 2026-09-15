#!/usr/bin/env bash
# Shared tail for the dev-tooling MCP server entry points: the run_mcp_server
# call and the rationale for why it isn't isolated in a subshell.
#
# Owned by dev-tooling. Not templated — do not add it to the mapping in
# .claude/rules/template-sync.md.
#
# Requires: run_mcp_server() from shared/mcpserver_core.sh. Source with no
# arguments — a sourced file with none of its own receives the sourcing
# script's own positional parameters as "$@", so this call forwards the
# server's argv unchanged. The EXIT trap the comment below refers to is set
# earlier in the sourcing server.sh, before this module is sourced; it stays
# there rather than moving here, so its position relative to config.sh's own
# EXIT trap is unchanged.

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

# Called directly, not in a subshell. The handler installs EXIT/INT/TERM/HUP/PIPE
# traps that replace the one set above, and since bash-mcp-sdk v5.1.0 its
# teardown runs the EXIT handler it displaced, so that cleanup survives without
# isolating the call. A subshell would preserve the cleanup too, but it would
# also hold the handler's signal traps outside this process — the one the client
# signals — and the handler's own temp files were measured to survive every
# signalled shutdown in that shape.
run_mcp_server "$@"
