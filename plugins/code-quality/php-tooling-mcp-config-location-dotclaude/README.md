# PHP Tooling MCP Server (.claude Config)

MCP server configuration for php-tooling with config in `.claude/` directory.

**Requires:** `php-tooling` plugin must be installed first.

## Config Location

This plugin configures the MCP server to look for configuration at:

```
.claude/.mcp-php-tooling.json
```

This keeps project-specific Claude configuration separate from other dotfiles.

## Installation

```bash
# Install core plugin first
/plugin install php-tooling@shopware-plugins

# Then install this MCP configuration
/plugin install php-tooling-mcp-config-location-dotclaude@shopware-plugins
```

Restart Claude Code after installation.

## Alternative

If you prefer configuration at project root:

```bash
/plugin install php-tooling-mcp-config-location-root@shopware-plugins
```

## License

MIT
