# GitHub Tooling

GitHub CLI tools via MCP (Model Context Protocol). Wraps the `gh` CLI for pull requests, issues, CI runs, jobs, commits, search, and repository file browsing. Configuration-optional: works without a config file when `gh` is authenticated.

## Features

### GitHub Tools (gh-tooling MCP Server)
- **PR inspection** via `pr_view`, `pr_diff`, `pr_list`, `pr_checks`
- **PR review data** via `pr_comments`, `pr_reviews`, `pr_files`, `pr_commits`
- **Issue operations** via `issue_view`, `issue_list`
- **GitHub Actions CI** via `run_view`, `run_list`, `run_logs`, `workflow_jobs`
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

26 tools organized by category. See [REFERENCE.md](./REFERENCE.md) for full parameter docs and examples.

| Category | Tools |
|----------|-------|
| PR inspection | `pr_view`, `pr_diff`, `pr_list`, `pr_checks` |
| PR review data | `pr_comments`, `pr_reviews`, `pr_files`, `pr_commits` |
| Issues | `issue_view`, `issue_list` |
| CI runs | `run_view`, `run_list`, `run_logs`, `workflow_jobs` |
| CI jobs | `job_view`, `job_logs`, `job_annotations` |
| Commits | `commit_pulls` |
| Search | `search`, `search_code`, `search_repos`, `search_commits`, `search_discussions` |
| Repository | `repo_tree`, `repo_file` |
| Raw API | `api` |

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
