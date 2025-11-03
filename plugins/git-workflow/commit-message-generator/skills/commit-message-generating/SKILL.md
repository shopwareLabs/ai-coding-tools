---
name: commit-message-generating
description: Generate and validate conventional commit messages. Automatically determines commit type (feat/fix/refactor/etc.), infers scope from file paths, detects breaking changes, and validates commit messages match actual code changes. Includes cross-platform clipboard integration. Supports custom rules via .commitmsgrc.md. Use when writing or validating commit messages, or when the user mentions commits, git messages, or conventional commits.
allowed-tools: Read, Bash, AskUserQuestion
---

# Commit Message Generating Skill

## Table of Contents

- [Requirements](#requirements)
- [Overview](#overview)
- [Mode Detection](#mode-detection)
- [Configuration](#configuration)
- [Core Principles](#core-principles)
- [Generation Workflow](#generation-workflow)
- [Validation Workflow](#validation-workflow)
- [Utility Scripts](#utility-scripts)
- [Progressive Disclosure References](#progressive-disclosure-references)
- [Error Handling](#error-handling)
- [Output Guidelines](#output-guidelines)

## Requirements

- Git repository with working directory access
- Staged changes (for generation) or commit history (for validation)
- Optional: `.commitmsgrc.md` configuration file in project root for custom rules

## Overview

Generates and validates conventional commit messages following the Conventional Commits specification. Analyzes code changes to determine commit type, infers scope from file paths, detects breaking changes, and crafts precise commit messages with self-validation.

## Mode Detection

Automatically detect operating mode and data source:

**Mode:**
- **Generation**: "generate", "create", "write" commit message or `/commit-gen` command
- **Validation**: "validate", "check", "verify" commit message or `/commit-check` command

**Data Source (for Generation mode only):**
- **Staged changes**: No commit reference provided (default)
- **Existing commit**: Commit reference provided (HEAD, sha1, branch name, etc.)

If ambiguous, ask user for clarification.

## Configuration

**Load project config:** Check for `.commitmsgrc.md` in project root using `Read` tool:
```bash
Read .commitmsgrc.md
```

Extract YAML frontmatter for custom rules:
- `types`, `scopes`, `required_ticket_format`, `max_subject_length`, `breaking_change_marker`

**Defaults if missing:**
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Scopes: Optional, inferred from file paths
- Subject length: 72 chars max
- Breaking changes: Mark with **!**

See `references/custom-rules.md` and `commitmsgrc-template.md` for configuration details.

## Core Principles

1. **Semantic accuracy over format** - Message must accurately describe changes
2. **Progressive disclosure** - Load references only when needed
3. **Validation loop** - Validate generated messages before presenting

## Generation Workflow

Execute these steps with integrated validation:

### Step 0: Detect Data Source

**Actions:**
- [ ] Check if commit reference was provided (from slash command $ARGUMENTS or user request)
- [ ] If commit reference provided:
  - [ ] Validate using: git rev-parse --verify "$commit_ref"
  - [ ] Set data_source = "commit"
  - [ ] Store commit_ref for Step 1
- [ ] If no reference provided:
  - [ ] Set data_source = "staged" (default)

**Error Handling:**
- Invalid commit ref: "Commit 'xyz' not found. Recent commits:" + `git log --oneline -10`
- Suggest valid references: HEAD, HEAD~N, sha1, branch names

**Important:** Do NOT retrieve existing commit message via get_commit_message. We generate purely from code changes.

### Step 1: Get Changes

**Actions:**
- [ ] Source helper script using bash -c pattern (see Utility Scripts section for invocation examples)
- [ ] Verify working directory is a git repository
- [ ] Branch based on data_source:

**If data_source = "staged":**
- [ ] Use get_staged_files to list changed files
- [ ] Use get_staged_diff to retrieve full diff
- [ ] Confirm file count and types detected

**Error Handling:**
If no staged changes found: "No staged changes found. Stage files with 'git add' first."

**If data_source = "commit":**
- [ ] Use get_commit_files <commit_ref> to get changed files
- [ ] Use get_commit_diff <commit_ref> to retrieve full diff
- [ ] DO NOT use get_commit_message (ignore existing message)
- [ ] Confirm file count and types detected

**Error Handling:**
If commit not found: Show recent commits with `git log --oneline -10`

**After this step:** Proceed to Step 2 with the diff and file list. All remaining steps (2-6) work identically for both data sources.

See **Utility Scripts** section below for helper functions reference.

### Step 2: Determine Type

**Actions:**
- [ ] Invoke type-detector agent with diff and file list
- [ ] If agent returns `user_question`, ask user to choose type
- [ ] Use selected/returned type for message generation
- [ ] Store breaking change indicators for Step 5

**Invocation:**

```
Task(
  subagent_type="commit-message-generator:type-detector",
  description="Determine commit type",
  prompt="Analyze this diff and determine the conventional commit type.

**Diff:**
{diff content from get_staged_diff or get_commit_diff}

**Files:**
{file list from get_staged_files or get_commit_files}

**Data source:** {Staged changes | Commit {commit_ref}}"
)
```

**Agent returns:** type, confidence, reasoning, breaking info, optional `user_question`

**Processing:**
- **If `user_question` present:** Pass directly to AskUserQuestion tool, use user's selection
- **If no `user_question`:** Use `type` directly (agent is confident)
- **Store breaking indicators** (`breaking`, `breaking_reasoning`) for Step 5

**Error handling:** If agent fails:
1. Retry agent invocation once (handles transient failures)
2. If second failure, use AskUserQuestion to let user select type:
   - Question: "The type detector encountered an error. Please select the commit type:"
   - Options: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
   - Each option includes brief description (e.g., "feat - New feature or functionality")
3. Log agent error details for bug reporting

### Step 3: Infer Scope

**Actions:**
- [ ] Extract file paths from diff
- [ ] Identify common path prefixes
- [ ] Determine if single or multiple scopes
- [ ] Load references/scope-detection.md if ambiguous
- [ ] Ask user if multiple valid scopes

**Scope Inference Logic:**

1. **Single Module**: Files all in same module → use module name
   - Example: `src/auth/login.ts`, `src/auth/types.ts` → scope: `auth`

2. **Multiple Related Modules**: Files related to same feature → use feature name
   - Example: `src/api/users.ts`, `src/services/UserService.ts` → scope: `users`

3. **Multiple Unrelated Modules**: Files in different domains → ask user or omit
   - Example: `src/auth/`, `src/database/`, `src/cache/` → ask: "Which is primary?"

**Common Path-to-Scope Mapping:**
- `src/auth/` → `auth`
- `src/api/` → `api`
- `src/database/` → `db`
- `src/components/` → `ui` or component name
- `src/services/` → service name or feature
- `src/config/` → `config`

See `references/scope-detection.md` for complex patterns and custom scopes.

### Step 4: Craft Subject

**Actions:**
- [ ] Use imperative mood (add, fix, remove - not added, fixes, removed)
- [ ] Start with lowercase letter
- [ ] No period at end
- [ ] Check length against max_subject_length
- [ ] Make description specific and clear

**Subject Validation Rules:**
- ✅ Imperative: "add user authentication", "fix memory leak", "remove dead code"
- ❌ Wrong tense: "added authentication", "fixes memory", "removes code"
- ✅ Lowercase: "add feature" (not "Add feature")
- ❌ Period: "add feature." (remove the period)
- ✅ Concise and specific: "add JWT authentication" (not "add feature")

**Example transformations:**
- "Added OAuth2 support" → "add OAuth2 support"
- "Fix the bug" → "fix memory leak in cache"
- "Updated dependencies" → "upgrade dependencies to v18"

### Step 5: Generate Complete Message

**Actions:**
- [ ] Build type(scope): subject line (from steps 2-4)
- [ ] Add body for context if changes are complex
- [ ] Add footer with ticket references if applicable
- [ ] Include BREAKING CHANGE footer if breaking change detected
- [ ] Verify formatting and spacing

**Message Format:**

Format:
```
type(scope): subject

body (optional)

footer (optional)
BREAKING CHANGE: description (if applicable)
```

### Step 6: Self-Validate (Iterative Loop)

**Validate commit message before presenting (max 3 iterations):**

1. **Run Validation** - Check format compliance (type, scope, subject) and consistency (type matches changes, scope matches files, subject accurate)
2. **If PASS** - Proceed to present message
3. **If FAIL** - Apply automatic fixes if possible (trim subject, add breaking change footer, suggest scope)
4. **Escalate to User** - After 3 iterations, ask user for clarification on remaining issues

**Validation checks:**
- Format: Valid type, proper scope format, subject format correct
- Consistency: Type matches change nature, scope matches file paths, subject describes changes accurately
- Breaking changes: Marker (!) matches BREAKING CHANGE footer

See `references/validation-checklist.md` for complete validation criteria.

### Step 7: Offer Clipboard Copy (Generation Only)

**Actions:**
- [ ] Use AskUserQuestion tool to ask if user wants to copy the commit message to clipboard
- [ ] If user selects "Yes":
  - [ ] Source clipboard-helper.sh using bash -c pattern
  - [ ] Call copy_to_clipboard with the generated commit message
  - [ ] Report success or failure to user
- [ ] If user selects "No":
  - [ ] Skip clipboard copy, proceed to present message only

**AskUserQuestion Format:**
```
Question: "Copy the generated commit message to your clipboard?"
Header: "Clipboard"
Options:
  - "Yes, copy to clipboard" (description: "Copy the commit message to system clipboard for easy pasting")
  - "No, just show the message" (description: "Display the message without copying to clipboard")
```

**Clipboard Copy Invocation:**
```bash
bash -c "cd {baseDir} && source scripts/clipboard-helper.sh && copy_to_clipboard 'commit message here'"
```

**Error Handling:**
- If clipboard tool not available: Show error message with installation instructions
- If copy fails: Report failure but still present the generated message
- Always present the message regardless of clipboard success/failure

**Important:** This step only runs in Generation mode. Validation mode should NOT offer clipboard copy.

See **Utility Scripts** section below for clipboard-helper.sh reference.

## Validation Workflow

Execute these steps to validate existing commit messages:

### Step 1: Get Commit

**Actions:**
- [ ] Source helper script using bash -c pattern (see Utility Scripts section for invocation examples)
- [ ] Use HEAD as default if no commit reference provided
- [ ] Use get_commit_message to retrieve commit message
- [ ] Use get_commit_files to get file changes
- [ ] Use get_commit_diff to retrieve full diff
- [ ] Confirm commit exists and is accessible

See **Utility Scripts** section below for helper functions reference.

**Error Handling:**
- If commit not found: Show recent commits with `git log --oneline -10`
- Suggest valid references (HEAD, HEAD~N, SHA1, branch name)

### Step 2: Parse Commit Message

**Actions:**
- [ ] Extract type from commit message (feat, fix, docs, etc.)
- [ ] Extract scope (if present, in parentheses)
- [ ] Check for breaking change marker (!)
- [ ] Parse subject line (after `: `)
- [ ] Extract body section (after first blank line)
- [ ] Extract footer section (key: value pairs)

**Regex Pattern for Validation:**
```
^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?: .+
```

**Expected Commit Message Structure:**
```
type(scope)!: subject

body (optional)

footer (optional)
BREAKING CHANGE: description
```

### Step 3: Format Compliance

**Actions:**
- [ ] Verify type is in allowed types list
- [ ] Check scope format (alphanumeric/kebab-case if present)
- [ ] Ensure subject doesn't end with period
- [ ] Verify subject length within min/max limits
- [ ] Confirm breaking change marker (!) matches BREAKING CHANGE footer
- [ ] Load references/conventional-commits-spec.md if violations found

**Format Rules to Check:**
- Type in allowed list (feat, fix, docs, etc.)
- Scope format: kebab-case, no special chars (unless project allows)
- Subject: no period at end, lowercase, imperative mood
- Breaking marker (!) must have BREAKING CHANGE footer
- Subject length: between min (default 10) and max (default 72) chars

See `references/conventional-commits-spec.md` for full specification.

### Step 4: Consistency Check

**Actions:**
- [ ] Analyze actual changes from diff
- [ ] Compare type against actual change nature
- [ ] Verify scope matches changed file paths
- [ ] Check subject describes changes accurately
- [ ] Confirm breaking changes are properly marked
- [ ] Load references/consistency-validation.md if uncertain

**Consistency Validation:**
- Type accuracy: Does type reflect actual changes? (feat vs fix vs refactor)
- Scope accuracy: Do changed files match claimed scope?
- Subject accuracy: Does subject describe actual changes without vagueness?
- Breaking changes: Are all breaking changes marked? Are false positives avoided?

See `references/consistency-validation.md` for detailed validation patterns.

### Step 5: Generate Report

**Actions:**
- [ ] Determine appropriate verbosity level
- [ ] Compile format compliance results
- [ ] Compile consistency check results
- [ ] Add specific recommendations
- [ ] Format output for user clarity
- [ ] Include suggested improvements if applicable

**Verbosity Levels:**
- **Verbose**: Full reasoning for learning/complex cases (use when user asks for explanation)
- **Standard**: Core results with key decisions (default for most validations)
- **Concise**: Pass/fail only for batch operations (use when validating many commits)

**Report Structure:**
```
Commit Message Validation Report
=================================

Commit: <hash>
Commit Message: "<full message>"

Format Compliance: [PASS/FAIL/WARN]
  [✓/✗/⚠] Rule 1: <specific result>
  [✓/✗/⚠] Rule 2: <specific result>

Consistency Check: [PASS/FAIL/WARN]
  [✓/✗/⚠] Type accuracy: <analysis>
  [✓/✗/⚠] Scope accuracy: <analysis>
  [✓/✗/⚠] Subject accuracy: <analysis>

Recommendations (if any):
  1. <specific suggestion>
  2. <specific suggestion>

[Optional] Suggested improved message: <example>
```

See `references/output-formats.md` for output templates.

## Utility Scripts

This skill includes bash utility scripts for reliable git operations. All scripts contain functions that must be sourced before calling.

**Invocation pattern:**
```bash
bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-commit-helpers.sh && function_name arg1 arg2"
```

**Important:** The `WORK_DIR` variable must be set to the user's project directory before sourcing git-commit-helpers.sh. This ensures git commands execute in the correct repository even when the script is sourced from the plugin directory.

**git-commit-helpers.sh** - Git operations and commit parsing
```bash
# Get staged files with status
bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-commit-helpers.sh && get_staged_files"

# Get staged diff
bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-commit-helpers.sh && get_staged_diff"

# Get commit message
bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-commit-helpers.sh && get_commit_message HEAD"

# Get commit diff
bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-commit-helpers.sh && get_commit_diff abc123f"

# Parse commit type
bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-commit-helpers.sh && parse_commit_type 'feat(auth): add OAuth2'"

# Check for breaking change marker
bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-commit-helpers.sh && has_breaking_change_marker 'feat(api)!: change endpoint'"
```

Available functions: `get_staged_diff`, `get_staged_files`, `get_commit_message`, `get_commit_diff`, `get_commit_files`, `parse_commit_type`, `parse_commit_scope`, `parse_commit_subject`, `has_breaking_change_marker`, `validate_commit_format`, `get_commit_hash`, `get_commit_hash_short`, `is_working_directory_clean`

**clipboard-helper.sh** - Cross-platform clipboard operations
```bash
# Copy text to clipboard
bash -c "cd {baseDir} && source scripts/clipboard-helper.sh && copy_to_clipboard 'commit message text'"

# Detect available clipboard tool
bash -c "cd {baseDir} && source scripts/clipboard-helper.sh && detect_clipboard_tool"

# Detect platform
bash -c "cd {baseDir} && source scripts/clipboard-helper.sh && detect_platform"
```

Available functions: `copy_to_clipboard`, `detect_clipboard_tool`, `detect_platform`

**Platform support:**
- macOS: Uses `pbcopy` (built-in)
- Linux X11: Uses `xclip` or `xsel` (requires installation)
- Linux Wayland: Uses `wl-copy` from wl-clipboard (requires installation)
- Windows/WSL: Uses `clip.exe` (built-in)

**Note:** The clipboard script automatically detects the platform and available tools. If no clipboard tool is found, it provides installation instructions.

## Progressive Disclosure References

Load reference files ONLY when needed:

**Scope inference uncertainty:**
`references/scope-detection.md` - Complex path patterns, custom scopes, multi-module changes

**Format compliance questions:**
`references/conventional-commits-spec.md` - Full spec, footer syntax, edge cases

**Consistency validation needs:**
`references/consistency-validation.md` - Detailed validation criteria, type/scope/subject accuracy

**Configuration questions:**
`references/custom-rules.md` - Project-specific config, ticket formats, custom types

**Output formatting:**
`references/output-formats.md` - Verbosity levels, report templates, examples

**Error handling:**
`references/error-handling.md` - Error recovery patterns, git failures, config errors

**QA procedures:**
`references/validation-checklist.md` - Systematic validation steps, quality gates

**Examples:**
`references/examples.md` - Generation/validation examples, edge cases

## Error Handling

Handle errors gracefully with clear, actionable messages:
- Not a git repo → suggest `git init`
- No staged changes → suggest `git add <files>`
- Invalid commit ref → show recent commits, suggest valid refs
- Invalid config → warn, fall back to defaults
- Git command failures → report error, suggest remedies

See `references/error-handling.md` for detailed recovery patterns.

## Output Guidelines

Adapt verbosity to context automatically:
- Complex/uncertain operations: Include reasoning and alternatives
- Standard requests: Show brief analysis with key decisions
- Batch operations: Concise pass/fail only

### Output Format for Generation

**CRITICAL RULES:**
1. Present brief analysis BEFORE the commit message
2. NEVER show validation checkmarks (✅/✗) in generation output
3. Self-validation (Step 6) is internal only - do not display to user

**Structure:**
- Brief analysis: files changed, type reasoning, scope reasoning, breaking changes
- Then: "Generated commit message:" or "Generated commit message for [sha]:"
- Then: The actual commit message

See `references/output-formats.md` for detailed templates and examples.
