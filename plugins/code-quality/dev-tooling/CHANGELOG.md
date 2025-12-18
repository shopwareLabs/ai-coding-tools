# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-12-18

### Added
- **js-admin-tooling MCP server** - Administration JavaScript tools:
  - `eslint_check`, `eslint_fix` - ESLint linting
  - `stylelint_check`, `stylelint_fix` - SCSS linting
  - `prettier_check`, `prettier_fix` - Code formatting
  - `jest_run` - Unit testing
  - `tsc_check` - TypeScript type checking
  - `lint_all` - Run all lint checks in one command
  - `lint_twig` - ESLint for Twig templates
  - `unit_setup` - Regenerate Jest import resolver
  - `vite_build` - Build with Vite
- **js-storefront-tooling MCP server** - Storefront JavaScript tools:
  - `eslint_check`, `eslint_fix` - ESLint linting
  - `stylelint_check`, `stylelint_fix` - SCSS linting
  - `jest_run` - Unit testing
  - `webpack_build` - Build with Webpack
- Shared configuration via `.mcp-js-tooling.json` for both JS servers

### Changed
- **BREAKING**: Plugin renamed from `php-tooling` to `dev-tooling`

### Migration

1. Uninstall: `/plugin uninstall php-tooling@shopware-plugins`
2. Install: `/plugin install dev-tooling@shopware-plugins`
3. Restart Claude Code
4. PHP tools work unchanged with existing `.mcp-php-tooling.json`
5. For JS tools: Create `.mcp-js-tooling.json` with environment configuration

## [1.5.0] - 2025-12-17

### Added
- Config discovery in popular LLM coding tool directories:
  - `.aiassistant/` (JetBrains AI Assistant)
  - `.amazonq/` (Amazon Q Developer)
  - `.cline/` (Cline / Claude Dev)
  - `.cursor/` (Cursor AI)
  - `.kiro/` (Kiro - Amazon Q CLI successor)
  - `.windsurf/` (Windsurf / Codeium)
  - `.zed/` (Zed editor)
- Cross-tool configuration sharing via deep-merge support

### Changed
- Improved error messages to list all supported config directories
- Config locations ordered alphabetically for deterministic merge behavior

## [1.4.0] - 2025-12-17

### Added
- `console_run` tool - Execute any Symfony console command with arguments and options
- `console_list` tool - List available console commands with namespace filtering
- Support for Symfony global options: env, verbosity, no_debug, no_interaction
- Flexible options handling: boolean flags, string values, and arrays
- Console configuration section in `.mcp-php-tooling.json`

## [1.3.1] - 2025-12-17

### Fixed
- Added missing `lib/config.sh` library file that was not included in 1.3.0 release

## [1.3.0] - 2025-12-16

### Added
- `MCP_PHP_TOOLING_CONFIG` environment variable for config path override
- Config discovery with deep merging (`.mcp-php-tooling.json` + `.claude/.mcp-php-tooling.json`)
- Extensible `CONFIG_LOCATIONS` array in new `lib/config.sh` module

### Changed
- Consolidated into single plugin (removed separate `php-tooling-mcp-config-location-*` plugins)
- Replaced `--config` argument with environment variable and auto-discovery

### Migration
Uninstall `php-tooling-mcp-config-location-*` plugins, update php-tooling, restart Claude Code.

## [1.2.0] - 2025-12-16

### Changed
- Split MCP server configuration into separate location-based plugins
- Removed `.mcp.json` from main plugin (requires separate config plugin to activate)
- Added `php-tooling-mcp-config-location-root` plugin (config at project root)
- Added `php-tooling-mcp-config-location-dotclaude` plugin (config in `.claude/` directory)

## [1.1.0] - 2025-12-16

### Changed
- **BREAKING**: Renamed configuration file from `.lintrc.local.json` to `.mcp-php-tooling.json`
- Added `--config` argument to override config file path

## [1.0.0] - 2025-12-15

### Added
- PHPStan static analysis tool (`phpstan_analyze`)
- ECS code style checking tool (`ecs_check`)
- ECS code style fixing tool (`ecs_fix`)
- PHPUnit test runner tool (`phpunit_run`)
- Multi-environment support: native, docker, vagrant, ddev
- Auto-detection of development environment from project files
- Configuration via `.lintrc.local.json` file
- Bash-based MCP server implementation (minimal dependencies)
