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
- [ ] Invoke scope-detector agent with file list and commit type
- [ ] If agent returns `user_question`, ask user to choose scope
- [ ] Use selected/returned scope for message generation
- [ ] Store scope determination for Step 6 validation

**Invocation:**

```
Task(
  subagent_type="commit-message-generator:scope-detector",
  description="Determine commit scope",
  prompt="Analyze these file paths and determine the conventional commit scope.

**Files:**
{file list from get_staged_files or get_commit_files}

**Commit Type:** {type from Step 2}

**Data source:** {Staged changes | Commit {commit_ref}}

**Project Config (if present):**
{.commitmsgrc.md scopes/scope_aliases from Step 0}"
)
```

**Agent returns:** scope, confidence, reasoning, omit_scope flag, optional `user_question`

**Processing:**
- **If `user_question` present:** Pass directly to AskUserQuestion tool, use user's selection
- **If no `user_question`:** Use `scope` directly (agent is confident)
- **If `omit_scope: true`:** Skip scope in message (type-only format)

**Error handling:** If agent fails:
1. Retry agent invocation once (handles transient failures)
2. If second failure, use fallback logic:
   - Extract first directory from most common path
   - Set confidence = LOW
   - Ask user via AskUserQuestion with "omit scope" option
3. Log agent error for bug reporting

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
- [ ] Invoke report-generator agent with validation results
- [ ] Pass verbosity level and structured validation data
- [ ] Present formatted report to user

**Invocation:**

```
Task(
  subagent_type="commit-message-generator:report-generator",
  description="Format validation report",
  prompt="Generate validation report for commit {commit_hash}.

**Validation Results:**
{
  \"commit\": {
    \"hash\": \"{commit_hash}\",
    \"short_hash\": \"{short_hash}\",
    \"message\": \"{full_commit_message}\",
    \"parsed\": {
      \"type\": \"{parsed_type}\",
      \"scope\": \"{parsed_scope}\",
      \"breaking\": {breaking_flag},
      \"subject\": \"{parsed_subject}\",
      \"body\": \"{parsed_body}\",
      \"footer\": \"{parsed_footer}\"
    }
  },
  \"format_compliance\": {
    \"status\": \"PASS|WARN|FAIL\",
    \"checks\": [
      {
        \"rule\": \"Type validity\",
        \"status\": \"PASS|WARN|FAIL\",
        \"message\": \"Description\",
        \"severity\": \"error|warning\",
        \"expected\": \"Expected value (if failed)\",
        \"actual\": \"Actual value (if failed)\"
      }
    ]
  },
  \"consistency_check\": {
    \"status\": \"PASS|WARN|FAIL\",
    \"checks\": [
      {
        \"aspect\": \"Type accuracy|Scope accuracy|Subject accuracy|Breaking changes\",
        \"status\": \"PASS|WARN|FAIL\",
        \"claimed\": \"Value from message\",
        \"inferred\": \"Value from analysis\",
        \"confidence\": \"HIGH|MEDIUM|LOW\",
        \"reasoning\": \"Explanation\",
        \"recommendation\": \"Suggested fix\"
      }
    ]
  },
  \"overall_status\": \"PASS|WARN|FAIL\",
  \"verbosity\": \"{concise|standard|verbose}\",
  \"files_changed\": [{file_list}],
  \"diff_summary\": \"{brief_diff_description}\"
}

**Verbosity Level:** {standard|verbose|concise}

**Context:** Validation mode for commit {commit_ref}"
)
```

**Agent returns:** Formatted markdown report (plain text)

**Processing:**
- Agent formats validation results into user-friendly report
- Report format varies by verbosity level:
  - **Concise**: Single line with status and issue count
  - **Standard**: Summary with key issues and recommendations (default)
  - **Verbose**: Full details with reasoning and suggested improvements
- Present report directly to user (no post-processing needed)

**Error handling:** If agent fails:
1. Retry agent invocation once (handles transient failures)
2. If second failure, use fallback formatting:
   ```
   Commit {hash}: {overall_status} ({issue_count} issues)

   See validation results above for details.
   ```
3. Log agent error for bug reporting

**Verbosity Determination:**
- **Verbose**: When user asks for explanation, details, or reasoning
- **Standard**: Default for most validations
- **Concise**: When validating multiple commits (ranges, lists) or user requests brief output

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

**Format compliance questions:**
`references/conventional-commits-spec.md` - Full spec, footer syntax, edge cases

**Consistency validation needs:**
`references/consistency-validation.md` - Detailed validation criteria, type/scope/subject accuracy

**Configuration questions:**
`references/custom-rules.md` - Project-specific config, ticket formats, custom types

**Output formatting:**
`references/output-formats.md` - Generation output verbosity levels and formatting (validation reports: see `agents/report-generator.md`)

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
