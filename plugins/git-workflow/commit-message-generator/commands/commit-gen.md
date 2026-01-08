---
description: Generate conventional commit message from a commit
argument-hint: "<commit-ref>"
allowed-tools: Skill, AskUserQuestion, Bash
model: sonnet
---

# Generate Conventional Commit Message

Generate a conventional commit message by analyzing a commit's changes.

## Task

1. **Validate argument** - require explicit commit reference
2. **Invoke the skill** to generate the commit message
3. **Offer clipboard copy** after the message is generated

## Argument Validation

**Argument**: $ARGUMENTS

If no argument provided, show error and stop:
```
Error: Git reference required.

Usage: /commit-gen <commit-ref>

Examples:
  /commit-gen HEAD        # Most recent commit
  /commit-gen HEAD~3      # Three commits back
  /commit-gen abc123f     # Specific SHA
```

Validate reference exists: `git rev-parse --verify <ref>^{commit}`
If invalid, show recent commits: `git log --oneline -5`

Invoke the skill:
```
Skill(skill="commit-message-generating", args="Generate commit message for <sha>")
```

## Clipboard Offering

After the skill returns the generated commit message, offer to copy it to clipboard:

1. Ask user: "Copy to clipboard?"
2. If yes, copy using platform-appropriate command:
   - macOS: `echo "message" | pbcopy`
   - Linux: `echo "message" | xclip -selection clipboard` or `xsel --clipboard`
   - Windows/WSL: `echo "message" | clip.exe`
3. Confirm success or report failure

## Examples

```bash
/commit-gen HEAD        # Most recent commit
/commit-gen HEAD~3      # Three commits back
/commit-gen abc123f     # Specific SHA
/commit-gen main        # Branch tip
```

## Output

```
Generated commit message for abc123f:

feat(auth): add OAuth2 authentication support

Implements OAuth2 with Google and GitHub providers.

BREAKING CHANGE: Session-based auth deprecated.
```
