---
name: feature-branch-pr-writing
version: 1.4.3
model: sonnet
description: >-
  Draft PR titles (conventional commit format) and descriptions (narrative prose with topical
  subsections) for Shopware core PRs targeting non-trunk feature branches. Analyzes the diff
  against the target branch, detects related PRs in the chain, and asks targeted questions.
  Use when the user asks to write a PR description AND the PR targets a non-trunk branch.
  Requires an existing PR or branch targeting a feature branch (not trunk).
  Do not activate for trunk-targeting PRs — use pr-description-writing instead.
  Do not activate mid-implementation — only when the user is ready to describe their changes.
allowed-tools: Read, Grep, Glob, Bash, AskUserQuestion, mcp__plugin_gh-tooling_gh-tooling__pr_view, mcp__plugin_gh-tooling_gh-tooling__pr_diff, mcp__plugin_gh-tooling_gh-tooling__pr_files, mcp__plugin_gh-tooling_gh-tooling__pr_commits, mcp__plugin_gh-tooling_gh-tooling__pr_comments, mcp__plugin_gh-tooling_gh-tooling__pr_checks, mcp__plugin_gh-tooling_gh-tooling__pr_list, mcp__plugin_gh-tooling_gh-tooling__pr_reviews, mcp__plugin_gh-tooling_gh-tooling__commit_pulls, mcp__plugin_gh-tooling_gh-tooling__issue_view, mcp__plugin_gh-tooling_gh-tooling__issue_list, mcp__plugin_gh-tooling_gh-tooling__search, mcp__plugin_gh-tooling_gh-tooling__search_code
---

# Feature-Branch PR Description Drafting

Draft a PR title (conventional commit format) and description (narrative prose with topical subsections) for PRs targeting non-trunk feature branches. Analyzes the diff against the target branch, detects related PRs in the chain, and asks targeted questions for missing context.

**Output scope:** Presents formatted title + description text. Does not create or update PRs on GitHub. Does not write to any files.

## Phase 1 — Assess Branch State

Determine what we're working with: branch, target, PR status, diff, and chain.

1. Get the current branch: `git branch --show-current`
2. If on `trunk`, stop: "This skill works on feature branches. Switch to a feature branch first."
3. Check for an existing PR:
   - If the user provided a PR number or URL, use `pr_view` to read it
   - Otherwise, use `pr_list` filtered to the current branch
   - If a PR exists, read its current title and description
4. Identify the PR's target branch from PR data. If the target is `trunk`, stop: "This PR targets `trunk`. Use the `pr-description-writing` skill for trunk-targeting PRs."
5. Get the diff:
   - If a PR exists: use `pr_diff` and `pr_files`
   - If no PR: run `git diff <target>...HEAD --stat` and `git log <target>..HEAD --oneline`
6. Chain detection: use `pr_list` filtered to PRs targeting the same feature branch. Record titles, numbers, merge state, and any cross-references in bodies. Identify predecessor/successor relationships.
7. Present a brief assessment to the user: branch name, target branch, PR status (exists / doesn't exist / has existing description), change magnitude (files touched, lines changed, areas affected), related PRs in the chain.

## Phase 2 — Analyze Changes

Understand the full story of the branch relative to the target.

1. Synthesize the full branch scope from the diff, commits, and file changes. Understand the totality: features, fixes, cleanups, refactors.
2. Determine scope: map file paths to Shopware areas. This informs the conventional commit scope for the title.

| File path pattern | Scope |
|---|---|
| `src/Core/Checkout/Cart/` | `cart` |
| `src/Core/Checkout/Order/` | `order` |
| `src/Core/Checkout/Promotion/` | `promotion` |
| `src/Core/Content/Product/` | `product` |
| `src/Core/Content/Media/` | `media` |
| `src/Core/Content/Category/` | `category` |
| `src/Core/Content/Cms/` | `cms` |
| `src/Core/Content/Mail/` | `mail` |
| `src/Core/Framework/DataAbstractionLayer/` | `dal` |
| `src/Core/Framework/App/` | `app-system` |
| `src/Core/System/SystemConfig/` | `system-config` |
| `src/Core/System/NumberRange/` | `number-range` |
| `src/Storefront/` | `storefront` |
| `src/Administration/` | `admin` |
| `src/Elasticsearch/` | `elasticsearch` |

For changes spanning multiple areas, use the scope of the primary story. If no specific scope fits, omit the parenthetical scope entirely: `fix: description`.

3. Identify narrative candidates. A branch often contains multiple threads. Present them to the user:
   > "This branch contains: (a) ..., (b) .... **What's the primary story?**"
4. The user confirms or reframes the story. This drives the title's type/scope and which aspects get depth vs. a brief mention.
5. Assess description depth based on the confirmed story's complexity.
6. Leverage session context: if the user has been debugging, implementing, or discussing in the current session, use that knowledge. Don't re-ask what's already known.

## Phase 3 — Gather Context

Fill the gaps. Ask targeted questions only for information not in the diff, chain detection, or session context.

1. Inventory what's known from the diff, chain, and session:
   - Why the change was made (motivation)
   - What changed (from diff)
   - Which prior PRs established the pattern
   - Related PRs (blocked by, follows, follow-up)
   - Design alternatives considered
   - Trade-offs or limitations
   - Tracking issue
2. Ask only what's missing, one question at a time:
   - "What triggered this change?"
   - "Which prior PR established the pattern being followed?"
   - "Are there PRs blocked by this one?"
   - "Were there design alternatives you considered and rejected?"
   - "Should reviewers know about any deliberate trade-offs or limitations?"
   - "Is there a tracking issue for this feature?"
3. Skip questions the session already answers. If the user has been working on this and the session contains motivation, design decisions, and chain context, go straight to drafting.
4. Load `references/writing-rules.md` to internalize style constraints and anti-slop rules.

## Phase 4 — Draft

Generate the conventional commit title and narrative description.

1. Load `references/description-examples.md` for sizing calibration
2. Generate the title: `<type>(<scope>): <description>`

| Type | When to use |
|---|---|
| `fix` | Bug fix |
| `feat` | New feature or capability |
| `refactor` | Code restructuring with no behavioral change |
| `perf` | Performance improvement |
| `chore` | Maintenance, dependency updates, tooling |
| `docs` | Documentation only |
| `test` | Test additions or corrections |
| `style` | Code style (formatting, semicolons, etc.) |

Title description rules: imperative mood, lowercase first letter, no period, under ~60 characters after type/scope. Describe the behavioral change, not the implementation.

3. Draft the description:
   - **Opening context paragraph:** state the prior situation, what this PR does about it, and reference predecessor PRs in the chain when applicable.
   - **Topical `###` subsections:** each covers one concern or aspect of the change. Choose headers based on what the PR actually does, not from a fixed list. Good: "Event-based type override", "DI decentralization". Bad: "Changes", "What changed", "Updates".
   - **Tables** for structured mappings (file moves, new classes with locations, config key changes, loader-to-route delegations).
   - **`## References` section** at the end with cross-references: `Ref #issue`, `Blocked by #PR`, `Follows #PR`, `Follow-up: #PR`. Never use `closes` or `fixes`.
4. Self-check each subsection: state in one sentence what contract it describes (what goes in, what comes out, why it exists). If you can't collapse the subsection to one contract-level sentence, it's restating the diff. Rewrite.
5. Diagram reasoning (two steps):
   - Would the reviewer understand this better by seeing it than reading about it? If no, skip.
   - If yes: can it fit one focused diagram, or should it split by concern? A single diagram that tries to show everything is as hard to follow as the prose it replaced.
6. Scale length to complexity:
   - **Small** (~2 paragraphs, 2 subsections): single-concern refactors, review feedback fixes.
   - **Medium** (~3 paragraphs, 3-4 subsections, tables): multi-file features following established patterns, structural moves.
   - **Large** (~6+ paragraphs, 6+ subsections, tables, potentially diagrams): new subsystems with multiple integration points.
   - Determine the tier from the story's complexity, not the diff size.
7. Present the full draft to the user: title clearly labeled, then the description formatted as GitHub markdown

## Phase 5 — Validate and Present

Verify the draft against anti-slop rules, then deliver.

1. **Anti-slop validation pass** — load `references/writing-rules.md`, then check the draft literally (not from memory):
   - First: search the draft text for em dash (—) and en dash (–) characters. Remove every instance. This is the most common violation and must be checked first as a literal character search, not a mental scan.
   - Second: for each subsection, verify it states a contract, not implementation steps. If a paragraph walks through method internals a reviewer will see in the diff, compress to contract level.
   - Then re-read each sentence against: banned vocabulary, banned sentence patterns, banned formats, colon/semicolon overuse, sentence rhythm, tone
   - If any violations found, rewrite the affected sentences and re-check the rewritten sentences
2. Output the title — clearly labeled, in conventional commit format
3. Output the description — as GitHub-rendered markdown (no hard line wraps, let lines run to natural length)
4. Flag any assumptions: inferred chain relationships, guessed issue numbers, trade-off decisions the user should verify
5. If the user wants changes, revise and present again
6. Do not create PRs, update PRs, or write to any files. The user takes the output and uses it as they see fit.

## Boundaries

- Never create or update PRs on GitHub
- Never write to any files
- Never auto-commit
- Only present formatted text output for the user to use
- Works on feature branches targeting non-trunk branches only
