---
name: pr-description-writing
version: 1.1.5
model: sonnet
description: >-
  Draft PR titles (conventional commit format) and descriptions (Shopware's 5-section template)
  for the Shopware core repository. Analyzes the full branch scope against trunk, leverages session
  context, and asks targeted questions for missing information.
  Use when the user asks to write, draft, create, or improve a PR description, is about to create
  a PR, or mentions "PR description", "pull request description", or "PR template".
  Do not activate mid-implementation — only when the user is ready to describe their changes.
allowed-tools: Read, Grep, Glob, Bash, AskUserQuestion, mcp__plugin_gh-tooling_gh-tooling__pr_view, mcp__plugin_gh-tooling_gh-tooling__pr_diff, mcp__plugin_gh-tooling_gh-tooling__pr_files, mcp__plugin_gh-tooling_gh-tooling__pr_commits, mcp__plugin_gh-tooling_gh-tooling__pr_comments, mcp__plugin_gh-tooling_gh-tooling__pr_checks, mcp__plugin_gh-tooling_gh-tooling__pr_list, mcp__plugin_gh-tooling_gh-tooling__pr_reviews, mcp__plugin_gh-tooling_gh-tooling__commit_pulls, mcp__plugin_gh-tooling_gh-tooling__issue_view, mcp__plugin_gh-tooling_gh-tooling__issue_list, mcp__plugin_gh-tooling_gh-tooling__search, mcp__plugin_gh-tooling_gh-tooling__search_code
---

# PR Description Drafting

Draft a PR title (conventional commit format) and description (Shopware's 5-section template) by analyzing the full branch scope, leveraging session context, and asking targeted questions for missing context.

**Output scope:** Presents formatted title + description text. Does not create or update PRs on GitHub. Does not write to any files.

## Phase 1 — Assess Branch State

Determine what we're working with — branch, PR status, and diff.

1. Get the current branch: `git branch --show-current`
2. If on `trunk`, stop: "This skill works on feature branches. Switch to a feature branch first."
3. Check for an existing PR:
   - If the user provided a PR number or URL, use `pr_view` to read it
   - Otherwise, use `pr_list` filtered to the current branch
   - If a PR exists, read its current title and description
4. Get the diff:
   - If a PR exists: use `pr_diff` and `pr_files`
   - If no PR: run `git diff trunk...HEAD --stat` and `git log trunk..HEAD --oneline`
5. Present a brief assessment to the user: branch name, PR status (exists / doesn't exist / has existing description), change magnitude (files touched, lines changed, areas affected)

## Phase 2 — Analyze Changes

Understand the full story of the branch — not just individual file changes.

1. Synthesize the full branch scope from the diff, commits, and file changes. Understand the totality: features, fixes, cleanups, refactors — everything that happened on this branch.
2. Determine scope: map file paths to Shopware areas (Core, Storefront, Administration, App System, etc.). This informs the conventional commit scope for the title.
3. Identify the narrative candidates. A branch often contains multiple threads — a feature plus cleanup plus a fix discovered along the way. Present these to the user:
   > "This branch contains: (a) a new endpoint for X, (b) a fix for null handling in Y, (c) cleanup of unused imports. **What's the primary story?**"
4. The user confirms or reframes the story. This drives the title's type/scope and which aspects get depth vs. a brief mention.
5. Assess description depth based on the confirmed story:
   - Bug fix → root cause analysis in Why, reproduction steps important
   - New feature → usage context in What, scope boundaries valuable
   - Breaking change → migration guidance needed
   - Performance → quantified improvement expected
6. Leverage session context: if the user has been debugging, implementing, or discussing in the current session, use that knowledge. Don't re-ask what's already known.

## Phase 3 — Gather Context

Fill the gaps — ask targeted questions only for information not in the diff or session context.

1. Inventory what's known from the diff and session:
   - Why the change was made (motivation)
   - What changed (from diff)
   - How to reproduce the issue/behavior
   - Related issues or PRs
   - Breaking changes or deprecations
2. Ask only what's missing, one question at a time:
   - "What triggered this change? Bug report, user complaint, or internal decision?"
   - "Is there a GitHub issue for this?"
   - "How would someone reproduce the original problem?"
   - "Is this behind a feature flag?"
   - "Are there downstream PRs or related changes in other repos?"
   - "Should reviewers know about any deliberate trade-offs or limitations?"
3. Skip questions the session already answers. If the user just spent time debugging and the session contains root cause, reproduction, and fix rationale — go straight to drafting.
4. Load `references/writing-rules.md` to internalize style constraints and anti-slop rules.

## Phase 4 — Draft

Generate the conventional commit title and full PR description.

1. Load `references/pr-description-examples.md` for sizing calibration
2. Load `references/template-structure.md` for output format
3. Generate the title: `<type>(<scope>): <description>` — type from the confirmed story, scope from file path analysis, description short and imperative
4. Draft description sections 1-4 following the template structure and writing rules
5. Calibrate total density for sections 1-3 combined based on explanation complexity:
   - **Small (< 20 lines):** Self-explanatory from title + a few sentences. Simple constraints, obvious fixes, straightforward config.
   - **Medium (20-50 lines):** Needs context not obvious from the diff. Non-trivial root causes, behavioral changes with reproduction, features needing usage explanation. Most PRs land here.
   - **Large (50+ lines):** Complete new feature with new integration points — the kind of change that justifies a presentation. New API surfaces, new subsystems, architectural decisions.
   - Determine the tier from the story, not the diff size. A 2-line fix requiring trace through three code paths is medium, not small.
6. Add enhancements where they genuinely help reviewers (see template-structure.md for rules)
7. Present the full draft to the user: title clearly labeled, then all description sections formatted as GitHub markdown

## Phase 5 — Present

Deliver the formatted output.

1. Output the title — clearly labeled, in conventional commit format
2. Output the description — full template with all sections as GitHub-rendered markdown (not commit message format: no hard line wraps, let lines run to natural length)
3. Flag any assumptions: inferred reproduction steps, guessed issue numbers, trade-off decisions the user should verify
4. If the user wants changes, revise and present again
5. Do not create PRs, update PRs, or write to any files. The user takes the output and uses it as they see fit.

## Boundaries

- Never create or update PRs on GitHub
- Never write to any files
- Never auto-commit
- Only present formatted text output for the user to use
- Works on feature branches only — not on `trunk`
