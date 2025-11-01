---
description: Validate commit message follows conventions and matches changes
argument-hint: "[commit-ref]"
allowed-tools: Skill
model: claude-haiku-4-5-20251001
---

# Check Commit Message

Validate that a commit message follows conventional commits format and accurately describes the changes.

## Task

Invoke the **commit-message-generating** skill in **validation mode** to check commit message consistency.

**Argument parsing:**
- If `$ARGUMENTS` is provided → validate specified commit (HEAD, sha1, branch, etc.)
- If `$ARGUMENTS` is empty → validate most recent commit (HEAD)

The skill will:
1. Parse the commit message format
2. Verify conventional commits compliance
3. Analyze the actual code changes
4. Check type matches changes (feat vs fix vs refactor)
5. Verify scope accuracy
6. Validate subject describes changes
7. Check for breaking changes
8. Apply project-specific rules from `.commitmsgrc.md` if present

Use the Skill tool to invoke the "commit-message-generating" skill with mode "validate" and the commit reference.

## Examples

```bash
# Validate most recent commit
/commit-check

# Validate specific commit
/commit-check HEAD~3
/commit-check abc123f
/commit-check main

# Validate HEAD commit explicitly
/commit-check HEAD
```

## Output Format

The skill will produce a validation report with:

**Format Compliance:**
- Type validity (feat, fix, etc.)
- Scope format
- Subject line length
- Breaking change markers

**Consistency Check:**
- Does type match actual changes?
- Is scope accurate for changed files?
- Does subject describe what changed?
- Are breaking changes properly marked?

Example output:
```
Commit Message Validation Report
=================================

Commit: abc123f
Message: "feat(auth): add login endpoint"

Format Compliance: ✓ PASS
  ✓ Valid type: feat
  ✓ Scope present: auth
  ✓ Subject length: 25 characters (within 72 limit)

Consistency Check: ✗ FAIL
  ✗ Type mismatch: Message says 'feat' but changes only modify existing
      code in src/auth/LoginController.php. Should be 'refactor' or 'fix'.
  ✓ Scope accurate: Changes are in auth module
  ⚠ Subject vague: "add login endpoint" doesn't specify what was added
      Suggestion: "add OAuth2 support to login endpoint"

Recommendations:
  1. Change type from 'feat' to 'refactor'
  2. Make subject more specific about what was added
```
