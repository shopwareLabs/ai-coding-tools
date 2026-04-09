# Changelog

## [0.1.0] - 2026-04-09

### Added
- Initial release of agent-skills-export
- `build-agent-skill` CLI command (Typer-based)
- Frontmatter transformation: strips `version`, `model`, `allowed-tools`
- Metadata enrichment from `.claude-plugin/plugin.json` (version, author, license)
- File exclusion for OS metadata, IDE files, Python bytecode, editor swap files
- Optional validation via `skills-ref` (`[validate]` extra)
- GitHub Actions workflow: discover, build, PR comment, release
- 47 tests with pytest, ruff linting, mypy strict type checking
