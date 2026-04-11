# Tools Reference

## Read Server (gh-tooling)

29 tools available via the `gh-tooling` MCP server. Requires `gh` CLI installed and authenticated.

### Shared Tool Parameters

All gh-tooling MCP tools accept these parameters:

| Parameter         | Type    | Default | Description                                                             |
|-------------------|---------|---------|-------------------------------------------------------------------------|
| `suppress_errors` | boolean | `false` | Silence stderr; errors produce empty output instead of an error message |
| `fallback`        | string  | --      | Return this text (successfully) when the gh command fails               |

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

`max_lines` and `tail_lines` are also available on `pr_view`, `pr_checks`, `pr_comments`, `pr_reviews`, `issue_view`, `api_read`, `label_list`, `project_list`, and `project_view` for output size control.

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

List recent GitHub Actions runs with optional filters.

```
Use gh-tooling run_list with branch "tests/content-system-unit-tests" and limit 5
Use gh-tooling run_list with workflow "CI" and status "failure" and limit 10
Use gh-tooling run_list with workflow "CI" and branch "main" and event "push"
Use gh-tooling run_list with user "mitelg" and created ">2024-01-01"
Use gh-tooling run_list with commit "abc1234" and fields "databaseId,status,conclusion"
```

**Parameters:**
- `repo` (string, optional): Repository in `owner/repo` format.
- `branch` (string, optional): Filter by branch name.
- `workflow` (string, optional): Filter by workflow name or filename (e.g. `CI`, `build.yml`).
- `status` (string, optional): Filter by status (e.g. `completed`, `failure`, `success`).
- `event` (string, optional): Filter by trigger event (e.g. `push`, `pull_request`, `schedule`).
- `user` (string, optional): Filter by GitHub username who triggered the workflow.
- `created` (string, optional): Filter by creation date range (e.g. `>2024-01-01`).
- `commit` (string, optional): Filter by commit SHA.
- `limit` (integer, optional): Max results. Default: 20.
- `fields` (string, optional): Comma-separated JSON fields.

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

### `workflow_jobs`

Aggregate jobs across workflow runs in a single call. Reduces N+1 tool calls (run_list + N x job_view) to one invocation. Fetches runs for a workflow, then retrieves jobs for each run.

```
Use gh-tooling workflow_jobs with workflow "CI" and repo "shopware/shopware" and job "PHPStan" and limit 3
Use gh-tooling workflow_jobs with workflow "CI" and repo "shopware/shopware" and conclusion "failure"
Use gh-tooling workflow_jobs with workflow "CI" and repo "shopware/shopware" and job "unit" and step "Run tests" and limit 5
Use gh-tooling workflow_jobs with workflow "CI" and repo "shopware/shopware" and run_status "failure" and branch "main"
```

**Parameters:**
- `workflow` (string, required): Workflow name or filename (e.g. `CI`, `build.yml`).
- `repo` (string, required): Repository in `owner/repo` format (pass explicitly or configure default).
- `job` (string, optional): Filter jobs by name (case-insensitive substring).
- `conclusion` (string, optional): Filter by job conclusion (e.g. `failure`, `success`).
- `step` (string, optional): Filter and include steps by name. Steps are excluded unless this is set.
- `limit` (integer, optional): Max workflow runs to fetch (each = 1 API call). Default: 5.
- `run_status` (string, optional): Filter runs by status.
- `branch` (string, optional): Filter runs by branch.
- `event` (string, optional): Filter runs by trigger event.
- `jq_filter` (string, optional): jq expression to filter the final output.
- `max_lines` (integer, optional): Return only the first N lines.

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

List GitHub pull requests associated with a pushed commit SHA. GitHub-only -- for local commit metadata (files changed, commit message) use `git show <sha>` via Bash.

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

Search for repositories by query, owner, topic, language, license, or star count. Query is optional -- filters alone suffice.

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
- `url` (string, optional): GitHub URL to parse. Explicit params override URL values. Note: URLs with slashed refs (e.g. `feature/my-branch`) are not parsed correctly -- use explicit `ref` param instead.

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
- `url` (string, optional): GitHub URL to parse. Explicit params override URL values. Note: URLs with slashed refs (e.g. `feature/my-branch`) are not parsed correctly -- use explicit `ref` param instead.
- `line_start` (integer, optional): First line to return (1-indexed).
- `line_end` (integer, optional): Last line to return (inclusive).
- `download_to` (string, optional): Local path. Saves file content instead of returning it.
- Supports all grep parameters and `max_lines`/`tail_lines`.

### `label_list`

List labels for a repository. Returns label names, descriptions, and colors.

```
Use gh-tooling label_list
Use gh-tooling label_list with repo "shopware/shopware"
Use gh-tooling label_list with filter "bug"
Use gh-tooling label_list with jq_filter ".[] | {name, description}"
```

**Parameters:**
- `repo` (string, optional): Repository in `owner/repo` format.
- `filter` (string, optional): Filter labels by name substring (case-insensitive).
- `jq_filter` (string, optional): jq expression to filter/transform the JSON output.
- `max_lines` (integer, optional): Return only the first N lines.

### `project_list`

List GitHub Projects (v2) for a user or organization. Returns project numbers, titles, and URLs.

```
Use gh-tooling project_list
Use gh-tooling project_list with owner "shopware"
Use gh-tooling project_list with jq_filter ".[] | {number, title}"
```

**Parameters:**
- `owner` (string, optional): Owner (user or org) to list projects for. Defaults to the owner from the configured default repo.
- `jq_filter` (string, optional): jq expression to filter/transform the JSON output.
- `max_lines` (integer, optional): Return only the first N lines.

### `project_view`

View details of a GitHub Project (v2), including field definitions and status options. Use to discover available status values before setting them.

```
Use gh-tooling project_view with number 5
Use gh-tooling project_view with number 5 and owner "shopware"
Use gh-tooling project_view with number 5 and jq_filter ".fields[] | select(.name == \"Status\")"
```

**Parameters:**
- `number` (integer, required): Project number.
- `owner` (string, optional): Owner (user or org). Defaults to the owner from the configured default repo.
- `jq_filter` (string, optional): jq expression to filter/transform the JSON output.
- `max_lines` (integer, optional): Return only the first N lines.

### `api_read`

Read-only GitHub REST API call (GET only). Use the gh-tooling-write server's `api` tool for POST, PATCH, PUT, or DELETE requests.

```
Use gh-tooling api_read with endpoint "repos/shopware/shopware/issues/8498/timeline"
Use gh-tooling api_read with endpoint "repos/shopware/shopware/pulls/14642/comments" and paginate true
Use gh-tooling api_read with endpoint "search/issues" and jq_filter ".items[] | {number, title, state}"
```

**Parameters:**
- `endpoint` (string, required): GitHub API endpoint, relative to `https://api.github.com/`.
- `method` (string, optional): HTTP method. Enum: `GET`, `POST`, `PATCH`, `PUT`, `DELETE`. Default: `GET`.
- `jq_filter` (string, optional): jq expression to filter/transform the JSON response.
- `paginate` (boolean, optional): Fetch all pages of paginated results. Default: `false`.
- `fields` (string, optional): Comma-separated fields for `--jq` selection.
- `max_lines` (integer, optional): Return only the first N lines of output.
- `tail_lines` (integer, optional): Return only the last N lines of output.

---

## Write Server (gh-tooling-write)

23 tools available via the `gh-tooling-write` MCP server. Requires `enable_write_server: true` in `.mcp-gh-tooling.json`.

### Shared Tool Parameters

All gh-tooling-write MCP tools accept these parameters:

| Parameter         | Type    | Default | Description                                                             |
|-------------------|---------|---------|-------------------------------------------------------------------------|
| `suppress_errors` | boolean | `false` | Silence stderr; errors produce empty output instead of an error message |
| `fallback`        | string  | --      | Return this text (successfully) when the gh command fails               |

### PR Write Tools

#### `pr_create`

Create a new pull request. Opens a PR from the current or specified branch. Use `draft` to create a draft PR that is not ready for review.

```
Use gh-tooling-write pr_create with title "Fix cart calculation" and body "Resolves NEXT-1234"
Use gh-tooling-write pr_create with title "Add feature" and base "main" and head "feature/my-feature" and draft true
Use gh-tooling-write pr_create with title "Bug fix" and labels ["bug", "priority/high"] and assignees ["mitelg"]
```

**Parameters:**
- `title` (string, required): Title of the pull request.
- `body` (string, optional): Body text (description) of the pull request.
- `base` (string, optional): Base branch to merge into (e.g. `main`). Defaults to the repository's default branch.
- `head` (string, optional): Head branch containing the changes. Defaults to the current branch.
- `draft` (boolean, optional): Create as a draft pull request. Default: `false`.
- `labels` (array of strings, optional): Labels to apply to the pull request.
- `assignees` (array of strings, optional): GitHub usernames to assign.
- `reviewers` (array of strings, optional): GitHub usernames to request reviews from.
- `milestone` (string, optional): Milestone name or number.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `pr_edit`

Edit an existing pull request's metadata: title, body, base branch, labels, assignees, or milestone. Labels and assignees are added (not replaced). Use the GitHub API tool to remove labels or assignees.

```
Use gh-tooling-write pr_edit with number 14642 and title "Updated title"
Use gh-tooling-write pr_edit with number 14642 and labels ["needs-review"] and assignees ["reviewer1"]
Use gh-tooling-write pr_edit with number 14642 and body "Updated description with more context"
```

**Parameters:**
- `number` (integer, required): Pull request number.
- `title` (string, optional): New title.
- `body` (string, optional): New body text.
- `base` (string, optional): New base branch.
- `labels` (array of strings, optional): Labels to add.
- `assignees` (array of strings, optional): Usernames to add as assignees.
- `milestone` (string, optional): Milestone name or number.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `pr_ready`

Mark a draft pull request as ready for review. Transitions the PR from draft state to open/reviewable state.

```
Use gh-tooling-write pr_ready with number 14642
```

**Parameters:**
- `number` (integer, required): Pull request number.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `pr_merge`

Merge a pull request immediately. Supports merge commit, squash, and rebase strategies. Optionally deletes the head branch after merging.

```
Use gh-tooling-write pr_merge with number 14642
Use gh-tooling-write pr_merge with number 14642 and method "squash" and delete_branch true
Use gh-tooling-write pr_merge with number 14642 and method "squash" and subject "fix: resolve cart calculation"
```

**Parameters:**
- `number` (integer, required): Pull request number.
- `method` (string, optional): Merge strategy. Enum: `merge`, `squash`, `rebase`. Default: `merge`.
- `delete_branch` (boolean, optional): Delete the head branch after merging. Default: `false`.
- `subject` (string, optional): Subject line for the merge commit (used with merge and squash methods).
- `body` (string, optional): Body text for the merge commit message.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `pr_close`

Close a pull request without merging. Optionally posts a comment explaining why the PR is being closed.

```
Use gh-tooling-write pr_close with number 14642
Use gh-tooling-write pr_close with number 14642 and comment "Superseded by #14650"
```

**Parameters:**
- `number` (integer, required): Pull request number.
- `comment` (string, optional): Comment to post when closing.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `pr_reopen`

Reopen a previously closed pull request.

```
Use gh-tooling-write pr_reopen with number 14642
```

**Parameters:**
- `number` (integer, required): Pull request number.
- `repo` (string, optional): Repository in `owner/repo` format.

### Review Write Tools

#### `pr_review`

Submit a review on a pull request. Use event to approve, request changes, or add a comment.

```
Use gh-tooling-write pr_review with number 14642 and event "approve"
Use gh-tooling-write pr_review with number 14642 and event "request_changes" and body "Please address the following issues..."
Use gh-tooling-write pr_review with number 14642 and event "comment" and body "Looks good overall, minor suggestions inside"
```

**Parameters:**
- `number` (integer, required): Pull request number.
- `event` (string, optional): Review event type. Enum: `approve`, `request_changes`, `comment`. Default: `comment`.
- `body` (string, optional): Review body text. Required for `request_changes`.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `pr_comment`

Add a general comment to a pull request.

```
Use gh-tooling-write pr_comment with number 14642 and body "CI is green, ready to merge"
```

**Parameters:**
- `number` (integer, required): Pull request number.
- `body` (string, required): Comment body text.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `pr_review_comment`

Add an inline review comment on a specific file and line in a pull request diff.

```
Use gh-tooling-write pr_review_comment with number 14642 and body "This should use strict comparison" and path "src/Core/Cart/Calculator.php" and line 42
Use gh-tooling-write pr_review_comment with number 14642 and body "This block needs refactoring" and path "src/Core/Cart/Calculator.php" and line 50 and start_line 42
```

**Parameters:**
- `number` (integer, required): Pull request number.
- `body` (string, required): Comment body text.
- `path` (string, required): File path relative to repo root.
- `line` (integer, required): Line number in the diff to comment on.
- `side` (string, optional): Side of the diff. Enum: `LEFT`, `RIGHT`. Default: `RIGHT`.
- `start_line` (integer, optional): Start line for a multi-line comment range.
- `repo` (string, optional): Repository in `owner/repo` format.

### Issue Write Tools

#### `issue_create`

Create a new GitHub issue. Supports labels, assignees, milestone, and project.

```
Use gh-tooling-write issue_create with title "Cart calculation bug" and body "Steps to reproduce..."
Use gh-tooling-write issue_create with title "Feature request" and labels ["enhancement"] and assignees ["mitelg"]
Use gh-tooling-write issue_create with title "Task" and project "Sprint Board"
```

**Parameters:**
- `title` (string, required): Title of the issue.
- `body` (string, optional): Body text (description).
- `labels` (array of strings, optional): Labels to apply.
- `assignees` (array of strings, optional): GitHub usernames to assign.
- `milestone` (string, optional): Milestone name or number.
- `project` (string, optional): Project name or URL to add the issue to.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `issue_edit`

Edit an existing issue's metadata: title, body, labels, assignees, or milestone. Labels and assignees are added (not replaced). Use the GitHub API tool to remove labels or assignees.

```
Use gh-tooling-write issue_edit with number 8498 and title "Updated issue title"
Use gh-tooling-write issue_edit with number 8498 and labels ["priority/high"] and assignees ["reviewer1"]
```

**Parameters:**
- `number` (integer, required): Issue number.
- `title` (string, optional): New title.
- `body` (string, optional): New body text.
- `labels` (array of strings, optional): Labels to add.
- `assignees` (array of strings, optional): Usernames to add as assignees.
- `milestone` (string, optional): Milestone name or number.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `issue_close`

Close an issue. Optionally specify a reason (completed or not_planned) and post a comment when closing.

```
Use gh-tooling-write issue_close with number 8498
Use gh-tooling-write issue_close with number 8498 and reason "completed" and comment "Fixed in #14642"
Use gh-tooling-write issue_close with number 8498 and reason "not_planned" and comment "Won't fix: out of scope"
```

**Parameters:**
- `number` (integer, required): Issue number.
- `reason` (string, optional): Reason for closing. Enum: `completed`, `not_planned`.
- `comment` (string, optional): Comment to post when closing.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `issue_reopen`

Reopen a previously closed issue.

```
Use gh-tooling-write issue_reopen with number 8498
```

**Parameters:**
- `number` (integer, required): Issue number.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `issue_comment`

Post a comment on an issue.

```
Use gh-tooling-write issue_comment with number 8498 and body "This has been fixed in the latest release"
```

**Parameters:**
- `number` (integer, required): Issue number.
- `body` (string, required): Comment text to post.
- `repo` (string, optional): Repository in `owner/repo` format.

### Label Write Tools

#### `label_add`

Add labels to a pull request or issue by name.

```
Use gh-tooling-write label_add with number 14642 and type "pr" and labels ["bug", "priority/high"]
Use gh-tooling-write label_add with number 8498 and type "issue" and labels ["needs-triage"]
```

**Parameters:**
- `number` (integer, required): PR or issue number.
- `type` (string, required): Whether this is a PR or issue. Enum: `pr`, `issue`.
- `labels` (array of strings, required): Label names to add.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `label_remove`

Remove labels from a pull request or issue by name.

```
Use gh-tooling-write label_remove with number 14642 and type "pr" and labels ["needs-triage"]
Use gh-tooling-write label_remove with number 8498 and type "issue" and labels ["bug"]
```

**Parameters:**
- `number` (integer, required): PR or issue number.
- `type` (string, required): Whether this is a PR or issue. Enum: `pr`, `issue`.
- `labels` (array of strings, required): Label names to remove.
- `repo` (string, optional): Repository in `owner/repo` format.

### Assignee Write Tools

#### `assignee_add`

Assign users to a pull request or issue.

```
Use gh-tooling-write assignee_add with number 14642 and type "pr" and assignees ["mitelg", "reviewer1"]
Use gh-tooling-write assignee_add with number 8498 and type "issue" and assignees ["developer1"]
```

**Parameters:**
- `number` (integer, required): PR or issue number.
- `type` (string, required): Whether this is a PR or issue. Enum: `pr`, `issue`.
- `assignees` (array of strings, required): GitHub usernames to assign.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `assignee_remove`

Remove assigned users from a pull request or issue.

```
Use gh-tooling-write assignee_remove with number 14642 and type "pr" and assignees ["reviewer1"]
Use gh-tooling-write assignee_remove with number 8498 and type "issue" and assignees ["developer1"]
```

**Parameters:**
- `number` (integer, required): PR or issue number.
- `type` (string, required): Whether this is a PR or issue. Enum: `pr`, `issue`.
- `assignees` (array of strings, required): GitHub usernames to remove.
- `repo` (string, optional): Repository in `owner/repo` format.

### Sub-Issue Write Tools

#### `sub_issue_add`

Add a sub-issue to a parent issue. Both must exist in the same repository. Uses GitHub's GraphQL sub-issues API.

```
Use gh-tooling-write sub_issue_add with issue_number 100 and sub_issue_number 101
Use gh-tooling-write sub_issue_add with issue_number 100 and sub_issue_number 101 and repo "shopware/shopware"
```

**Parameters:**
- `issue_number` (integer, required): Parent issue number.
- `sub_issue_number` (integer, required): Issue number to add as sub-issue.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `sub_issue_remove`

Remove a sub-issue from a parent issue. Uses GitHub's GraphQL sub-issues API.

```
Use gh-tooling-write sub_issue_remove with issue_number 100 and sub_issue_number 101
```

**Parameters:**
- `issue_number` (integer, required): Parent issue number.
- `sub_issue_number` (integer, required): Sub-issue number to remove.
- `repo` (string, optional): Repository in `owner/repo` format.

### Project Write Tools

#### `project_item_add`

Add an issue or PR to a GitHub Project by project name. The server resolves the project name to its ID.

```
Use gh-tooling-write project_item_add with number 14642 and type "pr" and project "Sprint Board"
Use gh-tooling-write project_item_add with number 8498 and type "issue" and project "Backlog"
```

**Parameters:**
- `number` (integer, required): PR or issue number.
- `type` (string, required): Whether this is a PR or issue. Enum: `pr`, `issue`.
- `project` (string, required): Project name (human-readable). Server resolves to project number.
- `repo` (string, optional): Repository in `owner/repo` format.

#### `project_status_set`

Set the Status field of an issue or PR in a GitHub Project. Both project and status are specified by name -- the server resolves to IDs. The item must already be in the project (use `project_item_add` first).

```
Use gh-tooling-write project_status_set with number 14642 and type "pr" and project "Sprint Board" and status "In Progress"
Use gh-tooling-write project_status_set with number 8498 and type "issue" and project "Sprint Board" and status "Done"
```

**Parameters:**
- `number` (integer, required): PR or issue number.
- `type` (string, required): Whether this is a PR or issue. Enum: `pr`, `issue`.
- `project` (string, required): Project name. Server resolves to project number.
- `status` (string, required): Status value name (e.g. `In Progress`, `Done`). Server resolves to option ID.
- `repo` (string, optional): Repository in `owner/repo` format.

### Write API

#### `api`

Execute a GitHub API call using gh api. Supports all HTTP methods (GET, POST, PATCH, PUT, DELETE). Use this as an escape hatch when specific write tools don't cover your use case.

```
Use gh-tooling-write api with endpoint "repos/shopware/shopware/pulls/14642/requested_reviewers" and method "POST"
Use gh-tooling-write api with endpoint "repos/shopware/shopware/issues/8498/labels" and method "DELETE"
Use gh-tooling-write api with endpoint "repos/shopware/shopware/issues/8498/timeline" and jq_filter ".[] | {event, actor: .actor.login}"
```

**Parameters:**
- `endpoint` (string, required): GitHub API endpoint, relative to `https://api.github.com/`.
- `method` (string, optional): HTTP method. Enum: `GET`, `POST`, `PATCH`, `PUT`, `DELETE`. Default: `GET`.
- `jq_filter` (string, optional): jq expression to filter/transform the output.
- `paginate` (boolean, optional): Enable pagination. Default: `false`.
- `fields` (string, optional): jq expression for `--jq` flag on the gh api call.
- `max_lines` (integer, optional): Return only the first N lines of output.
- `tail_lines` (integer, optional): Return only the last N lines of output.
