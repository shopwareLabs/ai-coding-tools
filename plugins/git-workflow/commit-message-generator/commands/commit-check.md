---
description: Validate commit message follows conventions and matches changes
argument-hint: "<commit-ref>"
allowed-tools: Skill, Bash
model: haiku
---

# Check Commit Message

Validate that a commit message follows conventional commits format and accurately describes the changes.

## Task

1. **Validate argument** - require explicit commit reference
2. **Invoke the skill** in validation mode

## Argument Validation

**Argument**: $ARGUMENTS

If no argument provided, show error and stop:
```
Error: Git reference required.

Usage: /commit-check <commit-ref>

Examples:
  /commit-check HEAD        # Most recent commit
  /commit-check HEAD~3      # Three commits back
  /commit-check abc123f     # Specific SHA
```

Validate reference exists: `git rev-parse --verify <ref>^{commit}`
If invalid, show recent commits: `git log --oneline -5`

Use the Skill tool to invoke "commit-message-generating" in validation mode.

The skill will:
1. Parse commit message format
2. Verify conventional commits compliance
3. Analyze actual code changes
4. Check type/scope/subject accuracy
5. Validate breaking change markers
6. Check body quality and migration instructions
7. Apply project rules from `.commitmsgrc.md`

## Examples

```bash
/commit-check HEAD        # Most recent commit
/commit-check HEAD~3      # Three commits back
/commit-check abc123f     # Specific SHA
```

## Output

```
Commit Message Validation Report
=================================

Commit: abc123f
Message: "feat(auth): add login endpoint"

Format Compliance: PASS
Consistency Check: WARN
  Type accuracy: PASS
  Scope accuracy: PASS
  Subject accuracy: WARN - Could be more specific

Recommendations:
  1. Make subject more specific about what was added
```
