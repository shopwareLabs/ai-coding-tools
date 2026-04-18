ALWAYS use lifecycle-tooling MCP tools for Shopware environment operations — NEVER run these via Bash.

If a .mcp-php-tooling.json config exists, its environment settings override any arguments passed to these tools.

lifecycle-tooling: install_dependencies, database_install, database_reset, testdb_prepare, frontend_build_admin, frontend_build_storefront, plugin_create, plugin_setup

Call tools sequentially — never in parallel. These tools run long-running operations that should not overlap.
