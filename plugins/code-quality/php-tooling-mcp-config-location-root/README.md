# PHP Tooling MCP Server (Project Root Config)

MCP server configuration for php-tooling with config at project root.

**Requires:** `php-tooling` plugin must be installed first.

## Config Location

This plugin configures the MCP server to look for configuration at:

```
.mcp-php-tooling.json  (project root)
```

## Installation

```bash
# Install core plugin first
/plugin install php-tooling@shopware-plugins

# Then install this MCP configuration
/plugin install php-tooling-mcp-config-location-root@shopware-plugins
```

Restart Claude Code after installation.

## Alternative

If you prefer to store configuration in `.claude/`:

```bash
/plugin install php-tooling-mcp-config-location-dotclaude@shopware-plugins
```

## License

MIT
