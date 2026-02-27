# GitHub Tooling

GitHub CLI tools via MCP (Model Context Protocol). Wraps the `gh` CLI for pull requests, issues, CI runs, jobs, commits, search, and repository file browsing. Configuration-optional: works without a config file when `gh` is authenticated.

## Features

### GitHub Tools (gh-tooling MCP Server)
- **PR inspection** via `pr_view`, `pr_diff`, `pr_list`, `pr_checks`
- **PR review data** via `pr_comments`, `pr_reviews`, `pr_files`, `pr_commits`
- **Issue operations** via `issue_view`, `issue_list`
- **GitHub Actions CI** via `run_view`, `run_list`, `run_logs`
- **Job-level CI debugging** via `job_view`, `job_logs`, `job_annotations`
- **Commit PR lookup** via `commit_pulls`
- **Cross-repo search** via `search` (issues and PRs), `search_code`, `search_repos`, `search_commits`, `search_discussions`
- **Repository browsing** via `repo_tree` (directory listings) and `repo_file` (file content) — use instead of WebFetch on GitHub URLs
- **Raw API access** via `api` for any GitHub REST endpoint

## Quick Start

### Installation

```bash
/plugin install gh-tooling@shopware-ai-coding-tools
```

**IMPORTANT**: Restart Claude Code after installation for the MCP server to initialize.

### Verification

After restarting, verify the MCP server is running:

```bash
/mcp
```

You should see `gh-tooling` listed as a connected server.

## Configuration

### `.mcp-gh-tooling.json`

The gh-tooling server is **configuration-optional** - it works without any config file as long as `gh` is authenticated. A config file adds a default repository so you don't need to pass `repo` to every tool call.

```json
{
  "repo": "shopware/shopware"
}
```

With full enforcement (blocks both subcommands and known `gh api` endpoints):

```json
{
  "repo": "shopware/shopware",
  "enforce_mcp_tools": true,
  "block_api_commands": true
}
```

With enforcement disabled:

```json
{
  "repo": "shopware/shopware",
  "enforce_mcp_tools": false
}
```

### Configuration Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `repo` | string | — | Default repository in `owner/repo` format. Used when `repo` is not passed to a tool call. |
| `enforce_mcp_tools` | boolean | `true` | Blocks high-level `gh` subcommands (`gh pr view`, `gh issue view`, `gh run view`, `gh search`, etc.) and redirects to MCP tools. Set to `false` to disable all gh hook enforcement. |
| `block_api_commands` | boolean | `false` | When `true` (and `enforce_mcp_tools` is also `true`), additionally blocks `gh api` calls for endpoints that have a dedicated MCP tool: `pulls/N/comments`, `pulls/N/reviews`, `pulls/N/files`, `pulls/N/commits`, `actions/jobs/N/logs`, `actions/jobs/N`, `check-runs/N/annotations`, `commits/SHA`. Other `gh api` calls remain unblocked. |
| `log_file` | string | — | Additional log file path. Relative paths resolve against the project root. |

### Configuration Priority

Configuration is loaded in the following priority order:

1. **Environment variable**: `MCP_GH_TOOLING_CONFIG`
2. **Config file discovery** (checked in order, last found wins):
   - `.mcp-gh-tooling.json` (project root, base config)
   - `.aiassistant/.mcp-gh-tooling.json` (JetBrains AI Assistant)
   - `.amazonq/.mcp-gh-tooling.json` (Amazon Q Developer)
   - `.cline/.mcp-gh-tooling.json` (Cline)
   - `.cursor/.mcp-gh-tooling.json` (Cursor AI)
   - `.kiro/.mcp-gh-tooling.json` (Kiro)
   - `.windsurf/.mcp-gh-tooling.json` (Windsurf/Codeium)
   - `.zed/.mcp-gh-tooling.json` (Zed editor)
   - `.claude/.mcp-gh-tooling.json` (override, highest priority)

**Prerequisites:**
- `gh` CLI installed: `brew install gh` (macOS) or see [GitHub CLI installation](https://cli.github.com/)
- Authenticated: `gh auth login`

## Tools Reference

Tools are available via the `gh-tooling` MCP server. Requires `gh` CLI installed and authenticated.

### Shared Tool Parameters

All gh-tooling MCP tools accept these parameters:

| Parameter         | Type    | Default | Description                                                             |
|-------------------|---------|---------|-------------------------------------------------------------------------|
| `suppress_errors` | boolean | `false` | Silence stderr; errors produce empty output instead of an error message |
| `fallback`        | string  | —       | Return this text (successfully) when the gh command fails               |

Tools that produce structured JSON output also accept `jq_filter` (string) for filtering and transforming results with full jq expression syntax. A syntax check runs before execution to give early feedback on invalid expressions.

Tools with large text output (`run_logs`, `job_logs`, `pr_diff`) additionally accept:

| Parameter             | Type    | Description                                                 |
|-----------------------|---------|-------------------------------------------------------------|
| `max_lines`           | integer | Return only the first N lines (`head -n N`)                 |
| `tail_lines`          | integer | Return only the last N lines (`tail -n N`)                  |
| `grep_pattern`        | string  | Extended regex filter (grep -E); non-matching lines removed |
| `grep_context_before` | integer | Lines of context before each match (-B)                     |
| `grep_context_after`  | integer | Lines of context after each match (-A)                      |
| `grep_ignore_case`    | boolean | Case-insensitive matching (-i)                              |
| `grep_invert`         | boolean | Return non-matching lines (-v)                              |

`max_lines` and `tail_lines` are also available on `pr_view`, `pr_checks`, `pr_comments`, `pr_reviews`, `issue_view`, and `api` for output size control.

### `pr_view`

View pull request details.

```
Use gh-tooling pr_view with number 14642
Use gh-tooling pr_view with number 14642 and fields "title,body,state,reviews"
Use gh-tooling pr_view with number 14642 and comments true
```

**Parameters:**
- `number` (integer, optional): PR number. Omit for the PR of the current branch.
- `repo` (string, optional): Repository in `owner/repo` format.
- `fields` (string, optional): Comma-separated JSON fields (e.g. `title,body,state,reviews,files`)
- `comments` (boolean, optional): Include PR comments in text output.

### `pr_diff`

Get the unified diff for a pull request.

```
Use gh-tooling pr_diff with number 14642
Use gh-tooling pr_diff with number 14642 and file "src/Core/Migration/V6_6/Migration1720094362.php"
Use gh-tooling pr_diff with number 14642 and name_only true
```

**Parameters:**
- `number` (integer, required): PR number.
- `file` (string, optional): Limit diff to a specific file path.
- `name_only` (boolean, optional): List only changed file names.
- `max_lines` (integer, optional): Return only the first N lines.
- `tail_lines` (integer, optional): Return only the last N lines.
- `grep_pattern` (string, optional): Filter lines by extended regex.
- `grep_context_before` / `grep_context_after` (integer, optional): Context lines around matches.
- `grep_ignore_case` (boolean, optional): Case-insensitive grep.
- `grep_invert` (boolean, optional): Return non-matching lines.

### `pr_list`

List pull requests with filters.

```
Use gh-tooling pr_list with author "mitelg" and state "merged" and limit 5
Use gh-tooling pr_list with search "NEXT-3412" and state "all"
Use gh-tooling pr_list with head "feature/my-branch"
```

### `pr_checks`

View CI status checks for a pull request.

```
Use gh-tooling pr_checks with number 14642
```

### `pr_comments`

Get inline review comments (code-level) for a PR.

```
Use gh-tooling pr_comments with number 14642
Use gh-tooling pr_comments with number 14642 and jq_filter ".[] | {path, body, line, user: .user.login}"
```

### `pr_reviews`

Get review decisions for a pull request.

```
Use gh-tooling pr_reviews with number 14642
Use gh-tooling pr_reviews with number 14642 and jq_filter ".[] | select(.state == \"CHANGES_REQUESTED\") | {user: .user.login, body}"
```

### `pr_files`

Get changed files with patch content.

```
Use gh-tooling pr_files with number 13911
Use gh-tooling pr_files with number 13911 and jq_filter ".[] | select(.filename | contains(\"Migration\")) | {filename, patch}"
```

### `pr_commits`

Get the commit history for a pull request.

```
Use gh-tooling pr_commits with number 14642
```

### `issue_view`

View a GitHub issue.

```
Use gh-tooling issue_view with number 8498
Use gh-tooling issue_view with number 8498 and with_comments true
Use gh-tooling issue_view with number 8498 and fields "title,body,state,labels,comments"
```

### `issue_list`

List issues with filters.

```
Use gh-tooling issue_list with search "TODO label:component/core" and limit 20
```

### `run_view`

View the status of a GitHub Actions workflow run.

```
Use gh-tooling run_view with run_id 21534190745
Use gh-tooling run_view with run_id 21534190745 and fields "status,conclusion"
```

### `run_list`

List recent GitHub Actions runs.

```
Use gh-tooling run_list with branch "tests/content-system-unit-tests" and limit 5
```

### `run_logs`

Get CI workflow run logs (failed steps by default).

```
Use gh-tooling run_logs with run_id 22245862281
Use gh-tooling run_logs with run_id 22245862281 and failed_only false and max_lines 500
Use gh-tooling run_logs with run_id 22245862281 and grep_pattern "FAILED|Error" and grep_context_after 3
Use gh-tooling run_logs with run_id 22245862281 and tail_lines 100
```

**Parameters:**
- `run_id` (integer, required): Workflow run ID.
- `failed_only` (boolean): Return only failed step logs. Default: `true`.
- `max_lines` (integer, optional): Return only the first N lines.
- `tail_lines` (integer, optional): Return only the last N lines.
- `grep_pattern` (string, optional): Filter lines by extended regex.
- `grep_context_before` / `grep_context_after` (integer, optional): Context lines around matches.
- `grep_ignore_case` (boolean, optional): Case-insensitive grep.
- `grep_invert` (boolean, optional): Return non-matching lines.

### `job_view`

Get details for a specific CI job including step statuses.

```
Use gh-tooling job_view with job_id 62056364818
Use gh-tooling job_view with job_id 62056364818 and jq_filter ".steps[] | select(.conclusion == \"failure\") | {name, number}"
```

### `job_logs`

Get raw log output for a specific CI job.

```
Use gh-tooling job_logs with job_id 62056364818
Use gh-tooling job_logs with job_id 62056364818 and max_lines 200
Use gh-tooling job_logs with job_id 62056364818 and grep_pattern "Fatal|Exception" and grep_context_after 5
Use gh-tooling job_logs with job_id 62056364818 and tail_lines 50
```

**Parameters:**
- `job_id` (integer, required): GitHub Actions job ID.
- `max_lines` (integer, optional): Return only the first N lines.
- `tail_lines` (integer, optional): Return only the last N lines.
- `grep_pattern` (string, optional): Filter lines by extended regex.
- `grep_context_before` / `grep_context_after` (integer, optional): Context lines around matches.
- `grep_ignore_case` (boolean, optional): Case-insensitive grep.
- `grep_invert` (boolean, optional): Return non-matching lines.

### `job_annotations`

Get inline error annotations from a CI check run.

```
Use gh-tooling job_annotations with check_run_id 62056364818
```

### `commit_pulls`

List GitHub pull requests associated with a pushed commit SHA. GitHub-only — for local commit metadata (files changed, commit message) use `git show <sha>` via Bash.

```
Use gh-tooling commit_pulls with sha "15a7c2bb86"
Use gh-tooling commit_pulls with sha "15a7c2bb86" and jq_filter ".[].number"
```

**Parameters:**
- `sha` (string, required): Commit SHA (7-40 hex characters). Must be pushed to GitHub.
- `repo` (string, optional): Repository in `owner/repo` format.
- `jq_filter` (string, optional): jq expression to filter/transform the PR list.

### `search`

Search for issues or pull requests.

```
Use gh-tooling search with query "NEXT-3412" and type "prs"
Use gh-tooling search with query "custom field translation" and type "issues" and limit 20
Use gh-tooling search with query "attribute entity" and state "closed"
```

### `search_code`

Search for code across GitHub repositories. Uses the legacy code search engine (no regex, no symbol search, no path globs). Rate limit: 10 requests/minute.

```
Use gh-tooling search_code with query "addClass" and repo "shopware/shopware"
Use gh-tooling search_code with query "extends AbstractController" and language "php" and limit 10
Use gh-tooling search_code with query "composer.json" and match "path" and owner "shopware"
Use gh-tooling search_code with query "addClass" and repo "shopware/shopware" and download_to "/tmp/results"
```

**Parameters:**
- `query` (string, required): Code search query text (exact text match, no regex).
- `owner` (string, optional): Limit to repositories owned by this user/org.
- `repo` (string, optional): Limit to this repository in `owner/repo` format.
- `language` (string, optional): Filter by language (e.g. `php`, `typescript`).
- `extension` (string, optional): Filter by file extension (e.g. `php`, `ts`).
- `filename` (string, optional): Filter by filename (e.g. `composer.json`).
- `match` (string, optional): Restrict matches to `file` contents or `path`.
- `limit` (integer, optional): Max results. Default: 30.
- `download_to` (string, optional): Local directory. Downloads matching files instead of returning results.
- Supports all grep parameters and `max_lines`/`tail_lines`.

### `search_repos`

Search for repositories by query, owner, topic, language, license, or star count. Query is optional — filters alone suffice.

```
Use gh-tooling search_repos with owner "shopware" and language "php"
Use gh-tooling search_repos with query "ecommerce" and stars ">100" and sort "stars"
Use gh-tooling search_repos with topic "shopware" and limit 10
```

**Parameters:**
- `query` (string, optional): Search text.
- `owner` (string, optional): Filter by owner.
- `topic` (string, optional): Filter by topic tag.
- `language` (string, optional): Filter by language.
- `license` (string, optional): Filter by SPDX license (e.g. `mit`).
- `stars` (string, optional): Star count range (e.g. `>100`, `50..200`).
- `sort` (string, optional): `stars`, `forks`, `help-wanted-issues`, or `updated`.
- `limit` (integer, optional): Max results. Default: 20.

### `search_commits`

Search for commits by message text, author, date range, or hash.

```
Use gh-tooling search_commits with query "NEXT-1234" and repo "shopware/shopware"
Use gh-tooling search_commits with query "fix cart" and author "mitelg" and author_date ">2024-01-01"
```

**Parameters:**
- `query` (string, required): Commit message search text.
- `repo` (string, optional): Limit to this repository in `owner/repo` format.
- `owner` (string, optional): Limit to repositories owned by this user/org.
- `author` (string, optional): Filter by commit author username.
- `committer` (string, optional): Filter by committer username.
- `author_date` (string, optional): Date range (e.g. `>2024-01-01`, `2024-01-01..2024-06-30`).
- `committer_date` (string, optional): Committer date range.
- `hash` (string, optional): Filter by SHA prefix.
- `merge` (boolean, optional): Filter merge commits.
- `sort` (string, optional): `author-date` or `committer-date`.
- `limit` (integer, optional): Max results. Default: 20.

### `search_discussions`

Search for GitHub discussions via GraphQL. Discussions are only available via GraphQL.

```
Use gh-tooling search_discussions with query "RFC" and repo "shopware/shopware"
Use gh-tooling search_discussions with query "authentication" and category "Q&A" and with_comments true
```

**Parameters:**
- `query` (string, required): Discussion search text.
- `repo` (string, optional): Limit to this repository in `owner/repo` format.
- `category` (string, optional): Filter by category name (e.g. `RFC`, `Q&A`).
- `author` (string, optional): Filter by author username.
- `state` (string, optional): State qualifier (e.g. `is:answered`, `is:open`).
- `with_comments` (boolean, optional): Include comment bodies and replies. Default: `false`.
- `limit` (integer, optional): Max results. Default: 20.
- `jq_filter` (string, optional): Applied to full GraphQL response. Default: `.data.search.nodes`.

### `repo_tree`

Browse repository directory contents or get the full recursive file tree. Accepts GitHub URLs. Use instead of `WebFetch` on GitHub tree URLs.

```
Use gh-tooling repo_tree with url "https://github.com/shopware/shopware/tree/main/src/Core"
Use gh-tooling repo_tree with repository "shopware/shopware" and path "src/Core"
Use gh-tooling repo_tree with repository "shopware/shopware" and recursive true
```

**Parameters:**
- `owner` (string, optional): Repository owner. Used with `repo`.
- `repo` (string, optional): Repository name. Used with `owner`.
- `repository` (string, optional): `owner/repo` format.
- `path` (string, optional): Directory path. Default: root.
- `ref` (string, optional): Branch, tag, or SHA.
- `recursive` (boolean, optional): Get full recursive tree. Default: `false`.
- `url` (string, optional): GitHub URL to parse. Explicit params override URL values. Note: URLs with slashed refs (e.g. `feature/my-branch`) are not parsed correctly — use explicit `ref` param instead.

### `repo_file`

Fetch a single file from a GitHub repository as raw text. Accepts GitHub URLs. Use instead of `WebFetch` on GitHub blob URLs.

```
Use gh-tooling repo_file with url "https://github.com/shopware/shopware/blob/main/composer.json"
Use gh-tooling repo_file with repository "shopware/shopware" and path "composer.json"
Use gh-tooling repo_file with repository "shopware/shopware" and path "src/Core/Kernel.php" and line_start 1 and line_end 20
Use gh-tooling repo_file with repository "shopware/shopware" and path "composer.json" and download_to "/tmp/composer.json"
```

**Parameters:**
- `owner` (string, optional): Repository owner. Used with `repo`.
- `repo` (string, optional): Repository name. Used with `owner`.
- `repository` (string, optional): `owner/repo` format.
- `path` (string, required unless from URL): File path within the repository.
- `ref` (string, optional): Branch, tag, or SHA.
- `url` (string, optional): GitHub URL to parse. Explicit params override URL values. Note: URLs with slashed refs (e.g. `feature/my-branch`) are not parsed correctly — use explicit `ref` param instead.
- `line_start` (integer, optional): First line to return (1-indexed).
- `line_end` (integer, optional): Last line to return (inclusive).
- `download_to` (string, optional): Local path. Saves file content instead of returning it.
- Supports all grep parameters and `max_lines`/`tail_lines`.

### `api`

Raw GitHub REST API call (escape hatch for unsupported operations).

```
Use gh-tooling api with endpoint "repos/shopware/shopware/issues/8498/timeline"
Use gh-tooling api with endpoint "repos/shopware/shopware/pulls/14642/comments" and paginate true
Use gh-tooling api with endpoint "search/issues" and jq_filter ".items[] | {number, title, state}"
```

## MCP Tool Enforcement

This plugin includes a PreToolUse hook that blocks bash commands in favor of MCP tools. The hook ensures Claude uses the proper MCP tools which provide structured output and consistent parameter handling.

### Disabling Enforcement

To allow direct CLI invocations, set `enforce_mcp_tools` to `false` in your config:

```json
{
  "enforce_mcp_tools": false
}
```

### Blocked Commands

| Bash Command | MCP Tool |
|--------------|----------|
| `gh pr view` | `mcp__gh-tooling__pr_view` |
| `gh pr diff` | `mcp__gh-tooling__pr_diff` |
| `gh pr list` | `mcp__gh-tooling__pr_list` |
| `gh pr checks` | `mcp__gh-tooling__pr_checks` |
| `gh issue view` | `mcp__gh-tooling__issue_view` |
| `gh issue list` | `mcp__gh-tooling__issue_list` |
| `gh run view` | `mcp__gh-tooling__run_view` / `run_logs` |
| `gh run list` | `mcp__gh-tooling__run_list` |
| `gh search code` | `mcp__gh-tooling__search_code` |
| `gh search repos` | `mcp__gh-tooling__search_repos` |
| `gh search commits` | `mcp__gh-tooling__search_commits` |
| `gh search` (issues/prs) | `mcp__gh-tooling__search` |

### Optional: `gh api` Blocking

With `block_api_commands: true`, additionally blocks `gh api` calls for endpoints with dedicated MCP tools:

| Endpoint Pattern           | MCP Tool                  |
|----------------------------|---------------------------|
| `pulls/N/comments`         | `pr_comments`             |
| `pulls/N/reviews`          | `pr_reviews`              |
| `pulls/N/files`            | `pr_files`                |
| `pulls/N/commits`          | `pr_commits`              |
| `actions/jobs/N/logs`      | `job_logs`                |
| `actions/jobs/N`           | `job_view`                |
| `check-runs/N/annotations` | `job_annotations`         |
| `commits/SHA/pulls`        | `commit_pulls`            |
| `git/trees/...`            | `repo_tree`               |
| `contents/...`             | `repo_tree` / `repo_file` |

### Commands NOT Blocked

- `gh auth login` (setup commands)
- `gh run download` (no dedicated MCP tool)
- `gh api` calls for endpoints without a dedicated tool (when `block_api_commands` is false)

## Integration with Other Plugins

Other plugins can reference these tools in their tool lists:

```markdown
---
tools: mcp__gh-tooling__pr_view, mcp__gh-tooling__run_logs, mcp__gh-tooling__search
---

After pushing, check PR status and CI results.
```

## Troubleshooting

### MCP Server Not Starting

1. Ensure Claude Code was restarted after plugin installation
2. Check `/mcp` for connection status
3. Verify `jq` is installed: `which jq`
4. Verify `gh` is installed and authenticated: `gh auth status`

### gh Not Authenticated

1. Run `gh auth login` and follow the prompts
2. Verify with `gh auth status`

## Dependencies

- **bash** (4.0+)
- **jq** (JSON processor)
- **gh** CLI (GitHub CLI, authenticated)

## License

MIT
