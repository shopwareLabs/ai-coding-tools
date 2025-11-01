---
description: Generate conventional commit message from staged changes or existing commit
argument-hint: "[commit-ref]"
allowed-tools: Skill
model: claude-sonnet-4-5-20250929
---

# Generate Conventional Commit Message

Generate a conventional commit message by analyzing code changes.

## Task

Invoke the **commit-message-generating** skill in **generation mode** to create a properly formatted conventional commit message.

**Scope to generate from**: $ARGUMENTS

### Scope Detection (Smart Parsing)

Parse the arguments to automatically detect the generation source:

**1. Empty arguments** → Generate for staged changes (default)

**2. Git commit** (auto-detected):
   - **Single commit**: `HEAD`, `abc123f`, `HEAD~3`, `main`

Detection pattern:
- Empty → staged changes (default)
- Matches commit patterns (HEAD*, sha1-like, branch names) → single commit
- Otherwise → error with usage help

The skill will:
1. Analyze changes (from staging area or commit diff)
2. Determine the appropriate type (feat, fix, refactor, etc.)
3. Infer scope from changed files
4. Detect breaking changes
5. Generate a conventional commit message
6. Apply project-specific rules from `.commitmsgrc.md` if present

Use the Skill tool to invoke the "commit-message-generating" skill with the detected scope.

## Examples

```bash
# Generate message for staged changes (default)
git add src/auth/
/commit-gen

# Generate message for existing commit
/commit-gen HEAD                     # Last commit
/commit-gen abc123f                  # Specific commit
/commit-gen HEAD~3                   # Older commit
/commit-gen main                     # Branch tip
```

## Output Format

The skill will produce a commit message in conventional commits format:

**For staged changes:**
```
Generated commit message:

type(scope): subject

body (optional)

BREAKING CHANGE: description (if applicable)
```

**For existing commits:**
```
Generated commit message for abc123f:

type(scope): subject

body (optional)

BREAKING CHANGE: description (if applicable)
```

Example output:
```
feat(auth): add JWT token refresh mechanism

Implements automatic token refresh when tokens expire within 5 minutes.
Prevents users from being logged out during active sessions.
```
