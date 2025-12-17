# Changelog

## [1.1.0] - 2025-12-17

### Changed

- Agent: model `sonnet` → `inherit`, added `color: yellow`, structured `<example>` blocks in description
- Command: added `allowed-tools` restriction, explicit JSON invocation format

### Added

- Agent: "Output Format" section, "Do NOT use this agent for" guidance
- Docs: Features section (README), Quick Reference table (AGENTS), removed fragile line numbers

## [1.0.0] - 2025-10-30

Initial release.

### Added

- `codex-escalation` agent for automatic consultation with OpenAI Codex (GPT-5) when stuck after three failed attempts
- `/codex-check` command for verifying Codex setup and troubleshooting issues
- MCP server configuration for native Codex CLI integration
- Progressive escalation protocol (Codex consultation → user notification)
- Multi-turn conversation support with single-turn fallback for compatibility
- Comprehensive context gathering (goal, attempts, errors, code snippets)

### Prerequisites

- OpenAI Codex CLI v0.36.0 or higher
- OpenAI account with Codex access (ChatGPT Plus/Pro/Team)
- Authenticated via `codex login --api-key`
