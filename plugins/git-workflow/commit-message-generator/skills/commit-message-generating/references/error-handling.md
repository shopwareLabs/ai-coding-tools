# Error Recovery Patterns

Comprehensive guide for handling errors gracefully during commit message generation and validation.

## Table of Contents

- [Git Repository Errors](#git-repository-errors)
- [Generation Mode Errors](#generation-mode-errors)
- [Validation Mode Errors](#validation-mode-errors)
- [Configuration Errors](#configuration-errors)
- [Git Command Failures](#git-command-failures)
- [General Error Handling Principles](#general-error-handling-principles)

## Git Repository Errors

### Not a git repository

**Detection:**
```bash
git rev-parse --git-dir 2>/dev/null
```

**Error message:**
```
Error: Not a git repository. Initialize with 'git init' to use commit message generation.
```

**Recovery:** User must initialize git repository before proceeding.

---

## Generation Mode Errors

### No staged changes

**Detection:**
```bash
git diff --cached --quiet
```

**Error message:**
```
No staged changes found. Stage your changes first:
  git add <files>

Then generate a commit message.
```

**Recovery:**
- Show unstaged files via `git status --short`
- Suggest: "You have unstaged changes in: <file list>"
- Wait for user to stage changes

### Uncertain type detection

**When confidence is LOW:**
1. Load `references/type-detection.md` for detailed heuristics
2. If still uncertain → Ask user for type
3. Present detected type with confidence level: "Detected type: feat (MEDIUM confidence)"

**Recovery:**
- Ask: "Is 'feat' the correct type, or should it be 'fix', 'refactor', etc.?"
- Accept user correction and continue

### Scope ambiguity

**Triggers:**
- Changes span multiple modules → Cannot auto-infer scope
- Config requires scope → Must ask user
- Config allows omitting scope → Suggest omitting or ask user

**Recovery:**
- Present changed paths: "Changes in: src/auth/, src/api/, tests/"
- Ask: "Choose scope: 'auth', 'api', or omit scope?"
- Accept user choice and continue

### Subject too long

**Detection:**
Check subject length against max_subject_length from config

**Recovery:**
- Show generated subject with length: "Subject: 'add user authentication with JWT and refresh tokens' (58 chars, limit: 50)"
- Suggest shortened version: "add user authentication with JWT"
- Ask user to approve or provide alternative

---

## Validation Mode Errors

### Invalid commit reference

**Detection:**
```bash
git rev-parse --verify <ref> 2>/dev/null
```

**Error message:**
```
Error: Commit '<ref>' not found. Use a valid commit reference:
  - HEAD (most recent commit)
  - HEAD~N (N commits ago)
  - <sha1> (commit hash)
  - <branch> (branch name)
```

**Recovery:**
- Show recent commits: `git log --oneline -5`
- Ask user to provide valid reference

### Malformed commit message

**Handling:**
1. Attempt to parse commit message
2. If doesn't match conventional commits format → Report format issues
3. Still proceed with consistency check if possible

**Reporting:**
- Report specific format problems: "Missing type", "Invalid scope format", "Subject ends with period"
- Generate validation report with all failures
- Provide corrected example

### Unreachable commit

**Detection:**
```bash
git merge-base --is-ancestor <commit-ref> HEAD
```

**Warning message:**
```
Warning: Commit '<ref>' is not in current branch history.
Proceeding with validation anyway.
```

**Action:** Continue with validation regardless

---

## Configuration Errors

### Invalid YAML syntax

**Handling:**
1. Attempt to parse `.commitmsgrc.md` frontmatter
2. If YAML parsing fails → Warn user with specific error
3. Fall back to default configuration
4. Continue operation with defaults

**Error message:**
```
Warning: .commitmsgrc.md contains invalid YAML. Using default configuration.
Details: <parse error>
```

**Recovery:**
- Use default conventional commits configuration
- Note in output: "Using default config due to parse error"
- Suggest user fix YAML syntax

### Invalid regex patterns

**Handling:**
1. Validate ticket_format regex
2. If regex is invalid → Warn user with specific pattern
3. Skip that specific validation rule
4. Continue with other rules

**Error message:**
```
Warning: Invalid regex in ticket_format: <pattern>
Details: <regex error>
Skipping ticket format validation.
```

**Recovery:**
- Continue with other validation rules
- Note in output: "Ticket format validation skipped due to invalid pattern"

### Missing configuration file

**Handling:**
1. Check for `.commitmsgrc.md`
2. If not found → Silently use defaults (not an error)
3. Do not warn user

**Behavior:** Default configuration is valid, no error message needed.

---

## Git Command Failures

### Diff extraction failure

**Error message:**
```
Error: Failed to retrieve git diff.
Command: git diff --cached
Error: <stderr output>
```

**Recovery:** User must resolve git issue before proceeding.

### Commit parsing failure

**Error message:**
```
Error: Failed to retrieve commit information.
Command: git show <ref>
Error: <stderr output>
```

**Recovery:** User must resolve git issue or provide different commit reference.

---

## General Error Handling Principles

1. **Clear, actionable error messages** - Always explain what went wrong and how to fix it
2. **Graceful degradation** - Fall back to safe defaults when possible
3. **Continue when feasible** - Don't fail entire operation for single validation rule
4. **Show context** - Include relevant git output, file paths, or commands in error messages
5. **Suggest next steps** - Guide user toward resolution, don't just report failure
