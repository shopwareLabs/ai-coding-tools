# Tools Reference

Tools are available via the `gh-tooling` MCP server. Requires `gh` CLI installed and authenticated.

## Shared Tool Parameters

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

## `pr_view`

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

## `pr_diff`

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

## `pr_list`

List pull requests with filters.

```
Use gh-tooling pr_list with author "mitelg" and state "merged" and limit 5
Use gh-tooling pr_list with search "NEXT-3412" and state "all"
Use gh-tooling pr_list with head "feature/my-branch"
```

## `pr_checks`

View CI status checks for a pull request.

```
Use gh-tooling pr_checks with number 14642
```

## `pr_comments`

Get inline review comments (code-level) for a PR.

```
Use gh-tooling pr_comments with number 14642
Use gh-tooling pr_comments with number 14642 and jq_filter ".[] | {path, body, line, user: .user.login}"
```

## `pr_reviews`

Get review decisions for a pull request.

```
Use gh-tooling pr_reviews with number 14642
Use gh-tooling pr_reviews with number 14642 and jq_filter ".[] | select(.state == \"CHANGES_REQUESTED\") | {user: .user.login, body}"
```

## `pr_files`

Get changed files with patch content.

```
Use gh-tooling pr_files with number 13911
Use gh-tooling pr_files with number 13911 and jq_filter ".[] | select(.filename | contains(\"Migration\")) | {filename, patch}"
```

## `pr_commits`

Get the commit history for a pull request.

```
Use gh-tooling pr_commits with number 14642
```

## `issue_view`

View a GitHub issue.

```
Use gh-tooling issue_view with number 8498
Use gh-tooling issue_view with number 8498 and with_comments true
Use gh-tooling issue_view with number 8498 and fields "title,body,state,labels,comments"
```

## `issue_list`

List issues with filters.

```
Use gh-tooling issue_list with search "TODO label:component/core" and limit 20
```

## `run_view`

View the status of a GitHub Actions workflow run.

```
Use gh-tooling run_view with run_id 21534190745
Use gh-tooling run_view with run_id 21534190745 and fields "status,conclusion"
```

## `run_list`

List recent GitHub Actions runs.

```
Use gh-tooling run_list with branch "tests/content-system-unit-tests" and limit 5
```

## `run_logs`

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

## `job_view`

Get details for a specific CI job including step statuses.

```
Use gh-tooling job_view with job_id 62056364818
Use gh-tooling job_view with job_id 62056364818 and jq_filter ".steps[] | select(.conclusion == \"failure\") | {name, number}"
```

## `job_logs`

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

## `job_annotations`

Get inline error annotations from a CI check run.

```
Use gh-tooling job_annotations with check_run_id 62056364818
```

## `commit_pulls`

List GitHub pull requests associated with a pushed commit SHA. GitHub-only — for local commit metadata (files changed, commit message) use `git show <sha>` via Bash.

```
Use gh-tooling commit_pulls with sha "15a7c2bb86"
Use gh-tooling commit_pulls with sha "15a7c2bb86" and jq_filter ".[].number"
```

**Parameters:**
- `sha` (string, required): Commit SHA (7-40 hex characters). Must be pushed to GitHub.
- `repo` (string, optional): Repository in `owner/repo` format.
- `jq_filter` (string, optional): jq expression to filter/transform the PR list.

## `search`

Search for issues or pull requests.

```
Use gh-tooling search with query "NEXT-3412" and type "prs"
Use gh-tooling search with query "custom field translation" and type "issues" and limit 20
Use gh-tooling search with query "attribute entity" and state "closed"
```

## `search_code`

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

## `search_repos`

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

## `search_commits`

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

## `search_discussions`

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

## `repo_tree`

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

## `repo_file`

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

## `api`

Raw GitHub REST API call (escape hatch for unsupported operations).

```
Use gh-tooling api with endpoint "repos/shopware/shopware/issues/8498/timeline"
Use gh-tooling api with endpoint "repos/shopware/shopware/pulls/14642/comments" and paginate true
Use gh-tooling api with endpoint "search/issues" and jq_filter ".items[] | {number, title, state}"
```
