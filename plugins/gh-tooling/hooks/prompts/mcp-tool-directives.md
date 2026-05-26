ALWAYS use gh-tooling MCP tools for GitHub operations. NEVER run gh CLI commands via Bash.

Call all gh-tooling tools sequentially, never in parallel.

Each tool's input schema is the contract. Read the schema for the tool you're calling — do not reuse parameter shapes from adjacent tools. Unknown fields are rejected at the MCP layer.

Repository selection (PR / issue / search / commit / repo tools): pass `repo` (owner/repo), `repository` (owner/repo, alias of `repo`), or `owner`+`repo` (split form, `repo` is the bare name). Repo browsing tools also accept `url`. Inside a git clone, `repo` may be omitted; outside a git repo you must pass one explicitly.

## Read (gh-tooling)
PRs: pr_view, pr_diff, pr_list, pr_checks, pr_comments, pr_reviews, pr_files, pr_commits
Issues: issue_view, issue_list
CI: run_view, run_list, run_logs, workflow_jobs, job_view, job_logs, job_annotations
Commits: commit_pulls
Search: search, search_code, search_repos, search_commits, search_discussions
Repo: repo_tree, repo_file
Labels: label_list
Projects: project_list, project_view
Escape hatch (last resort): api_read (GET only). Use only when no dedicated tool covers your endpoint — not as a fallback when a dedicated tool returns an error.

{{WRITE_SECTION}}
{{LABEL_SECTION}}
