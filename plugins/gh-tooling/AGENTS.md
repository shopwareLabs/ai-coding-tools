@README.md

## Directory & File Structure

```
plugins/gh-tooling/
├── README.md                           # User documentation (usage, configuration, troubleshooting)
├── REFERENCE.md                        # Full tool parameter docs and examples (29 read + 23 write tools)
├── AGENTS.md                           # LLM navigation guide (this file)
├── CLAUDE.md                           # Points to AGENTS.md
├── CHANGELOG.md                        # Version history
│
├── .mcp.json                           # MCP server registration (gh-tooling + gh-tooling-write)
│
├── hooks/                              # HOOKS (MCP tool enforcement)
│   ├── hooks.json                      # Hook configuration (SessionStart + PreToolUse x3)
│   ├── prompts/
│   │   └── mcp-tool-directives.md      # SessionStart prompt template: MCP tool listing and usage rules
│   └── scripts/
│       ├── session-start.sh            # SessionStart hook: assembles prompt from template + conditional sections
│       ├── check-gh-tools.sh           # Blocks common gh CLI bash commands (read + write)
│       ├── check-api-tools.sh          # Blocks MCP api_read/api tool bypass of dedicated tools
│       └── lib/
│           └── common.sh              # Shared: parse_hook_input(), load_mcp_config(), block_tool()
│
├── shared/                             # SHARED FRAMEWORK (language-agnostic)
│   └── mcpserver_core.sh              # JSON-RPC 2.0 protocol handler
│
└── mcp-server-gh/                      # GITHUB CLI MCP SERVERS
    ├── server-read.sh                 # Read server entry point - loads optional .mcp-gh-tooling.json
    ├── server-write.sh                # Write server entry point - gated by enable_write_server config
    ├── config-read.json               # Read server metadata (name="gh-tooling")
    ├── config-write.json              # Write server metadata (name="gh-tooling-write")
    ├── tools-read.json                # 29 read tools (PR, issue, CI, commit, search, repo, label, project, api_read)
    ├── tools-write.json               # 23 write tools (PR lifecycle, reviews, issues, labels, assignees, sub-issues, projects, api)
    ├── mcp-gh-tooling.schema.json     # JSON Schema for .mcp-gh-tooling.json
    └── lib/
        ├── common.sh                  # _gh_validate_number/repo/sha(), _gh_resolve_repo(), _gh_validate_jq_filter(), _gh_post_process(), _gh_parse_github_url(), _gh_validate_path(), _gh_download_file(), _gh_resolve_owner_repo()
        ├── pr.sh                      # tool_pr_view/diff/list/checks/comments/reviews/files/commits()
        ├── pr_write.sh                # tool_pr_create/edit/ready/merge/close/reopen()
        ├── issue.sh                   # tool_issue_view(), tool_issue_list()
        ├── issue_write.sh             # tool_issue_create/edit/close/reopen/comment()
        ├── review_write.sh            # tool_pr_review_submit(), tool_pr_comment(), tool_pr_review_reply()
        ├── run.sh                     # tool_run_view(), tool_run_list(), tool_run_logs(), tool_workflow_jobs()
        ├── job.sh                     # tool_job_view(), tool_job_logs(), tool_job_annotations()
        ├── commit.sh                  # tool_commit_pulls()
        ├── search.sh                  # tool_search(), tool_search_code(), tool_search_repos(), tool_search_commits(), tool_search_discussions()
        ├── repo.sh                    # tool_repo_tree(), tool_repo_file()
        ├── label.sh                   # tool_label_list() (read), tool_label_add(), tool_label_remove() (write)
        ├── assignee_write.sh          # tool_assignee_add(), tool_assignee_remove()
        ├── sub_issue_write.sh         # tool_sub_issue_add(), tool_sub_issue_remove() (GraphQL)
        ├── project.sh                 # tool_project_list(), tool_project_view() (read), tool_project_item_add(), tool_project_status_set() (write, name-to-ID resolution)
        └── api.sh                     # tool_api_read() (GET only), tool_api() (all methods)
```

## Component Overview

This plugin provides:
- **Two MCP Servers** via `.mcp.json`:
  - `gh-tooling` (read) - 29 read-only GitHub tools (PRs, issues, CI, commits, search, repo, labels, projects, read-only API)
  - `gh-tooling-write` (write) - 23 write tools (PR lifecycle, reviews, issues, labels, assignees, sub-issues, projects, full API). Gated by `enable_write_server` config flag.
- **SessionStart Hook** via `hooks/hooks.json`:
  - Assembles MCP tool directives dynamically from template with conditional write and label sections
  - Prompt template maintained in `hooks/prompts/mcp-tool-directives.md`
  - Outputs JSON `additionalContext` format
- **PreToolUse Hooks** via `hooks/hooks.json`:
  - `check-gh-tools.sh` - Blocks bash commands that should use MCP tools instead (both read and write commands)
  - `check-api-tools.sh` - Blocks `api_read` and `api` MCP tools when targeting endpoints with dedicated tools (opt-in via `block_api_tool_read`/`block_api_tool_write`)
- All hook types configurable via `enforce_mcp_tools: false` in `.mcp-gh-tooling.json`

## Architecture

### Config Loading

The gh-tooling servers have their own config loading logic independent of any shared config framework:
- Config is **optional** (works without any config file if `gh` is authenticated)
- Provides a default repo so `repo` doesn't need to be passed to every tool call
- Config discovery checks standard locations (project root, LLM tool directories, `.claude/`)
- Write server checks `enable_write_server` flag and returns empty tools list when disabled

### Protocol Flow

```
Claude Code → stdin → server-read.sh → mcpserver_core.sh → tool_* function
                                                                ↓
Claude Code ← stdout ← JSON-RPC response ← formatted output

Claude Code → stdin → server-write.sh → mcpserver_core.sh → tool_* function
                                                                ↓
Claude Code ← stdout ← JSON-RPC response ← formatted output
```

### Tool Dispatch Convention

Tools in `tools-read.json` and `tools-write.json` map to bash functions with `tool_` prefix:
- Uses bash arrays (`local -a cmd=("gh" "pr" "view" "${number}")`) for injection-safe argument passing
- `_gh_resolve_repo()` falls back to `GH_DEFAULT_REPO` from config
- All tools support `suppress_errors` and `fallback` shared parameters
- Tools with JSON output support `jq_filter` with pre-execution syntax validation
- Log/text tools support `max_lines`, `tail_lines`, and grep parameters

### Standard execution block

Captures `__raw` and `__exit` separately; branches on `suppress_errors` for `2>/dev/null` vs `2>&1`; checks `fallback` before re-echoing error output. Always calls `_gh_post_process()` on success.

## Key Navigation Points

| Task | Primary File | Secondary File | Key Concepts |
|------|--------------|----------------|--------------|
| Add read tool | `mcp-server-gh/lib/<group>.sh` | `mcp-server-gh/tools-read.json` | `tool_*()`, array-based `gh` args |
| Add write tool | `mcp-server-gh/lib/<group>_write.sh` | `mcp-server-gh/tools-write.json` | `tool_*()`, array-based `gh` args |
| Edit SessionStart prompt | `hooks/prompts/mcp-tool-directives.md` | `hooks/scripts/session-start.sh` | Template + conditional sections |
| Add blocked gh command | `hooks/scripts/check-gh-tools.sh` | - | `block_tool()`, grep pattern |
| Add blocked API endpoint | `hooks/scripts/check-api-tools.sh` | - | Endpoint pattern matching |
| Modify shared hook logic | `hooks/scripts/lib/common.sh` | - | `parse_hook_input()`, `load_mcp_config()`, `block_tool()` |
| Disable hook enforcement | `.mcp-gh-tooling.json` | - | `enforce_mcp_tools: false` |
| Enable write server | `.mcp-gh-tooling.json` | - | `enable_write_server: true` |
| Configure label semantics | `.mcp-gh-tooling.json` | - | `labels: {...}` map |
| Modify protocol | `shared/mcpserver_core.sh` | - | `process_request()`, `handle_*()` |
| Update read tool schemas | `mcp-server-gh/tools-read.json` | - | JSON Schema Draft 7 |
| Update write tool schemas | `mcp-server-gh/tools-write.json` | - | JSON Schema Draft 7 |

## When to Modify What

**Adding a new read tool:**
1. Choose or create appropriate `mcp-server-gh/lib/<group>.sh` (pr, issue, run, job, commit, search, label, project)
2. Add `tool_<name>()` function using bash arrays for gh CLI args (not string eval)
3. Validate inputs via `_gh_validate_number()`, `_gh_validate_repo()`, `_gh_validate_sha()` from `lib/common.sh`; validate jq_filter via `_gh_validate_jq_filter()`
4. Use the standard execution block (suppress_errors/fallback) instead of bare `"${cmd[@]}" 2>&1`; pipe output through `_gh_post_process()` for jq/grep/head/tail support
5. Add `suppress_errors`, `fallback`, and any applicable `jq_filter`/`max_lines`/`tail_lines`/grep params to `tools-read.json` inputSchema
6. Add tool definition to `mcp-server-gh/tools-read.json`
7. If new file: source it in `mcp-server-gh/server-read.sh`
8. Update README.md and REFERENCE.md

**Adding a new write tool:**
1. Choose or create appropriate `mcp-server-gh/lib/<group>_write.sh`
2. Add `tool_<name>()` function using bash arrays for gh CLI args
3. Add tool definition to `mcp-server-gh/tools-write.json`
4. If new file: source it in `mcp-server-gh/server-write.sh`
5. Add bash command blocking in `hooks/scripts/check-gh-tools.sh`
6. Update README.md and REFERENCE.md

**Key design decisions:**
- No environment wrapping (gh always runs natively on host)
- Config is optional (no config = works with no default repo)
- Uses bash arrays instead of string eval for injection safety
- Read/write separation: read server always active, write server gated by config flag
- Hook has three enforcement layers: `enforce_mcp_tools` (default `true`) blocks high-level subcommands; `block_api_commands` (default `false`, opt-in) blocks `gh api` bash calls; `block_api_tool_read`/`block_api_tool_write` (default `false`, opt-in) blocks MCP API tool bypass

## Integration with Other Plugins

MCP tool names follow patterns:
- Read tools: `mcp__gh-tooling__<tool_name>`
- Write tools: `mcp__gh-tooling-write__<tool_name>`

```yaml
# Read tools
tools: mcp__gh-tooling__pr_view, mcp__gh-tooling__run_logs, mcp__gh-tooling__search

# Write tools
tools: mcp__gh-tooling-write__pr_create, mcp__gh-tooling-write__pr_comment, mcp__gh-tooling-write__label_add
```

## Testing

BATS tests for hook scripts and MCP tool functions are in `plugin-tests/gh-tooling/`:

| Test File | Coverage |
|-----------|----------|
| `gh_tools.bats` | GitHub CLI tool blocking (gh pr, gh issue, gh run, gh search, gh label, gh project, gh api) |
| `mcp_tool_gh.bats` | MCP tool shared parameters (_gh_validate_jq_filter, _gh_post_process, suppress_errors, fallback) |
| `extra_log_file.bats` | Extra log file configuration and dual-write log() |

Run tests:
```bash
.bats/bats-core/bin/bats plugin-tests/gh-tooling/*.bats
```

## External References

- [Bash MCP SDK](https://github.com/muthuishere/mcp-server-bash-sdk) - SDK this server is based on
- [MCP Protocol Specification](https://modelcontextprotocol.io/specification) - JSON-RPC 2.0 protocol details
