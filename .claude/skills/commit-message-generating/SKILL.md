---
name: commit-message-generating
description: Generate conventional commit messages for the Shopware AI Coding Tools marketplace. Determines type, infers scope from plugin directory structure, and detects breaking changes. Use when generating commit messages in this repository.
allowed-tools: Read, Bash, AskUserQuestion
---

# Commit Message Generating

Generate conventional commit messages for the Shopware AI Coding Tools marketplace repository.

## Requirements

- Working directory is this repository
- **Staged mode**: staged or unstaged changes for a single commit message
- **Squash mode**: a branch with commits diverged from `main`
- **Rewrite mode**: a commit hash provided as argument to rewrite its message

## Mode Detection

- **Rewrite mode**: argument is a commit hash (full or abbreviated SHA)
- **Squash mode**: user mentions "squash", "branch", "PR", or asks for a commit message summarizing a branch
- **Staged mode** (default): all other cases

## Project Rules

**Types** (all allowed): feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert

**Scopes** — two categories:
1. **Plugin scopes**: directory names under `plugins/` (run `ls plugins/` to get current list)
2. **Infrastructure scopes**: `hooks`, `marketplace`, `ci`, `github`

**Scope omission** — omit scope when:
- Type is `docs` with project-wide files (README.md, CONTRIBUTING.md, AGENTS.md)
- Type is `ci` with only CI config changes
- Root-level config files (.gitignore, LICENSE, pyproject.toml)
- Cross-cutting changes spanning 3+ unrelated plugins

**Subject**: imperative mood, lowercase, no period, max 72 chars.

**Body**: optional for most commits. Required for breaking changes (must include migration instructions).

**Attribution footer**: always enabled.

**No ticket format required.**

---

## Staged Workflow

### Step 1: Gather Changes

1. Run `ls plugins/` to get current plugin names (= valid scopes)
2. Run `git diff --cached --name-status` for staged changes
3. If nothing staged, run `git diff --name-status` for unstaged changes
4. Run `git diff --cached` (or `git diff`) for the full diff

### Step 2: Determine Type

Apply in priority order — see [Type Detection](references/type-detection.md) for decision tree.

- HIGH/MEDIUM confidence: use type directly
- LOW confidence: use AskUserQuestion with options from analysis
- Detect breaking change indicators

### Step 3: Infer Scope

Infer scope from changed file paths — see [Scope Detection](references/scope-detection.md) for rules.

- All files under `plugins/<name>/`: scope = `<name>`
- All files under `.github/`: scope = `ci` (unless workflow is plugin-specific)
- All files under `hooks/` or plugin hook dirs: scope = `hooks`
- Files in `.claude-plugin/marketplace.json` or marketplace structure: scope = `marketplace`
- Files in `.github/` relating to GitHub features (templates, etc.): scope = `github`
- Mixed across 2 related plugins: use the primary one, or ask user
- Mixed across 3+ unrelated areas: omit scope

Confidence handling:
- HIGH/MEDIUM: use scope directly
- LOW: use AskUserQuestion

### Step 4: Craft Subject and Message

**Subject rules**: imperative mood, lowercase, no period, max 72 chars, specific description.

**Body rules**: do not hard-wrap body lines at 72 characters. Write each paragraph as a single continuous line. The 72-char limit applies only to the subject.

**Writing quality**: Read `plugins/contributor-writing/references/writing-rules-anti-ai-slop.md` and apply all rules to the subject and body.

**Message format**:
```
type(scope): subject

body (if breaking change or complex multi-file change)

BREAKING CHANGE: description (if breaking)

Co-Authored-By: Claude <model-name> <noreply@anthropic.com>
```

Use your actual model name (e.g., "Opus 4.6 (1M context)", "Sonnet 4.6") for `<model-name>`.

Do NOT include PR references like `(#N)` — GitHub adds these during merge.

### Step 5: Anti-Slop Validation

Re-read `plugins/contributor-writing/references/writing-rules-anti-ai-slop.md`, then check the draft message literally (not from memory):

1. Check each body paragraph for hard-wrapping. If any paragraph spans multiple lines, join it into a single continuous line. The 72-char limit applies only to the subject, never to body lines.
2. Search the subject and body for em dash (—) and en dash (–) characters. Remove every instance. This is the most common violation and must be checked first as a literal character search, not a mental scan.
3. Re-read each word against the banned vocabulary list. Replace any match with the plain alternative or delete.
4. Check for banned sentence patterns, colon/semicolon overuse, hedging filler.
5. If any violations found, rewrite the affected text and re-check the rewritten text.

### Step 6: Present

Quick self-check: type matches changes, scope matches files, subject is accurate.

**Output**: brief analysis (type reasoning, scope reasoning, breaking changes), then the commit message in a code block.

---

## Squash Workflow

Generate a single commit message summarizing an entire branch, for use with squash merge.

### Step 1: Gather Branch Changes

1. Run `ls plugins/` to get current plugin names (= valid scopes)
2. Determine the base branch: `main` unless user specifies otherwise
3. Get the combined diff: `git diff main...HEAD --name-status` and `git diff main...HEAD`
4. Get individual commit subjects for context: `git log main..HEAD --oneline`
5. If uncommitted changes exist, note them but focus on committed branch content

### Step 2: Determine Type

Analyze the combined diff across all commits. The squash type reflects the overall branch intent, not individual commits.

- If all commits share one type, use that type
- If the branch adds a new feature with supporting fixes/refactors, type = `feat`
- If the branch fixes a bug with supporting refactors/tests, type = `fix`
- Apply the [Type Detection](references/type-detection.md) decision tree to the combined diff
- LOW confidence: use AskUserQuestion

### Step 3: Infer Scope

Same rules as staged mode. Apply [Scope Detection](references/scope-detection.md) to the combined file list from `git diff main...HEAD --name-status`.

### Step 4: Craft Subject and Message

**Subject**: summarize the branch's purpose in one line. Don't list individual commits.

**Writing quality**: Read `plugins/contributor-writing/references/writing-rules-anti-ai-slop.md` and apply all rules.

**Body**: for multi-commit branches, include a body that describes the key changes without restating each commit. Group by logical concern, not by commit order.

**Message format**: same as staged mode.

### Step 5: Anti-Slop Validation

Same gate as staged mode.

### Step 6: Present

Same output as staged mode.

---

## Rewrite Workflow

Generate a proper commit message for an existing commit, identified by its hash.

### Step 1: Gather Commit Changes

1. Run `ls plugins/` to get current plugin names (= valid scopes)
2. Validate the hash: `git cat-file -t <hash>` must return `commit`
3. Get the commit's diff: `git diff <hash>^..<hash> --name-status` and `git diff <hash>^..<hash>`
4. Get the current commit message for reference: `git log -1 --format=%B <hash>`

### Step 2: Determine Type

Apply the [Type Detection](references/type-detection.md) decision tree to the commit's diff. Ignore the existing commit message for type determination — base it purely on the changes.

### Step 3: Infer Scope

Same rules as staged mode. Apply [Scope Detection](references/scope-detection.md) to the file list from `git diff <hash>^..<hash> --name-status`.

### Step 4: Craft Subject and Message

Same rules as staged mode.

### Step 5: Anti-Slop Validation

Same gate as staged mode.

### Step 6: Present

Same output as staged mode.

---

## Clipboard Offer

After presenting a commit message in any mode, ask the user whether to copy it to the clipboard. If they accept, copy the message (without the surrounding code block markers) using `pbcopy` on macOS or `xclip -selection clipboard` on Linux.

---

## Git Commands

```bash
# Current plugin scopes
ls plugins/

# Staged changes
git diff --cached --name-status
git diff --cached

# Unstaged changes
git diff --name-status
git diff

# Branch changes (squash mode)
git diff main...HEAD --name-status
git diff main...HEAD
git log main..HEAD --oneline

# Existing commit (rewrite mode)
git cat-file -t <hash>
git diff <hash>^..<hash> --name-status
git diff <hash>^..<hash>
git log -1 --format=%B <hash>
```

## Error Handling

- No staged/unstaged changes (staged mode): inform user, suggest staging files first
- No commits ahead of main (squash mode): inform user the branch has no diverged commits
- Invalid commit hash (rewrite mode): inform user the hash does not resolve to a commit
