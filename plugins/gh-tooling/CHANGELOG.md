# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-23

### Added
- **`log_file` configuration option** - Route MCP server logs to a project-local file (e.g., `.claude/mcp-gh-tooling.log`) for easier debugging. Relative paths resolve against the project root. The default `server.log` continues to be written; the extra file is strictly additive. Invalid paths (non-existent parent directory) emit a warning and are silently skipped.

## [1.0.0] - 2026-02-23

### Added
- Initial standalone release, extracted from `dev-tooling` v2.7.0
- **`gh-tooling` MCP server** with 19 GitHub CLI tools:
  - **PR tools**: `pr_view`, `pr_diff`, `pr_list`, `pr_checks`, `pr_comments`, `pr_reviews`, `pr_files`, `pr_commits`
  - **Issue tools**: `issue_view`, `issue_list`
  - **CI/Actions tools**: `run_view`, `run_list`, `run_logs`, `job_view`, `job_logs`, `job_annotations`
  - **Commit tools**: `commit_pulls`
  - **Search tools**: `search`
  - **API escape hatch**: `api` for raw GitHub REST API calls
- **PreToolUse hook** (`check-gh-tools.sh`) enforcing MCP tool usage over bash `gh` commands
- Optional configuration via `.mcp-gh-tooling.json` (default repo, hook enforcement toggle, API command blocking)
- Shared parameters across all tools: `suppress_errors`, `fallback`
- `jq_filter` for JSON output tools with pre-execution syntax validation
- `max_lines`, `tail_lines`, and grep parameters for log/text tools
