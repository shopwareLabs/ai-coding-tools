ALWAYS use gh-tooling MCP tools for GitHub operations. NEVER run gh CLI commands via Bash.

Call all gh-tooling tools sequentially, never in parallel.

## Read (gh-tooling)
PRs: pr_view, pr_diff, pr_list, pr_checks, pr_comments, pr_reviews, pr_files, pr_commits
Issues: issue_view, issue_list
CI: run_view, run_list, run_logs, workflow_jobs, job_view, job_logs, job_annotations
Commits: commit_pulls
Search: search, search_code, search_repos, search_commits, search_discussions
Repo: repo_tree, repo_file
Labels: label_list
Projects: project_list, project_view
API: api (GET only)

{{WRITE_SECTION}}
{{LABEL_SECTION}}
