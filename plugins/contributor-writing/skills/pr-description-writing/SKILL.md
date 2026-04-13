---
name: pr-description-writing
version: 1.6.4
model: sonnet
description: >-
  Draft PR titles (conventional commit format) and descriptions (Shopware's 5-section template)
  for Shopware core PRs targeting trunk. Analyzes the full branch scope against trunk, leverages
  session context, and asks targeted questions for missing information.
  Use when the user asks to write, draft, create, or improve a PR description, is about to create
  a PR, or mentions "PR description", "pull request description", or "PR template".
  Do not activate for PRs targeting non-trunk branches — use feature-branch-pr-writing instead.
  Do not activate mid-implementation — only when the user is ready to describe their changes.
allowed-tools: Read, Grep, Glob, Bash, AskUserQuestion, mcp__plugin_gh-tooling_gh-tooling
---

# PR Description Drafting

Draft a PR title (conventional commit format) and description (Shopware's 5-section template) by analyzing the full branch scope, leveraging session context, and asking targeted questions for missing context.

**Output scope:** Presents formatted title + description text. Does not create or update PRs on GitHub. Does not write to any files.

## Phase 1 — Assess Branch State

Determine what we're working with — branch, PR status, and diff.

1. Load `references/branch-and-pr-detection.md` and execute Steps 1-4. Route as `pr-description-writing`.
2. Get the diff:
   - If a PR exists: use `pr_diff` and `pr_files`
   - If no PR: run `git diff trunk...HEAD --stat` and `git log trunk..HEAD --oneline`
3. Present a brief assessment to the user: branch name, PR status (exists / doesn't exist / has existing description), change magnitude (files touched, lines changed, areas affected)

## Phase 2 — Analyze Changes

Understand the full story of the branch — not just individual file changes.

1. Synthesize the full branch scope from the diff, commits, and file changes. Understand the totality: features, fixes, cleanups, refactors — everything that happened on this branch.
2. Determine scope: map file paths to Shopware areas (Core, Storefront, Administration, App System, etc.). This informs the conventional commit scope for the title.
3. Identify the narrative candidates. A branch often contains multiple threads — a feature plus cleanup plus a fix discovered along the way. Present these to the user:
   > "This branch contains: (a) a new endpoint for X, (b) a fix for null handling in Y, (c) cleanup of unused imports. **What's the primary story?**"
4. The user confirms or reframes the story. This drives the title's type/scope and which aspects get depth vs. a brief mention. If secondary threads remain (cleanup, test improvements, incidental fixes), offer them as an "Additional Changes" section: "The test cleanup / refactor / fix isn't part of the main story. Want it mentioned in an Additional Changes section at the end?" Only offer when the secondary work has educational value (practices not widely known in the project) or touches files a reviewer might otherwise question.
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
5. Self-check each section: state in one sentence what contract it describes (what goes in, what comes out, why it exists). If you can't collapse the section to one contract-level sentence, it's restating the diff. Rewrite.
6. Calibrate total density for sections 1-3 combined based on explanation complexity:
   - **Small (< 20 lines):** Self-explanatory from title + a few sentences. Simple constraints, obvious fixes, straightforward config.
   - **Medium (20-50 lines):** Needs context not obvious from the diff. Non-trivial root causes, behavioral changes with reproduction, features needing usage explanation. Most PRs land here.
   - **Large (50+ lines):** Complete new feature with new integration points — the kind of change that justifies a presentation. New API surfaces, new subsystems, architectural decisions.
   - Determine the tier from the story, not the diff size. A 2-line fix requiring trace through three code paths is medium, not small.
7. Add enhancements where they genuinely help reviewers (see template-structure.md for rules)
8. If the user opted in during Phase 2, draft an "Additional Changes" section after section 4 (see template-structure.md for format)
9. Present the full draft to the user: title clearly labeled, then all description sections formatted as GitHub markdown

## Phase 5 — Validate and Present

Verify the draft against anti-slop rules, then deliver.

1. **Anti-slop validation pass** — load `references/writing-rules.md`, then check the draft literally (not from memory):
   - First: search the draft text for em dash (—) and en dash (–) characters. Remove every instance. This is the most common violation and must be checked first as a literal character search, not a mental scan.
   - Second: for each section, verify it states a contract, not implementation steps. If a paragraph walks through method internals a reviewer will see in the diff, compress to contract level.
   - Then re-read each sentence against: banned vocabulary, banned sentence patterns, banned formats, colon/semicolon overuse, sentence rhythm, tone
   - If any violations found, rewrite the affected sentences and re-check the rewritten sentences
2. Output the title — clearly labeled, in conventional commit format
3. Output the description — full template with all sections as GitHub-rendered markdown (not commit message format: no hard line wraps, let lines run to natural length)
4. Flag any assumptions: inferred reproduction steps, guessed issue numbers, trade-off decisions the user should verify
5. If the user wants changes, revise and present again
6. Do not create PRs, update PRs, or write to any files. The user takes the output and uses it as they see fit.

## Boundaries

- Never create or update PRs on GitHub
- Never write to any files
- Never auto-commit
- Only present formatted text output for the user to use
- Works on feature branches only — not on `trunk`
