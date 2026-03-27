---
name: release-info-writing
version: 1.0.1
model: sonnet
description: >-
  Draft entries for RELEASE_INFO and UPGRADE files in the Shopware core repository.
  Analyzes the full branch diff against trunk, synthesizes the narrative of the changes,
  and writes entries calibrated to the magnitude of change.
  Use when completing features, deprecations, or breaking changes that affect external developers,
  or when the user mentions writing release info, upgrade entries, release notes, release documentation,
  or changelog entries. Do not activate mid-implementation or for internal refactoring, non-critical bug
  fixes, or test-only changes.
allowed-tools: Read, Grep, Glob, Bash, Edit, AskUserQuestion, mcp__plugin_gh-tooling_gh-tooling__pr_view, mcp__plugin_gh-tooling_gh-tooling__pr_diff, mcp__plugin_gh-tooling_gh-tooling__pr_files, mcp__plugin_gh-tooling_gh-tooling__pr_commits, mcp__plugin_gh-tooling_gh-tooling__pr_comments, mcp__plugin_gh-tooling_gh-tooling__pr_checks, mcp__plugin_gh-tooling_gh-tooling__pr_list, mcp__plugin_gh-tooling_gh-tooling__pr_reviews, mcp__plugin_gh-tooling_gh-tooling__commit_pulls, mcp__plugin_gh-tooling_gh-tooling__issue_view, mcp__plugin_gh-tooling_gh-tooling__issue_list, mcp__plugin_gh-tooling_gh-tooling__search, mcp__plugin_gh-tooling_gh-tooling__search_code
---

# Release Info Drafting

Draft entries for `RELEASE_INFO-6.x.md` and `UPGRADE-6.x.md` in the Shopware core repository. The skill auto-generates the mechanical "what changed" from code analysis but requires human input for "why external developers should care."

**File write scope:** Edit only `RELEASE_INFO-6.*.md` and `UPGRADE-6.*.md`. Read everything else.

## Phase 1 — Detect Target Files

Parse `.danger.php` in the repo root to get the canonical file names CI enforces.

1. Read `.danger.php`
2. Look for lines matching `matches('RELEASE_INFO-` — extract the file name from the string argument (e.g., `RELEASE_INFO-6.7.md`)
3. Look for lines matching `matches('UPGRADE-` or referencing `UPGRADE-` in failure messages — extract the file name (e.g., `UPGRADE-6.8.md`)
4. **Fallback:** If parsing fails, glob for `RELEASE_INFO-6.*.md` and `UPGRADE-6.*.md` in the repo root. Pick the file with the highest version number.
5. **Last resort:** Ask the user for the file names.

Verify both files exist before proceeding.

## Phase 2 — Analyze Branch Scope

Understand the full story of the branch, not just individual changes.

1. Get the full diff against `trunk`:
   - If a PR exists, use `mcp__plugin_gh-tooling_gh-tooling__pr_diff` and `mcp__plugin_gh-tooling_gh-tooling__pr_files`
   - Otherwise, run `git diff trunk...HEAD --stat` and `git log trunk..HEAD --oneline`
2. Use session context — what the user has been working on and why
3. Synthesize the **narrative**: a PR may touch features, fixes, and cleanups. Identify what's most important — what's the story of these changes?
4. Classify using the decision tree below
5. If the changes are not externally relevant: tell the user with reasoning, offer to proceed anyway

### Classification Decision Tree

**Step 1 — Is this externally relevant?**

Skip if ALL are true:
- No public API changes (no new/changed/removed public methods, interfaces, routes)
- No behavioral changes visible to extensions or integrations
- No new features, extension points, or config options
- No deprecation annotations added
- Only test files, internal refactoring, or non-critical bug fixes

**Step 2 — Which files need entries?**

| Signal in diff | RELEASE_INFO | UPGRADE |
|---|---|---|
| New public feature / extension point | Yes | No |
| New/changed config option | Yes | No |
| Deprecation added (`@deprecated`) | Yes | Yes (next major) |
| Method/class removed | No | Yes |
| Method signature changed (breaking) | Possibly | Yes |
| Behavioral change (non-breaking but notable) | Yes | No |
| Behavioral change (breaking) | Yes | Yes |
| Critical bug fix | Yes | No |
| New API endpoint | Yes | No |
| API endpoint removed/changed | Yes | Yes |

**Step 3 — Present classification to user:**

> "Based on the branch changes, this looks like **[classification]**. I'd suggest entries in **[file(s)]**. Does that match your intent?"

The user can override — they know the story better than the diff.

## Phase 3 — Gather Context

1. After the user confirms the classification, ask targeted questions the skill cannot infer from code. Ask only what's needed — skip questions the session context already answers:
   - "Why should external developers care about this change?"
   - "Are there migration steps needed?" (only if UPGRADE entry required)
   - "Is this behind a feature flag?"
2. Load `references/writing-rules.md` for style guidance
3. Read 2-3 existing entries from the target category in the target file for voice and density calibration

## Phase 4 — Draft Entries

1. Load `references/entry-examples.md` for sizing calibration
2. Load `references/file-structure.md` for heading hierarchy and placement rules
3. Scan **all** categories in the entire target file (not just the upcoming section) to discover the full category set
4. Propose a category based on file paths changed. Present the full category list and let the user confirm or pick a different one.
5. Draft the entry/entries:
   - Size to the magnitude of change (see entry-examples.md for tiers)
   - Follow the writing rules (see writing-rules.md)
   - Match the voice and density of recent entries in the same file
6. Present the draft(s) to the user for review. Show each entry clearly with its target file and category.

## Phase 5 — Write

1. On user approval, use `Edit` to insert the entry under the correct heading in the correct file
2. Place as the last entry in the target category section
3. If both RELEASE_INFO and UPGRADE need entries, write both
4. After writing, show the diff so the user can verify placement

**Do not commit.** The user decides when to commit.

## Boundaries

- Never touch `changelog/_unreleased/` — warn the user if files exist there (old format rejected by CI)
- Never create new version headings — write into existing sections only
- Never auto-commit or create PRs
- Only operates in repositories that contain `RELEASE_INFO-6.*.md` files
