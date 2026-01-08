---
description: Generate conventional commit message from staged changes or existing commit
argument-hint: "[commit-ref]"
allowed-tools: Skill, AskUserQuestion, Bash
model: sonnet
---

# Generate Conventional Commit Message

Generate a conventional commit message by analyzing code changes.

## Task

1. **Invoke the skill** to generate the commit message
2. **Offer clipboard copy** after the message is generated

**Scope to generate from**: $ARGUMENTS

### Scope Detection

- **Empty arguments** → Generate for staged changes
- **Git reference** (HEAD, abc123f, HEAD~3, branch name) → Generate for that commit

Use the Skill tool to invoke "commit-message-generating" in generation mode.

### Clipboard Offering

After the skill returns the generated commit message, offer to copy it to clipboard:

1. Ask user: "Copy to clipboard?"
2. If yes, copy using platform-appropriate command:
   - macOS: `echo "message" | pbcopy`
   - Linux: `echo "message" | xclip -selection clipboard` or `xsel --clipboard`
   - Windows/WSL: `echo "message" | clip.exe`
3. Confirm success or report failure

## Examples

```bash
# Staged changes (default)
git add src/auth/
/commit-gen

# Existing commit
/commit-gen HEAD
/commit-gen abc123f
/commit-gen HEAD~3
```

## Output

```
Generated commit message:

feat(auth): add OAuth2 authentication support

Implements OAuth2 with Google and GitHub providers.

BREAKING CHANGE: Session-based auth deprecated.
```
