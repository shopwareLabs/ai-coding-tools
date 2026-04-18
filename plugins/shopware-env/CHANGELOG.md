# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-18

### Added
- MCP server `lifecycle-tooling` with 8 tools: `install_dependencies`, `database_install`, `database_reset`, `testdb_prepare`, `frontend_build_admin`, `frontend_build_storefront`, `plugin_create`, `plugin_setup`
- `dev-environment-bootstrapping` skill for first-run setup orchestration
- SessionStart hook with lifecycle tool directives
- PreToolUse hook enforcing MCP tools over bash equivalents
- Reads dev-tooling's `.mcp-php-tooling.json` as optional config fallback
