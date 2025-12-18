#!/usr/bin/env bash
# Build tool implementation for Storefront Tooling MCP Server
# Provides webpack_build MCP tool
# Note: "hot" mode (watch) is not supported - long-running processes hang MCP servers

# Webpack build (Storefront)
# Args: JSON with mode (optional: "development" or "production")
tool_webpack_build() {
    local args="$1"

    local mode
    mode=$(echo "${args}" | jq -r '.mode // "production"')

    # Reject watch/hot mode - MCP servers cannot handle long-running processes
    if [[ "${mode}" == "hot" || "${mode}" == "watch" ]]; then
        cat <<'EOF'
Error: Watch mode is not supported via MCP tools.

MCP servers use a synchronous request-response model that blocks until commands complete.
Watch tasks run indefinitely, which would hang the entire MCP server.

To run watch mode, open a separate terminal and run:
  npm run hot

Or from the Shopware project root:
  cd src/Storefront/Resources/app/storefront && npm run hot

For one-time builds, use mode "development" or "production" instead.
EOF
        return 1
    fi

    # Map mode to npm script name
    local script_name
    case "${mode}" in
        development) script_name="development" ;;
        production|*) script_name="production" ;;
    esac

    local cmd="npm run ${script_name}"

    log "INFO" "Running Webpack build (storefront): ${cmd}"

    exec_npm_command "${cmd}"
}
