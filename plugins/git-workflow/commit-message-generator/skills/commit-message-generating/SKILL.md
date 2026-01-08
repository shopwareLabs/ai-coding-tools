---
name: commit-message-generating
version: 2.3.0
description: Generate and validate conventional commit messages with confidence-based type/scope detection. Analyzes code changes to determine type, infer scope from file paths, and detect breaking changes. Use when writing or validating commit messages.
allowed-tools: Read, Bash, AskUserQuestion, Task
---

# Commit Message Generating

Generate and validate conventional commit messages for projects with high commit message quality requirements.

## Requirements

- Git repository with commit history
- Explicit commit reference (any valid git ref)
- Optional: `.commitmsgrc.md` for custom project rules

## Mode Detection

- **Generation**: "generate", "create", "write" or `/commit-gen`
- **Validation**: "validate", "check", "verify" or `/commit-check`

## Configuration

Load `.commitmsgrc.md` from project root if present. Extract: `types`, `scopes`, `require_scope`, `required_ticket_format`, `max_subject_length`, `require_body_for_breaking`, `add_attribution_footer`.

**Defaults:** Types (feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert), Subject max 72 chars, Body required for breaking changes, Attribution footer disabled.

---

## Generation Workflow

### Step 1: Load Config and Resolve Reference

1. Read `.commitmsgrc.md` if present, use defaults otherwise
2. Resolve commit reference: `git rev-parse --verify <ref>^{commit}`
3. Get diff and file list: `git show <sha> --format="" --name-status` and `git show <sha> --format=""`

**Error:** Invalid ref → show `git log --oneline -5`

### Step 2: Determine Type

Invoke type-detector agent:

```
Task(
  subagent_type="commit-message-generator:type-detector",
  description="Determine commit type",
  prompt="Analyze and determine type.\n\n**Diff:**\n{diff}\n\n**Files:**\n{files}"
)
```

**Processing:**
- If `user_question` returned → pass to AskUserQuestion
- Otherwise → use returned `type` directly
- Store breaking change indicators

### Step 3: Infer Scope

Invoke scope-detector agent:

```
Task(
  subagent_type="commit-message-generator:scope-detector",
  description="Determine scope",
  prompt="Determine scope from files.\n\n**Files:**\n{files}\n\n**Type:** {type}\n\n**Config scopes:** {config.scopes}"
)
```

**Processing:**
- If `user_question` returned → pass to AskUserQuestion
- If `omit_scope: true` → skip scope
- Otherwise → use returned `scope`

### Step 4: Craft Subject and Message

**Subject rules:** Imperative mood, lowercase, no period, max length from config, specific description.

**Message format:**
```
type(scope): subject

body (if complex changes or breaking)

BREAKING CHANGE: description (if breaking)
Refs: TICKET-123 (if required_ticket_format)

🤖 Generated with [Claude Code](https://claude.com/claude-code) (if add_attribution_footer)

Co-authored-by: Claude <model-name> <noreply@anthropic.com> (if add_attribution_footer)
```

Note: Use your actual model name (e.g., "Opus 4.5", "Sonnet 4") for `<model-name>`.

### Step 5: Validate and Present

Quick self-check: type matches changes, scope matches files, subject is accurate. If issues found, fix and note. Present the generated message.

**Output format:** Brief analysis (type reasoning, scope reasoning, breaking changes), then the commit message.

---

## Validation Workflow

### Step 1: Load Config and Get Commit

1. Read `.commitmsgrc.md` if present
2. Resolve commit reference and get: message, diff, files
3. Parse message: type, scope, breaking marker, subject, body, footer

### Step 2: Format Compliance

Check against Conventional Commits spec and project config:
- Type in allowed list
- Scope format (kebab-case) and in allowed list if configured
- Subject: no period, lowercase after colon, imperative mood
- Breaking marker (!) has BREAKING CHANGE footer
- Subject length within limits

### Step 3: Consistency Check

Analyze actual changes and compare:
- Type accuracy: Does type match change nature?
- Scope accuracy: Do files match claimed scope?
- Subject accuracy: Does subject describe changes?
- Breaking changes: Properly marked?

### Step 4: Validate Body Quality

Invoke body-validator agent:

```
Task(
  subagent_type="commit-message-generator:body-validator",
  description="Validate body",
  prompt="Validate body.\n\n**Body:** {body}\n\n**Type:** {type}\n**Breaking:** {breaking}\n**Files:** {file_count}\n\n**Config:** {body_validation_config}"
)
```

### Step 5: Generate Report

Format validation results directly using these templates:

**Status Icons:** PASS=✓, WARN=⚠, FAIL=✗

**Concise** (for batch operations):
```
Commit {hash}: {STATUS} {icon} ({N} issues)
```

**Standard** (default):
```
Commit Message Validation Report
=================================

Commit: {hash}
Message: "{message}"

Format Compliance: {STATUS} {icon}
Consistency Check: {STATUS} {icon}
  {Only WARN/FAIL items with icon prefix}
Body Quality: {STATUS} {icon}
  {Only WARN/FAIL items with icon prefix}

Recommendations:
  1. {First recommendation from failed checks}
```

**Verbose** (for complex issues):
- Include all check details with reasoning
- Add suggested improved message if issues found

Present the formatted report to user.

---

## Git Commands

Use these git commands directly:

```bash
# Resolve reference to SHA
git rev-parse --verify <ref>^{commit}

# Commit files and diff
git show <sha> --name-status --format=''
git show <sha> --format=''

# Commit message
git log -1 --format='%B' <sha>
```

---

## Error Handling

- Not a git repo → suggest `git init`
- Invalid commit ref → show recent commits with `git log --oneline -5`
- Invalid config → warn, use defaults, continue

## Output Guidelines

- **Generation:** Brief analysis, then commit message (no validation checkmarks)
- **Validation:** Formatted report with status, issues, recommendations
- Adapt verbosity: verbose for complex/uncertain, concise for batch operations
