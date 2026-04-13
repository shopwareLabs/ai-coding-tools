---
name: commit-message-writing
version: 1.6.4
model: sonnet
description: >-
  Generate conventional commit messages for the Shopware core repository.
  Two modes: squash merge titles (title-only) for trunk merges, and full commit
  messages (title + body) for branch commits. Analyzes diffs, infers scope from
  Shopware's directory structure, and detects breaking changes.
  Use when the user explicitly asks to generate, write, or create a commit message,
  squash commit, commit title, or merge commit message.
  Do not activate during implementation work or when the user is writing code.
allowed-tools: Read, Grep, Glob, Bash, AskUserQuestion, mcp__plugin_gh-tooling_gh-tooling
---

# Commit Message Generation

Generate conventional commit messages for Shopware core. Squash merge titles (title-only) for trunk merges and full commit messages (title + body) for branch work.

**Output scope:** Presents formatted commit message text. Does not create commits, write files, or modify git state.

## Phase 1 — Detect Mode and Gather Context

Determine what we're generating — a squash merge title or a branch commit message.

1. Parse user input:
   - **Commit ref provided** (SHA, HEAD, HEAD~3, etc.) -> **branch mode**, resolve to SHA
   - **Branch ref, "squash", "current branch", or "merge commit"** -> **squash mode**
   - **Nothing specific** -> **branch mode**, use HEAD
2. Gather the diff:
   - **Branch mode:** `git show <sha> --name-status --format=''` and `git show <sha> --format=''`
   - **Squash mode:** Continue to step 3
3. **Squash mode only — detect base branch:** Load `references/branch-and-pr-detection.md` and execute Steps 1-4. Route as `commit-message-writing`.
4. **Squash mode only — get branch diff:**
   - `git diff <base>...HEAD --stat` and `git diff <base>...HEAD`
   - `git log <base>..HEAD --oneline`

## Phase 2 — Analyze and Generate

### Type Detection

Analyze the diff to determine the commit type. Priority-ordered decision tree:

1. Revert commit? -> `revert`
2. Only docs (*.md, docblocks, inline comments)? -> `docs`
3. Only formatting/whitespace changes? -> `style`
4. Only test files? -> `test`
5. Only build/dependency files (composer.json, package.json, Dockerfile)? -> `build`
6. Only CI config (.github/workflows/, .gitlab-ci.yml)? -> `ci`
7. Adds new user-facing functionality? -> `feat`
8. Fixes broken behavior? -> `fix`
9. Performance improvement (caching, query optimization, reduced allocations)? -> `perf`
10. Code restructuring without behavior change? -> `refactor`
11. Otherwise -> `chore`

When ambiguous (e.g., both `feat` and `fix` equally present), ask the user:

```
AskUserQuestion(
  question="This branch contains both new functionality and bug fixes. Which type best represents the primary purpose?",
  options=[
    {label: "feat", description: "The main goal is new functionality"},
    {label: "fix", description: "The main goal is correcting broken behavior"}
  ]
)
```

### Scope Detection

Delegate to references/scope-inference.md. Pass the list of changed file paths and the base branch (for commit history lookup in squash mode) or `HEAD~20` (for branch mode).

### Breaking Change Detection

Scan the diff for breaking changes:
- API signature changes (required parameters added, removed, or reordered)
- Public methods or classes removed or renamed
- Return types changed on public methods
- Database schema breaking changes (column removal, type change)
- Default behavior changed in ways that affect existing callers

If detected, add the `!` marker after scope in the output.

### Subject

Craft the subject line. Apply references/writing-rules.md.

- Imperative mood, lowercase, no period, max 72 characters total
- Informed by the diff (truth) and commit messages (intent context, squash mode only)
- Specific: name the component and behavior, not abstract descriptions
- No PR number (GitHub adds it during squash merge)
- No AI/tool attribution

### Body (Branch Mode Only)

Craft the body. Apply references/writing-rules.md.

- WHY-not-WHAT: explain motivation, root cause, trade-offs
- Blank line between subject and body
- Single continuous lines per paragraph (no hard-wrapping)
- Concrete: class names, config keys, method signatures
- If breaking: include `BREAKING CHANGE:` footer with brief description

## Phase 3 — Validate and Present

Before presenting, validate the generated message against references/writing-rules.md:

1. **Em dash check:** Literally search the generated text for `—` and `–`. Replace any found.
2. **Banned vocabulary:** Scan for words from the banned list. Replace with plain alternatives.
3. **Subject rules:** Verify imperative mood, lowercase, no period, within 72 characters, no attribution.
4. **Body rules (branch mode):** Verify WHY-not-WHAT, no diff restatement, concrete specifics.

**Squash mode:**
```
type(scope): subject
```

**Branch mode:**
```
type(scope): subject

Body explaining why this change was made.
```

Or with breaking change:
```
type(scope)!: subject

Body explaining why this change was made.

BREAKING CHANGE: brief description of what breaks.
```

After the message, show brief reasoning (one line each):
- **Type:** `feat` — adds new maxLength parameter to attribute entity fields
- **Scope:** `dal` — all changes within DataAbstractionLayer, matches trunk history

Done. No file writes, no git operations beyond read-only commands.
