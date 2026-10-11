# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-10-11

### Removed
- **The `dev-tooling-setting-up` skill no longer covers the phpactor LSP**, matching dev-tooling 5.0.0 removing the LSP. The skill no longer asks for `.lsp-php-tooling.json`, no longer checks `python3` or `phpactor` (the phar-sidecar install recipe is gone too), and no longer runs the LSP dispatcher dry-run or the other LSP validation steps. The containerized LSP lifecycle and `.phpactor.json` notes are gone from Post-Setup, and the skill description no longer mentions the LSP.

## [1.0.3] - 2026-10-07

### Changed
- **The `dev-tooling-setting-up` skill's bundled reference copy of dev-tooling's `SETUP.md` is refreshed.** Its post-restart validation steps now name the MCP tools the way Claude Code names them for an installed plugin (`mcp__plugin_dev-tooling_<server>__<tool>` instead of `mcp__<server>__<tool>`), matching dev-tooling 4.1.0. No workflow change.

## [1.0.2] - 2026-07-13

### Removed
- The `gh-tooling-setting-up` skill. Its source plugin left this marketplace for the standalone `github-agent-tools` marketplace (as `github-mcp`), which ships its own `plugin-setup`. The remaining `dev-tooling-setting-up` and `chunkhound-integration-setting-up` skills are unaffected.

## [1.0.1] - 2026-05-13

### Changed
- All 3 setting-up skill descriptions rewritten to follow https://agentskills.io/skill-creation/optimizing-descriptions. Each description leads with imperative "Use this skill when..." and names the source plugin (dev-tooling, gh-tooling, chunkhound-integration) so the right skill activates when the user names the plugin they just installed. No behavior change.

## [1.0.0] - 2026-05-11

### Added
- Initial release. Extracts the `setting-up` skills from dev-tooling, gh-tooling, and chunkhound-integration into a standalone plugin. Each skill bundles a copy of its source plugin's `SETUP.md` as a reference file and follows the same interactive setup workflow as before.
