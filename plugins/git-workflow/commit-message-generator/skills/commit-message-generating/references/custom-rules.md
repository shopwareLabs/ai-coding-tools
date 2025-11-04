# Custom Rules Configuration

Configure project-specific commit message rules via `.commitmsgrc.md`.

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

Define allowed scopes. Empty array = optional (inferred from files); array values = only listed scopes allowed.

```yaml
scopes: [api, auth, ui, db]
```

### require_scope

Require scope in commits (default: `false`).

```yaml
require_scope: true
scopes: [api, auth]
```

### required_ticket_format

Enforce ticket/issue reference format (regex pattern in footer).

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

Boolean options (default `true`) for subject formatting:

- **require_imperative** — Accept imperative ("add"), reject past/present tense
- **require_lowercase_subject** — Enforce lowercase: `feat: add` ✓, `feat: Add` ✗
- **forbid_period** — Reject trailing periods: `fix: issue` ✓, `fix: issue.` ✗

## Advanced Configuration

### type_aliases

**Aliases for type names:**
```yaml
type_aliases:
  feature: feat
  bugfix: fix
  hotfix: fix
  documentation: docs
```

**Effect:** `feature: add login` → treated as `feat: add login`

### scope_aliases

**Aliases for scope names:**
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

**Patterns to skip validation:**
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

### body_validation

Control when body is required and how it's validated.

#### require_body_for_types (Array of strings, default: [])

Require body for specific commit types.

**Example:**
```yaml
body_validation:
  require_body_for_types:
    - feat  # Features should explain motivation
    - fix   # Fixes should explain root cause
    - perf  # Performance changes should show metrics
```

**Validation:** Commits of specified types without body will FAIL

#### require_body_above_file_count (Integer, default: null/disabled)

Require body when change affects many files.

**Example:**
```yaml
body_validation:
  require_body_above_file_count: 5
```

**Validation:** Commits changing more than N files without body will WARN

#### require_body_for_breaking (Boolean, default: true)

Require body for breaking changes to explain impact and migration.

**Example:**
```yaml
body_validation:
  require_body_for_breaking: true
```

**Validation:** Commits with ! marker without body will FAIL

#### body_line_length (Integer, default: 72)

Recommended line length for body text.

**Example:**
```yaml
body_validation:
  body_line_length: 72
```

**Validation:** Lines exceeding limit will WARN (not FAIL)

#### require_migration_instructions (Boolean, default: true)

Require migration instructions for breaking changes.

**Example:**
```yaml
body_validation:
  require_migration_instructions: true
```

**Validation:** Breaking changes without migration steps will FAIL

#### require_why_explanation (Boolean, default: true)

Require body to explain WHY (not WHAT).

**Example:**
```yaml
body_validation:
  require_why_explanation: true
```

**Validation:** Body that restates code will WARN

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

**File not found:** "Using default configuration. Create .commitmsgrc.md to customize."

**Invalid YAML/Values:** "Warning: .commitmsgrc.md invalid (YAML or type error). Using defaults. Example: invalid max_subject_length: 'abc' (expected number: 72)"

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
