# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.4.0] - 2026-06-25

### Added
- Tool-call arguments are now validated server-side against the called tool's declared `inputSchema` before dispatch, on both the read and write servers. Every `required` field must be present, and when the schema sets `additionalProperties: false` any field outside `properties` is rejected — returned as an `isError` result naming the offending parameters. This adds `required`-field enforcement and moves unknown-field rejection into the server itself, complementing the MCP-layer `additionalProperties: false` checks added in 3.1.0. Tools without a schema are left unvalidated. Added as `validate_tool_arguments` in the shared `mcpserver_core.sh`.

## [3.3.0] - 2026-06-25

### Changed
- `pr_view` now requires the PR `number`. The input schema marks `number` as `required`, and `pr.sh` rejects a missing number with `"Error: number is required for pr_view"`. Previously `number` was optional: when omitted, the tool resolved the current branch's PR via `gh pr list --head <branch>`. **Migration:** callers that omitted `number` to view the current branch's PR must now resolve and pass the PR number explicitly.

### Removed
- Current-branch PR fallback in `pr_view`. The `gh pr list --head <branch>` resolution path was removed. It silently resolved a *different* PR when the number was passed under a wrong key (for example `pr` instead of `number`), returning the wrong PR instead of failing — the failure mode this change eliminates. The tool description (`tools-read.json`) and `REFERENCE.md` were updated to state that `number` is required, and the bats suite now passes an explicit number.

## [3.2.0] - 2026-05-28

### Added
- `release_list` read tool for looking up release versions across one or more repositories. Built for dependency-update tasks: pass a `repos` array to get the latest version of each in a single call, replacing the repetitive one-`api_read`-per-repo pattern against `repos/{owner}/{repo}/releases/latest`. Goes beyond "latest" with `constraint` (major `4`/`v4` or major.minor `4.2`/`v4.2` pinning), `include_prereleases`, `include_drafts`, `latest: false` to list multiple releases, `limit`, and `resolve_sha` (resolves each tag to its commit SHA for pinning GitHub Actions). Releases are re-sorted by semantic version descending in jq (GitHub returns them by publish date), so the highest version is treated as latest. `fields` projects each result to only the requested keys (e.g. `["tag_name"]` for just version numbers) and unknown field names are rejected; `jq_filter` shapes the final array (e.g. `.[].tag_name` for bare version strings).
- `check-gh-tools.sh` now blocks `gh release list` / `gh release view` (always) and `gh api repos/.../releases*` (when `block_api_commands` is enabled), redirecting to `release_list`.

## [3.1.0] - 2026-05-26

### Added
- Unified repository contract on issue and PR tools. `issue_view`, `issue_list`, `pr_view`, `pr_diff`, `pr_list`, `pr_checks`, `pr_comments`, `pr_reviews`, `pr_files`, `pr_commits` now accept `owner`+`repo` (split form) and `repository` (owner/repo string) in addition to the legacy `repo` field. This matches the shape already available on `repo_file` / `repo_tree` / `search_code`, eliminating the cross-tool param-shape inconsistency that was the structural cause of recent misuse cascades.
- Git-context-aware repo requirement on `issue_view`, `issue_list`, `pr_view`, `pr_diff`, `pr_list`, `pr_checks`. Outside a git repository, missing-repo calls now fail with `"Error: repo is required outside a git repository..."` instead of letting `gh`'s confusing `"fatal: not a git repository"` surface. Inside a git repository, omitting `repo` still falls through to `gh`'s local resolution (no regression).
- Strict schema validation across every read-tool input schema (`"additionalProperties": false`). Unknown fields (typos, fabricated parameters transferred from adjacent tools) are rejected at the MCP layer instead of being silently dropped — which previously made wrong-input cascades hard to diagnose.
- Centralized "Repository selection" reference section in `REFERENCE.md` documenting the four accepted shapes (`repo`, `repository`, `owner`+`repo`, `url`).

### Changed
- Search-family tools (`search`, `search_code`, `search_repos`, `search_commits`, `search_discussions`) renamed the search-term parameter from `query` to `search`. Aligns all search-bearing tools on one canonical name; `search` already matched `gh`'s underlying `--search` flag in `issue_list` and `pr_list`. LLM consumers pick up the renamed schema at session start.
- `jq_filter` descriptions across all schemas reworded from "Most useful when 'fields' is also set for JSON output" to "Useful for shaping JSON responses or reducing response size before the token cap" — surfaces payload-size control as a primary use case rather than a side effect of JSON shaping.
- Block messages in `check-gh-tools.sh` for `gh pr view/diff/list/checks` and `gh issue view/list` now list `repo` (or `repository`/`owner`+`repo`) among the suggested parameters. Block messages for `gh search code/repos/commits` and `gh search` use `search` instead of `query` to match the renamed parameter.

## [3.0.2] - 2026-04-19

### Changed
- Internal shellcheck cleanup in `shared/mcpserver_core.sh`. No behavior change. The `log()` function now splits `local line` from its assignment so the `local` builtin no longer masks `date`'s exit status (SC2155).

## [3.0.1] - 2026-04-18

### Changed
- `setting-up` skill aligned with the shared template by adding an optional Phase 4 (Plugin Scope Setup) and renumbering the remaining phases. The phase is a no-op for gh-tooling since its `SETUP.md` has no `## Plugin Scope Setup` section.

## [3.0.0] - 2026-04-15

### Changed (BREAKING)
- Review tool surface rewritten to match GitHub's actual review workflow:
  - **Removed** `pr_review` and `pr_review_comment`.
  - **Added** `pr_review_submit` — submits a review with optional inline code comments in a single call. Without `comments` it behaves like the old `pr_review` (event-only submit). With `comments[]` it posts to `POST /pulls/N/reviews` with a JSON body; `commit_id` is auto-fetched from the PR head if not supplied. Supports ```suggestion blocks for one-click suggested changes.
  - **Added** `pr_review_reply` — posts a threaded reply to an existing review comment via `POST /pulls/N/comments/{id}/replies`.
- `pr_review_comment` was broken: it posted to `/pulls/N/comments` without the required `commit_id` field, so every call failed. Rather than patch a tool that could not express the batched review flow, the review surface was redesigned around `pr_review_submit`.

### Fixed
- `check-api-tools.sh` read-endpoint mapping now only fires for `GET` requests. `POST /pulls/N/reviews` previously matched the read `pr_reviews` rule before reaching the write section.

## [2.1.0] - 2026-04-13

### Added
- **Permission configuration in `setting-up` skill** — new Phase 4 pre-approves gh-tooling MCP tools in `.claude/settings.local.json`. Seven permission groups bundle related tools (read, PR writes, reviews, issue writes, metadata, project writes, raw API); write groups default to `ask` and are skipped unless the write server is enabled. Merges non-destructively into any existing settings.

## [2.0.1] - 2026-04-13

### Fixed
- `setting-up` SKILL.md: bare-path reference to `references/plugin-setup.md` so progressive disclosure loads it correctly.

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
