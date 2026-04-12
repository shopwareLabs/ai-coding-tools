# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-12

### Added
- Initial release of code-contribution-analysis plugin
- `pr-analyzing` skill: fetches PR metadata, diff, files, reviews, and inline comments from GitHub, then researches architectural impact via chunkhound-integration using an incremental Stage 1/2/3 strategy
- `issue-analyzing` skill: fetches issue metadata and comments from GitHub, locates the affected code area, then researches it via chunkhound-integration with the same staged approach
- Hard dependency on chunkhound-integration: both skills stop with an error if the research tool is not callable, rather than producing a partial analysis that silently omits the most valuable section
- GitHub access is tool-agnostic: skills describe fetch operations and use whatever is available in the session (GitHub MCP server, `gh` CLI, or direct API calls)
- Optional triage reasoning input: callers can pass context about why analysis was requested as a research focus hint
- Designed for standalone use in Claude Code sessions and as a building block loadable via the Claude Agent SDK `plugins` option
