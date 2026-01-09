# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2026-01-09

### Fixed
- Corrected MCP tool identifiers from `mcp__ChunkHound__*` to `mcp__plugin_chunkhound-integration_ChunkHound__*` format

## [1.0.1] - 2026-01-09

### Fixed
- `/chunkhound-status` now correctly detects database at configured `database.path` instead of only checking hardcoded `.chunkhound/` directory
- Status command now checks all 8 config file locations (project root through `.claude/`) instead of only project root

## [1.0.0] - 2026-01-08

### Added
- Initial release
- MCP server integration for ChunkHound semantic code research
- `/research <query>` command for explicit ChunkHound invocation
- `/chunkhound-status` command for diagnostics
- `code-research-routing` skill for automatic tool selection
- `code-researcher` agent for complex investigations
- PreToolUse hook suggesting ChunkHound for architectural Grep queries
- Multi-location config discovery (8 locations, `.claude/` highest priority)
