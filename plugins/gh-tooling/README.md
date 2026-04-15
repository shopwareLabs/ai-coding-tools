# GitHub Tooling

GitHub CLI tools via MCP (Model Context Protocol). Wraps the `gh` CLI for pull requests, issues, CI runs, jobs, commits, search, labels, projects, and repository file browsing. Two MCP servers: a read server (always active) and a write server (opt-in). Configuration-optional: works without a config file when `gh` is authenticated.

## Features

### Read Server (gh-tooling)
- **PR inspection** via `pr_view`, `pr_diff`, `pr_list`, `pr_checks`
- **PR review data** via `pr_comments`, `pr_reviews`, `pr_files`, `pr_commits`
- **Issue operations** via `issue_view`, `issue_list`
- **GitHub Actions CI** via `run_view`, `run_list`, `run_logs`, `workflow_jobs`
- **Job-level CI debugging** via `job_view`, `job_logs`, `job_annotations`
- **Commit PR lookup** via `commit_pulls`
- **Cross-repo search** via `search` (issues and PRs), `search_code`, `search_repos`, `search_commits`, `search_discussions`
- **Repository browsing** via `repo_tree` (directory listings) and `repo_file` (file content) -- use instead of WebFetch on GitHub URLs
- **Labels** via `label_list`
- **Projects** via `project_list`, `project_view`
- **Read-only API access** via `api_read` (GET only)

### Write Server (gh-tooling-write)
- **PR lifecycle** via `pr_create`, `pr_edit`, `pr_ready`, `pr_merge`, `pr_close`, `pr_reopen`
- **Reviews** via `pr_review_submit`, `pr_comment`, `pr_review_reply`
- **Issue lifecycle** via `issue_create`, `issue_edit`, `issue_close`, `issue_reopen`, `issue_comment`
- **Labels** via `label_add`, `label_remove`
- **Assignees** via `assignee_add`, `assignee_remove`
- **Sub-issues** via `sub_issue_add`, `sub_issue_remove` (GraphQL)
- **Projects** via `project_item_add`, `project_status_set` (name-to-ID resolution)
- **Full API access** via `api` (all HTTP methods)

## Quick Start

### Installation

```bash
/plugin install gh-tooling@shopware-ai-coding-tools
```

> [!IMPORTANT]
> Restart Claude Code after installation for the MCP server to initialize.

### Interactive Setup

After restarting, ask Claude to help you set up the plugin:

```
Help me set up gh-tooling
```

The `setting-up` skill verifies prerequisites (`gh`, `jq`) and optionally creates a config file with a default repository. You can also configure manually -- see [Configuration](#configuration) below.

### Verification

After restarting, verify the MCP server is running:

```bash
/mcp
```

You should see `gh-tooling` listed as a connected server. If you enabled the write server, you should also see `gh-tooling-write`.

## Configuration

### `.mcp-gh-tooling.json`

The gh-tooling server is **configuration-optional** - it works without any config file as long as `gh` is authenticated. A config file adds a default repository so you don't need to pass `repo` to every tool call.

```json
{
  "repo": "shopware/shopware"
}
```

With write server enabled and full enforcement:

```json
{
  "repo": "shopware/shopware",
  "enable_write_server": true,
  "enforce_mcp_tools": true,
  "block_api_commands": true,
  "block_api_tool_read": true,
  "block_api_tool_write": true
}
```

With label semantics:

```json
{
  "repo": "shopware/shopware",
  "enable_write_server": true,
  "labels": {
    "bug": "Confirmed bug in existing functionality",
    "enhancement": "New feature or improvement request",
    "needs-triage": "Issue requires team review and classification"
  }
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

| Field                  | Type    | Default | Description                                                                                                                                                                                                                                                                                                                                  |
|------------------------|---------|---------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `repo`                 | string  | --      | Default repository in `owner/repo` format. Used when `repo` is not passed to a tool call.                                                                                                                                                                                                                                                    |
| `enforce_mcp_tools`    | boolean | `true`  | Blocks high-level `gh` subcommands (`gh pr view`, `gh issue view`, `gh run view`, `gh search`, `gh pr create`, `gh label list`, `gh project view`, etc.) and redirects to MCP tools. Set to `false` to disable all gh hook enforcement.                                                                                                      |
| `block_api_commands`   | boolean | `false` | When `true` (and `enforce_mcp_tools` is also `true`), additionally blocks `gh api` calls for endpoints that have a dedicated MCP tool: `pulls/N/comments`, `pulls/N/reviews`, `pulls/N/files`, `pulls/N/commits`, `actions/jobs/N/logs`, `actions/jobs/N`, `check-runs/N/annotations`, `commits/SHA`. Other `gh api` calls remain unblocked. |
| `enable_write_server`  | boolean | `false` | When `true`, the write MCP server exposes write tools (PR creation, issue editing, reviews, etc.). When `false` (default), the write server returns an empty tools list.                                                                                                                                                                     |
| `block_api_tool_read`  | boolean | `false` | When `true`, the read server's `api_read` tool blocks requests to endpoints that have a dedicated read MCP tool, suggesting the dedicated tool instead.                                                                                                                                                                                      |
| `block_api_tool_write` | boolean | `false` | When `true`, the write server's `api` tool blocks requests to endpoints that have a dedicated write MCP tool, suggesting the dedicated tool instead.                                                                                                                                                                                         |
| `labels`               | object  | --      | Label name to description mapping. Injected into the SessionStart prompt so the model understands label semantics when adding, removing, or suggesting labels.                                                                                                                                                                               |
| `log_file`             | string  | --      | Additional log file path. Relative paths resolve against the project root.                                                                                                                                                                                                                                                                   |

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

29 read tools + 23 write tools organized by category. See [REFERENCE.md](./REFERENCE.md) for full parameter docs and examples.

### Read Server (gh-tooling) -- 29 tools

| Category       | Tools                                                                           |
|----------------|---------------------------------------------------------------------------------|
| PR inspection  | `pr_view`, `pr_diff`, `pr_list`, `pr_checks`                                    |
| PR review data | `pr_comments`, `pr_reviews`, `pr_files`, `pr_commits`                           |
| Issues         | `issue_view`, `issue_list`                                                      |
| CI runs        | `run_view`, `run_list`, `run_logs`, `workflow_jobs`                             |
| CI jobs        | `job_view`, `job_logs`, `job_annotations`                                       |
| Commits        | `commit_pulls`                                                                  |
| Search         | `search`, `search_code`, `search_repos`, `search_commits`, `search_discussions` |
| Repository     | `repo_tree`, `repo_file`                                                        |
| Labels         | `label_list`                                                                    |
| Projects       | `project_list`, `project_view`                                                  |
| Raw API        | `api_read` (GET only)                                                           |

### Write Server (gh-tooling-write) -- 23 tools

| Category     | Tools                                                                        |
|--------------|------------------------------------------------------------------------------|
| PR lifecycle | `pr_create`, `pr_edit`, `pr_ready`, `pr_merge`, `pr_close`, `pr_reopen`      |
| Reviews      | `pr_review_submit`, `pr_comment`, `pr_review_reply`                          |
| Issues       | `issue_create`, `issue_edit`, `issue_close`, `issue_reopen`, `issue_comment` |
| Labels       | `label_add`, `label_remove`                                                  |
| Assignees    | `assignee_add`, `assignee_remove`                                            |
| Sub-issues   | `sub_issue_add`, `sub_issue_remove`                                          |
| Projects     | `project_item_add`, `project_status_set`                                     |
| Raw API      | `api` (all HTTP methods)                                                     |

## Write Server

The write server is **disabled by default**. To enable it, set `enable_write_server` to `true` in your config:

```json
{
  "enable_write_server": true
}
```

When disabled, the write server starts but returns an empty tools list -- Claude cannot discover or invoke write tools. This provides a safe default where read operations work out of the box while write operations require explicit opt-in.

After enabling, restart Claude Code. You should see `gh-tooling-write` listed alongside `gh-tooling` in `/mcp`.

## Label Semantics

When a `labels` map is configured, the label names and descriptions are injected into the SessionStart prompt. This gives the model context about what each label means, enabling it to:

- Suggest appropriate labels when creating PRs or issues
- Understand label semantics when filtering or searching
- Apply labels correctly based on the nature of changes

```json
{
  "labels": {
    "bug": "Confirmed bug in existing functionality",
    "enhancement": "New feature or improvement request",
    "breaking-change": "Change that breaks backward compatibility",
    "needs-triage": "Issue requires team review and classification"
  }
}
```

The label descriptions appear in the session context only -- they do not modify the labels themselves in GitHub.

## MCP Tool Enforcement

This plugin enforces MCP tool usage through three layers:

### Layer 1: SessionStart Hook

Injects a directive at the start of every conversation listing all available MCP tools and instructing Claude to use them instead of bash `gh` commands. The prompt is assembled dynamically from a template, with conditional sections for write tools and label semantics. Maintained in `hooks/prompts/mcp-tool-directives.md`.

### Layer 2: Bash Command Blocking (PreToolUse)

Blocks bash commands that match known `gh` subcommands and redirects to the corresponding MCP tool. Acts as a safety net when the SessionStart directive is not followed. Covers both read and write commands.

### Layer 3: MCP API Tool Blocking (PreToolUse)

Optionally blocks the `api_read` and `api` tools when they target endpoints that have dedicated MCP tools. Configured separately via `block_api_tool_read` and `block_api_tool_write`. Implemented in `hooks/scripts/check-api-tools.sh`.

All hook layers respect the `enforce_mcp_tools` setting and are disabled when set to `false`.

### Disabling Enforcement

To allow direct CLI invocations, set `enforce_mcp_tools` to `false` in your config:

```json
{
  "enforce_mcp_tools": false
}
```

### Blocked Commands

#### Read Commands

| Bash Command             | MCP Tool                                 |
|--------------------------|------------------------------------------|
| `gh pr view`             | `mcp__gh-tooling__pr_view`               |
| `gh pr diff`             | `mcp__gh-tooling__pr_diff`               |
| `gh pr list`             | `mcp__gh-tooling__pr_list`               |
| `gh pr checks`           | `mcp__gh-tooling__pr_checks`             |
| `gh issue view`          | `mcp__gh-tooling__issue_view`            |
| `gh issue list`          | `mcp__gh-tooling__issue_list`            |
| `gh run view`            | `mcp__gh-tooling__run_view` / `run_logs` |
| `gh run list`            | `mcp__gh-tooling__run_list`              |
| `gh search code`         | `mcp__gh-tooling__search_code`           |
| `gh search repos`        | `mcp__gh-tooling__search_repos`          |
| `gh search commits`      | `mcp__gh-tooling__search_commits`        |
| `gh search` (issues/prs) | `mcp__gh-tooling__search`                |
| `gh label list`          | `mcp__gh-tooling__label_list`            |
| `gh project list`        | `mcp__gh-tooling__project_list`          |
| `gh project view`        | `mcp__gh-tooling__project_view`          |

#### Write Commands

| Bash Command             | MCP Tool                                         |
|--------------------------|--------------------------------------------------|
| `gh pr create`           | `mcp__gh-tooling-write__pr_create`               |
| `gh pr edit`             | `mcp__gh-tooling-write__pr_edit`                 |
| `gh pr ready`            | `mcp__gh-tooling-write__pr_ready`                |
| `gh pr merge`            | `mcp__gh-tooling-write__pr_merge`                |
| `gh pr close`            | `mcp__gh-tooling-write__pr_close`                |
| `gh pr reopen`           | `mcp__gh-tooling-write__pr_reopen`               |
| `gh pr review`           | `mcp__gh-tooling-write__pr_review_submit`        |
| `gh pr comment`          | `mcp__gh-tooling-write__pr_comment`              |
| `gh issue create`        | `mcp__gh-tooling-write__issue_create`            |
| `gh issue edit`          | `mcp__gh-tooling-write__issue_edit`              |
| `gh issue close`         | `mcp__gh-tooling-write__issue_close`             |
| `gh issue reopen`        | `mcp__gh-tooling-write__issue_reopen`            |
| `gh issue comment`       | `mcp__gh-tooling-write__issue_comment`           |
| `gh project item-add`    | `mcp__gh-tooling-write__project_item_add`        |
| `gh project item-edit`   | `mcp__gh-tooling-write__project_status_set`      |

### Optional: `gh api` Bash Command Blocking

With `block_api_commands: true`, additionally blocks `gh api` bash calls for endpoints with dedicated MCP tools:

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

### Optional: MCP API Tool Blocking

With `block_api_tool_read: true` and/or `block_api_tool_write: true`, the `api_read` and `api` MCP tools themselves will reject requests to endpoints that have dedicated MCP tools. This prevents the model from bypassing purpose-built tools by using the raw API tool within MCP.

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

Write tools use the `gh-tooling-write` server name:

```markdown
---
tools: mcp__gh-tooling-write__pr_create, mcp__gh-tooling-write__pr_comment
---

Create a PR and add a comment.
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

### Write Server Not Showing Tools

1. Verify `enable_write_server` is set to `true` in `.mcp-gh-tooling.json`
2. Restart Claude Code after changing the config
3. Check `/mcp` -- `gh-tooling-write` should be listed with tools

## Dependencies

- **bash** (4.0+)
- **jq** (JSON processor)
- **gh** CLI (GitHub CLI, authenticated)

## License

MIT
