# Custom Rules Configuration

Guide for configuring project-specific commit message rules via `.commitmsgrc.md`.

## Table of Contents

[File Location](#configuration-file-location) | [Basic Structure](#basic-configuration-structure) | [Options Reference](#configuration-options-reference) | [Advanced Options](#advanced-configuration) | [Examples](#complete-configuration-examples) | [Validation](#configuration-validation) | [Loading](#loading-configuration) | [Testing](#testing-configuration) | [Team Workflow](#team-workflow) | [Tool Integration](#integration-with-tools) | [FAQ](#faq)

## Configuration File Location

Place `.commitmsgrc.md` in project root (alongside `.git/`, `src/`, `package.json`).

## Basic Configuration Structure

```yaml
---
types:
  - feat
  - fix
scopes:
  - api
  - ui
required_ticket_format: "JIRA-\\d+"
max_subject_length: 72
---
```

## Configuration Options Reference

### types

Define allowed commit types (default: `[feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert]`).

```yaml
types: [feat, fix, docs, chore]
```

Only listed types are valid.

### scopes

Define allowed scopes (default: `[]` = any scope allowed, inferred from file paths). If empty, scopes are optional and inferred; if specified, only listed scopes are allowed.

```yaml
scopes: [api, auth, ui, db]
```

### require_scope

Make scope mandatory (default: `false`). Commit must include one of the allowed scopes.

```yaml
require_scope: true
scopes: [api, auth]
```

### required_ticket_format

Enforce ticket/issue reference format (default: `""` = optional). Regular expression pattern; footer must contain matching pattern.

**Examples:** JIRA: `"[A-Z]+-\\d+"` | GitHub: `"#\\d+"` | Custom: `"Refs: [A-Z]+-\\d+"`

### breaking_change_marker

Define symbol for breaking changes (default: `"!"`). Usage: `feat(api)!: change endpoint`

```yaml
breaking_change_marker: "!"
```

### Subject Length Constraints

**max_subject_length** (default: `72`) — Maximum line length; example: `max_subject_length: 50`

**min_subject_length** (default: `10`) — Minimum line length; example: `min_subject_length: 15`

### Subject Format Enforcement Options

These boolean options (all default `true`) enforce consistent subject formatting:

- **require_imperative** — Reject past tense ("added") and present tense ("adds"); accept imperative ("add")
- **require_lowercase_subject** — Enforce lowercase start after type/scope: `feat: add` ✓, `feat: Add` ✗
- **forbid_period** — Reject trailing periods: `fix: resolve issue` ✓, `fix: resolve issue.` ✗

## Advanced Configuration

### type_aliases

**Purpose:** Map alternative type names to standard types

**Example:**
```yaml
type_aliases:
  feature: feat
  bugfix: fix
  hotfix: fix
  documentation: docs
```

**Effect:** `feature: add login` → treated as `feat: add login`

### scope_aliases

**Purpose:** Normalize scope names

**Example:**
```yaml
scope_aliases:
  authentication: auth
  database: db
  frontend: ui
  backend: api
  user-interface: ui
```

**Effect:** `feat(authentication): ...` → normalized to `auth`

### exempt_patterns

**Purpose:** Skip validation for matching commit messages

**Example:**
```yaml
exempt_patterns:
  - "^Merge "
  - "^Revert "
  - "^Initial commit$"
  - "^Bump version"
```

**Effect:** These patterns bypass all validation rules

### custom_rules

Additional validation constraints:

**require_body_for_types** — Specified types must include commit body; example: `[feat, fix]`

**require_breaking_change_footer** — If `!` marker present, BREAKING CHANGE footer mandatory

**max_files_without_scope** — Scope required if more than N files changed; example: `5`

## Complete Configuration Examples

### Minimal Open Source Project

```yaml
---
types: [feat, fix, docs, refactor, test, chore]
required_ticket_format: "#\\d+"
max_subject_length: 72
---
```

### Strict Enterprise Configuration

```yaml
---
types: [feat, fix, docs, refactor, test]
scopes: [api, auth, billing, reporting, ui, db]
require_scope: true
required_ticket_format: "JIRA-\\d+"
max_subject_length: 50
min_subject_length: 15
custom_rules:
  require_body_for_types: [feat, fix]
  require_breaking_change_footer: true
  max_files_without_scope: 3
type_aliases: {feature: feat, bugfix: fix, hotfix: fix}
scope_aliases: {authentication: auth, database: db}
exempt_patterns: ["^Merge ", "^Bump version"]
---
```

### Flexible Team Configuration

```yaml
---
types: [feat, fix, docs, style, refactor, perf, test, build, ci, chore]
scopes: []
required_ticket_format: ""
max_subject_length: 72
min_subject_length: 10
require_imperative: true
require_lowercase_subject: true
forbid_period: true
custom_rules:
  require_breaking_change_footer: true
exempt_patterns: ["^Merge ", "^Revert ", "^Initial commit$"]
---
```

### Monorepo Configuration

```yaml
---
types: [feat, fix, docs, refactor, test, build, chore]
scopes: [core, ui-components, api-client, utils, shared-types, docs-site]
require_scope: true
required_ticket_format: "Refs: [A-Z]+-\\d+"
max_subject_length: 72
custom_rules:
  require_body_for_types: [feat]
  require_breaking_change_footer: true
scope_aliases: {components: ui-components, api: api-client, types: shared-types, documentation: docs-site}
---
```

## Configuration Validation

### Valid Configuration

```yaml
---
types:
  - feat
  - fix
scopes:
  - api
---
```
✓ Valid YAML, recognized keys

### Invalid Configuration

```yaml
---
types
  - feat  # Missing colon
  - fix
---
```
✗ Invalid YAML syntax

```yaml
---
types: "feat, fix"  # Should be array
---
```
✗ Wrong type for 'types' field

```yaml
---
unknown_field: value
---
```
⚠ Warning: Unknown field ignored, uses defaults

## Loading Configuration

### Skill Behavior

1. Check for `.commitmsgrc.md` in project root
2. If exists:
   - Parse YAML frontmatter
   - Validate configuration
   - Apply custom rules
3. If missing or invalid:
   - Use default conventional commits rules
   - Log warning if invalid

### Error Handling

**File not found:**
```
Using default configuration. Create .commitmsgrc.md to customize.
```

**Invalid YAML/Values:**
```
Warning: .commitmsgrc.md invalid (YAML or type error).
Using defaults. Example: invalid max_subject_length: "abc" (expected number: 72)
```

## Testing Configuration

### Validation Command

Use `/commit-check` on test commit to verify config:

```bash
# Create test commit
git add .
git commit -m "feat(api): test configuration"

# Validate
/commit-check HEAD
```

**Expected output:**
```
Format Compliance: ✓ PASS
  ✓ Valid type: feat (allowed in config)
  ✓ Valid scope: api (allowed in config)
  ✓ Subject length: 22 chars (within 50 limit)
  ✓ Ticket reference: JIRA-123 (matches required format)
```

## Team Workflow

### Initial Setup

Copy template, edit, then commit and push:

```bash
cp plugins/git-workflow/commit-message-generator/skills/commit-message-generating/commitmsgrc-template.md .commitmsgrc.md
vim .commitmsgrc.md
git add .commitmsgrc.md
git commit -m "chore: add conventional commit configuration"
git push
```

### Sharing and Updates

Team members pull the configuration (`git pull`). Configuration is automatically detected and enforced.

To update, edit `.commitmsgrc.md` and repeat the commit/push cycle above.

## Integration with Tools

### commitlint Compatibility

Most `.commitmsgrc.md` options align with commitlint config:

**This plugin:**
```yaml
types:
  - feat
  - fix
max_subject_length: 72
```

**commitlint.config.js:**
```javascript
module.exports = {
  rules: {
    'type-enum': [2, 'always', ['feat', 'fix']],
    'header-max-length': [2, 'always', 72]
  }
}
```

### Husky + commitlint

Use this plugin for interactive help, commitlint for git hooks:

```bash
# Pre-commit: Use commitlint
npx commitlint --edit $1

# During authoring: Use this plugin
/commit-gen
/commit-check HEAD
```

## FAQ

**Q: Is `.commitmsgrc.md` required?**
A: No, optional. Defaults work for most projects.

**Q: Can I use both `.commitmsgrc.md` and commitlint?**
A: Yes, keep configurations synchronized.

**Q: What if team members don't have the plugin?**
A: Configuration works with other tools; plugin users get enhanced features.

**Q: How do I share config across monorepo packages?**
A: Place `.commitmsgrc.md` in monorepo root; all packages inherit.

**Q: Can I require tickets only for certain types?**
A: Not yet. Use `required_ticket_format` globally or omit for flexibility.
