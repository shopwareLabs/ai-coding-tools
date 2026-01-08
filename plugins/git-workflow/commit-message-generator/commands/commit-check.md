---
description: Validate commit message follows conventions and matches changes
argument-hint: "[commit-ref]"
allowed-tools: Skill
model: haiku
---

# Check Commit Message

Validate that a commit message follows conventional commits format and accurately describes the changes.

## Task

Invoke the **commit-message-generating** skill in **validation mode**.

**Scope to validate**: $ARGUMENTS (default: HEAD)

The skill will:
1. Parse commit message format
2. Verify conventional commits compliance
3. Analyze actual code changes
4. Check type/scope/subject accuracy
5. Validate breaking change markers
6. Check body quality and migration instructions
7. Apply project rules from `.commitmsgrc.md`

Use the Skill tool to invoke "commit-message-generating" in validation mode.

## Examples

```bash
# Validate most recent commit
/commit-check

# Validate specific commit
/commit-check HEAD~3
/commit-check abc123f
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
