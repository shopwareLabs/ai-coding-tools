#!/bin/bash
# Wrapper script to locate and execute php-tooling server.sh
# Dynamically discovers the server in the plugin cache regardless of version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CACHE_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Find server.sh in php-tooling plugin (pick latest version)
SERVER=$(find "$CACHE_ROOT/php-tooling" -name "server.sh" -path "*/mcp-server/*" 2>/dev/null | sort -V | tail -1)

if [ -z "$SERVER" ] || [ ! -x "$SERVER" ]; then
    echo '{"jsonrpc":"2.0","error":{"code":-32603,"message":"php-tooling plugin not found. Install it first: /plugin install php-tooling@shopware-plugins"}}' >&2
    exit 1
fi

exec "$SERVER" "$@"
