@README.md

## Directory & File Structure

```
plugins/gh-tooling/
├── README.md                           # User documentation (usage, configuration, troubleshooting)
├── REFERENCE.md                        # Full tool parameter docs and examples (25 tools)
├── AGENTS.md                           # LLM navigation guide (this file)
├── CLAUDE.md                           # Points to AGENTS.md
├── CHANGELOG.md                        # Version history
│
├── .mcp.json                           # MCP server registration (gh-tooling)
│
├── hooks/                              # PRETOOLUSE HOOKS (MCP tool enforcement)
│   ├── hooks.json                      # Hook configuration (PreToolUse matcher for Bash)
│   └── scripts/
│       ├── check-gh-tools.sh           # Blocks common gh CLI bash commands
│       └── lib/
│           └── common.sh               # Shared: parse_hook_input(), load_mcp_config(), block_tool()
│
├── shared/                             # SHARED FRAMEWORK (language-agnostic)
│   └── mcpserver_core.sh              # JSON-RPC 2.0 protocol handler
│
└── mcp-server-gh/                      # GITHUB CLI MCP SERVER (optional config)
    ├── server.sh                      # Entry point - loads optional .mcp-gh-tooling.json
    ├── config.json                    # Server metadata (name="gh-tooling")
    ├── tools.json                     # 25 GitHub tools (PR, issue, CI, commit, search, repo, api)
    ├── mcp-gh-tooling.schema.json     # JSON Schema for .mcp-gh-tooling.json
    └── lib/
        ├── common.sh                  # _gh_validate_number/repo/sha(), _gh_resolve_repo(), _gh_validate_jq_filter(), _gh_post_process(), _gh_parse_github_url(), _gh_validate_path(), _gh_download_file(), _gh_resolve_owner_repo()
        ├── pr.sh                      # tool_pr_view/diff/list/checks/comments/reviews/files/commits()
        ├── issue.sh                   # tool_issue_view(), tool_issue_list()
        ├── run.sh                     # tool_run_view(), tool_run_list(), tool_run_logs()
        ├── job.sh                     # tool_job_view(), tool_job_logs(), tool_job_annotations()
        ├── commit.sh                  # tool_commit_pulls()
        ├── search.sh                  # tool_search(), tool_search_code(), tool_search_repos(), tool_search_commits(), tool_search_discussions()
        ├── repo.sh                    # tool_repo_tree(), tool_repo_file()
        └── api.sh                     # tool_api()
```

## Component Overview

This plugin provides:
- **One MCP Server** via `.mcp.json`:
  - `gh-tooling` - GitHub CLI wrapper (PRs, issues, CI runs, jobs, commits, search, repo browsing)
- **PreToolUse Hook** via `hooks/hooks.json`:
  - Blocks bash commands that should use MCP tools instead
  - Blocks high-level gh subcommands (`gh pr view`, `gh issue view`, etc.)
  - Optionally blocks `gh api` calls for endpoints with dedicated MCP tools
  - Configurable via `enforce_mcp_tools: false` in `.mcp-gh-tooling.json`

## Architecture

### Config Loading

The gh-tooling server has its own config loading logic independent of any shared config framework:
- Config is **optional** (works without any config file if `gh` is authenticated)
- Provides a default repo so `repo` doesn't need to be passed to every tool call
- Config discovery checks standard locations (project root, LLM tool directories, `.claude/`)

### Protocol Flow

```
Claude Code → stdin → server.sh → mcpserver_core.sh → tool_* function
                                                           ↓
Claude Code ← stdout ← JSON-RPC response ← formatted output
```

### Tool Dispatch Convention

Tools in `tools.json` map to bash functions with `tool_` prefix:
- Uses bash arrays (`local -a cmd=("gh" "pr" "view" "${number}")`) for injection-safe argument passing
- `_gh_resolve_repo()` falls back to `GH_DEFAULT_REPO` from config
- All 25 tools support `suppress_errors` and `fallback` shared parameters
- Tools with JSON output support `jq_filter` with pre-execution syntax validation
- Log/text tools support `max_lines`, `tail_lines`, and grep parameters

### Standard execution block

Captures `__raw` and `__exit` separately; branches on `suppress_errors` for `2>/dev/null` vs `2>&1`; checks `fallback` before re-echoing error output. Always calls `_gh_post_process()` on success.

## Key Navigation Points

| Task | Primary File | Secondary File | Key Concepts |
|------|--------------|----------------|--------------|
| Add GitHub tool | `mcp-server-gh/lib/<group>.sh` | `mcp-server-gh/tools.json` | `tool_*()`, array-based `gh` args |
| Add blocked gh command | `hooks/scripts/check-gh-tools.sh` | - | `block_tool()`, grep pattern |
| Modify shared hook logic | `hooks/scripts/lib/common.sh` | - | `parse_hook_input()`, `load_mcp_config()`, `block_tool()` |
| Disable hook enforcement | `.mcp-gh-tooling.json` | - | `enforce_mcp_tools: false` |
| Modify protocol | `shared/mcpserver_core.sh` | - | `process_request()`, `handle_*()` |
| Update tool schemas | `mcp-server-gh/tools.json` | - | JSON Schema Draft 7 |

## When to Modify What

**Adding a new GitHub tool:**
1. Choose or create appropriate `mcp-server-gh/lib/<group>.sh` (pr, issue, run, job, commit, search)
2. Add `tool_<name>()` function using bash arrays for gh CLI args (not string eval)
3. Validate inputs via `_gh_validate_number()`, `_gh_validate_repo()`, `_gh_validate_sha()` from `lib/common.sh`; validate jq_filter via `_gh_validate_jq_filter()`
4. Use the standard execution block (suppress_errors/fallback) instead of bare `"${cmd[@]}" 2>&1`; pipe output through `_gh_post_process()` for jq/grep/head/tail support
5. Add `suppress_errors`, `fallback`, and any applicable `jq_filter`/`max_lines`/`tail_lines`/grep params to `tools.json` inputSchema
6. Add tool definition to `mcp-server-gh/tools.json`
7. If new file: source it in `mcp-server-gh/server.sh`
8. Update README.md

**Key design decisions:**
- No environment wrapping (gh always runs natively on host)
- Config is optional (no config = works with no default repo)
- Uses bash arrays instead of string eval for injection safety
- Hook has two enforcement levels: `enforce_mcp_tools` (default `true`) blocks high-level subcommands; `block_api_commands` (default `false`, opt-in) additionally blocks `gh api` calls for endpoints with dedicated MCP tools

## Integration with Other Plugins

MCP tool names follow pattern: `mcp__gh-tooling__<tool_name>`

```yaml
# GitHub tools
tools: mcp__gh-tooling__pr_view, mcp__gh-tooling__run_logs, mcp__gh-tooling__search
```

## Testing

BATS tests for hook scripts and MCP tool functions are in `plugin-tests/gh-tooling/`:

| Test File | Coverage |
|-----------|----------|
| `gh_tools.bats` | GitHub CLI tool blocking (gh pr, gh issue, gh run, gh search, gh api) |
| `mcp_tool_gh.bats` | MCP tool shared parameters (_gh_validate_jq_filter, _gh_post_process, suppress_errors, fallback) |
| `extra_log_file.bats` | Extra log file configuration and dual-write log() |

Run tests:
```bash
.bats/bats-core/bin/bats plugin-tests/gh-tooling/*.bats
```

## External References

- [Bash MCP SDK](https://github.com/muthuishere/mcp-server-bash-sdk) - SDK this server is based on
- [MCP Protocol Specification](https://modelcontextprotocol.io/specification) - JSON-RPC 2.0 protocol details
