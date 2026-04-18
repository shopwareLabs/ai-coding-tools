# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1] - 2026-04-18

### Changed
- `setting-up` skill aligned with the shared template by adding an optional Phase 4 (Plugin Scope Setup) and renumbering the remaining phases. The phase is a no-op for chunkhound-integration since its `SETUP.md` has no `## Plugin Scope Setup` section.

## [1.2.0] - 2026-04-13

### Added
- **Permission configuration in `setting-up` skill** — new Phase 4 pre-approves ChunkHound MCP tools in `.claude/settings.local.json` as a single wildcard allow group. Merges non-destructively into any existing settings.

## [1.1.1] - 2026-04-13

### Fixed
- `setting-up` SKILL.md: bare-path reference to `references/plugin-setup.md` so progressive disclosure loads it correctly.

## [1.1.0] - 2026-04-10

### Added
- **Interactive setup skill** — `setting-up` skill walks users through plugin configuration: checks chunkhound CLI installation, verifies embedding provider API key (VoyageAI, OpenAI, or Ollama), creates `.chunkhound.json` with provider settings, runs the initial codebase index, validates the MCP server connection, and reports post-setup steps. Activates when users ask about setup or when ChunkHound MCP tools fail due to missing config.

## [1.0.3] - 2026-01-09

### Changed
- Improved skill description to follow Anthropic's best practices (third-person voice, quoted trigger phrases)

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
