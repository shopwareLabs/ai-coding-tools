#!/bin/bash
# Claude Code Hook: Shopware Lifecycle MCP Enforcer
# ==================================================
# Blocks Shopware lifecycle bash commands in favor of MCP tools.
#
# Exit codes:
#   0 - Command allowed
#   2 - Command blocked (message shown to Claude)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

parse_hook_input
load_mcp_config "php-tooling"

# Composer install/update - Use install_dependencies
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*composer\s+(install|update)(\s|$)'; then
    block_tool "mcp__lifecycle-tooling__install_dependencies" \
        "Use install_dependencies with composer/administration/storefront flags."
fi

# npm install/ci - Use install_dependencies
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*npm\s+(install|ci)(\s|$)'; then
    block_tool "mcp__lifecycle-tooling__install_dependencies" \
        "Use install_dependencies with administration/storefront flags."
fi

# system:install / system:setup - Use database_install
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?bin/console\s+system:(install|setup)(\s|$)'; then
    block_tool "mcp__lifecycle-tooling__database_install" \
        "Use database_install for first-time setup or database_reset to wipe and rebuild."
fi

# plugin:create - Use plugin_create
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?bin/console\s+plugin:create(\s|$)'; then
    block_tool "mcp__lifecycle-tooling__plugin_create" \
        "Use plugin_create with plugin_name and plugin_namespace arguments."
fi

# plugin:install / plugin:refresh / plugin:activate - Use plugin_setup
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?bin/console\s+plugin:(install|refresh|activate)(\s|$)'; then
    block_tool "mcp__lifecycle-tooling__plugin_setup" \
        "Use plugin_setup with plugin_name argument."
fi

# bundle:dump / assets:install / feature:dump / framework:schema:dump - Use frontend_build_*
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?bin/console\s+(bundle:dump|assets:install|feature:dump|framework:schema:dump)(\s|$)'; then
    block_tool "mcp__lifecycle-tooling__frontend_build_admin or frontend_build_storefront" \
        "Use frontend_build_admin or frontend_build_storefront for complete build chains."
fi

# theme:compile - Use frontend_build_storefront
if echo "$COMMAND" | grep -qE '(^|;|&&|\|)\s*(php\s+)?\.?/?bin/console\s+theme:compile(\s|$)'; then
    block_tool "mcp__lifecycle-tooling__frontend_build_storefront" \
        "Use frontend_build_storefront for the complete storefront build chain."
fi

exit 0
