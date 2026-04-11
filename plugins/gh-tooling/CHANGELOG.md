# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-04-11

### Added
- Write MCP server (`gh-tooling-write`) with 23 write tools gated by `enable_write_server` config flag
- PR lifecycle tools: `pr_create`, `pr_edit`, `pr_ready`, `pr_merge`, `pr_close`, `pr_reopen`
- Review tools: `pr_review`, `pr_comment`, `pr_review_comment`
- Issue tools: `issue_create`, `issue_edit`, `issue_close`, `issue_reopen`, `issue_comment`
- Label tools: `label_add`, `label_remove` (write), `label_list` (read)
- Assignee tools: `assignee_add`, `assignee_remove`
- Sub-issue tools: `sub_issue_add`, `sub_issue_remove` (GraphQL)
- Project tools: `project_item_add`, `project_status_set` (name-to-ID resolution), `project_list`, `project_view` (read)
- Label semantics: `labels` config map injected into SessionStart prompt
- MCP API tool blocking hook (`check-api-tools.sh`) with `block_api_tool_read` and `block_api_tool_write` config flags
- Bash CLI blocking extended to cover write commands, label, and project commands

### Changed
- Read server `api` tool renamed to `api_read` and restricted to GET requests only
- Server files renamed: `server.sh` → `server-read.sh`, `tools.json` → `tools-read.json`, `config.json` → `config-read.json`
- SessionStart prompt assembled dynamically from template with conditional write and label sections
- `.mcp.json` registers both `gh-tooling` (read) and `gh-tooling-write` (write) servers

## [1.5.0] - 2026-04-10

### Added
- **Interactive setup skill** — `setting-up` skill walks users through plugin configuration: verifies gh CLI is installed and authenticated, checks jq availability, optionally creates `.mcp-gh-tooling.json` with a default repository, validates the MCP server connection, and reports post-setup steps. Activates when users ask about setup or when MCP tools fail due to missing auth or config.

## [1.4.0] - 2026-04-01

### Added
- **SessionStart hook** — Injects MCP tool usage directives into conversation context at the start of every session. Lists all 26 available tools by category and instructs Claude to use them instead of bash `gh` commands. Includes sequential invocation rule (the stdio server processes one request at a time). Prompt is maintained in `hooks/prompts/mcp-tool-directives.md` and output uses the JSON `additionalContext` format. Respects `enforce_mcp_tools` setting.

## [1.3.1] - 2026-03-04

### Fixed
- **`pr_diff` file filter** — Passing the `file` parameter caused `"accepts at most 1 arg(s)"` because `gh pr diff` has no native file filter. File filtering is now done via post-processing instead of passing `-- <file>` to the CLI.

## [1.3.0] - 2026-02-27

### Added
- **`run_list` filters** - Added `workflow`, `status`, `event`, `user`, `created`, and `commit` parameters to `run_list`, exposing all `gh run list` filter flags.
- **`workflow_jobs`** - New composite tool that aggregates jobs across workflow runs in a single call. Reduces N+1 tool calls (run_list + N×job_view) to one invocation. Supports filtering by job name, conclusion, and step name.

## [1.2.0] - 2026-02-27

### Added
- **`search_code`** - Search for code across GitHub repositories. Supports language, extension, filename, and match filters. Set `download_to` to save matching files locally. Rate limit: 10 requests/minute.
- **`search_repos`** - Search for repositories by query, owner, topic, language, license, or star count. Query is optional — filters alone suffice.
- **`search_commits`** - Search for commits by message text, author, date range, or hash.
- **`search_discussions`** - Search for GitHub discussions via GraphQL. Supports category, author, and state filters. Set `with_comments` to include discussion comment bodies and replies.
- **`repo_tree`** - Browse repository directory contents or get the full recursive file tree. Accepts GitHub URLs, explicit params, or default repo. Use instead of `WebFetch` on GitHub tree URLs.
- **`repo_file`** - Fetch a single file from a GitHub repository as raw text. Supports line ranges, grep filtering, and local download. Use instead of `WebFetch` on GitHub blob URLs.
- Helper functions: `_gh_parse_github_url`, `_gh_validate_path`, `_gh_download_file`, `_gh_resolve_owner_repo`
- Hook blocking for `gh search code`, `gh search repos`, `gh search commits`
- Optional API blocking for `repos/.../contents/` and `repos/.../git/trees/` endpoints

## [1.1.1] - 2026-02-26

### Fixed
- **`pr_view` without number fails when `--repo` is configured** - When no PR number is provided and a default repo is set via `.mcp-gh-tooling.json`, `gh pr view --repo` requires an explicit identifier. Now resolves the current branch's PR number via `gh pr list --head` before calling `pr view`.

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
