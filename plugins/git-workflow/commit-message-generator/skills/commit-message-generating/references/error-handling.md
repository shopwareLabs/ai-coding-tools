# Error Recovery Patterns

Guide for handling errors during commit message generation and validation.

## Table of Contents

- [Git Repository Errors](#git-repository-errors)
- [Generation Mode Errors](#generation-mode-errors)
- [Validation Mode Errors](#validation-mode-errors)
- [Configuration Errors](#configuration-errors)
- [Git Command Failures](#git-command-failures)
- [General Error Handling Principles](#general-error-handling-principles)

## Git Repository Errors

### Not a git repository

**Detection:** `git rev-parse --git-dir 2>/dev/null`

**Error:** "Error: Not a git repository. Initialize with 'git init' to use commit message generation."

**Recovery:** Initialize git repository with `git init` to proceed.

---

## Generation Mode Errors

### No staged changes

**Detection:** `git diff --cached --quiet`

**Error:** "No staged changes found. Stage your changes first: `git add <files>`\n\nThen generate a commit message."

**Recovery:** Show unstaged files (`git status --short`) and suggest staging them.

### Uncertain type detection

**When confidence is LOW:** Type detection delegates to type-detector agent; skill presents result with confidence level: "Detected type: feat (MEDIUM confidence)"

**Recovery:**
- Ask: "Is 'feat' the correct type, or should it be 'fix', 'refactor', etc.?"
- Accept user correction and continue

### Scope ambiguity

**Triggers:**
- Changes span multiple modules → cannot auto-infer scope
- Config requires scope → must ask user
- Config allows omitting scope → suggest omitting or ask user

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

**Handling:** Attempt to parse; if non-compliant, report format issues and proceed with consistency check if possible.

**Reporting:**
- Report specific format problems: "Missing type", "Invalid scope format", "Subject ends with period"
- Generate validation report with all failures
- Provide corrected example

### Unreachable commit

**Detection:** `git merge-base --is-ancestor <commit-ref> HEAD`

**Warning:** "Warning: Commit '<ref>' is not in current branch history. Proceeding with validation anyway."

**Action:** Continue with validation regardless

---

## Configuration Errors

### Invalid YAML syntax

**Handling:** Parse `.commitmsgrc.md` frontmatter; on failure, warn user and fall back to defaults.

**Error:** "Warning: .commitmsgrc.md contains invalid YAML. Using default configuration.\nDetails: <parse error>"

**Recovery:**
- Use default conventional commits configuration
- Note in output: "Using default config due to parse error"
- Suggest user fix YAML syntax

### Invalid regex patterns

**Handling:** Validate ticket_format regex; if invalid, warn user and skip that rule.

**Error:** "Warning: Invalid regex in ticket_format: <pattern>\nDetails: <regex error>\nSkipping ticket format validation."

**Recovery:**
- Continue with other validation rules
- Note in output: "Ticket format validation skipped due to invalid pattern"

### Missing configuration file

**Handling:** Use defaults silently if `.commitmsgrc.md` not found (not an error).

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

**Recovery:** Resolve the git issue to proceed.

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

1. **Clear, actionable messages** - Explain what went wrong and how to fix it
2. **Graceful degradation** - Fall back to safe defaults
3. **Continue when feasible** - Don't fail entire operation for single validation rule
4. **Show context** - Include relevant git output and commands
5. **Suggest next steps** - Guide user toward resolution
