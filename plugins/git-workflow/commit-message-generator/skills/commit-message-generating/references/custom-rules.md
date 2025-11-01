# Custom Rules Configuration

Guide for configuring project-specific commit message rules via `.commitmsgrc.md`.

## Table of Contents

- [Configuration File Location](#configuration-file-location)
- [Basic Configuration Structure](#basic-configuration-structure)
- [Configuration Options Reference](#configuration-options-reference)
- [Advanced Configuration](#advanced-configuration)
- [Complete Configuration Examples](#complete-configuration-examples)
- [Configuration Validation](#configuration-validation)
- [Loading Configuration](#loading-configuration)
- [Testing Configuration](#testing-configuration)
- [Team Workflow](#team-workflow)
- [Integration with Tools](#integration-with-tools)
- [FAQ](#faq)

## Configuration File Location

Place in project root as `.commitmsgrc.md`:
```
project-root/
├── .commitmsgrc.md       ← Config file here
├── .git/
├── src/
└── package.json
```

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

**Purpose:** Define allowed commit types

**Default:** `[feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert]`

**Example:**
```yaml
types:
  - feat
  - fix
  - docs
  - chore
```

**Validation:** Only listed types are valid

### scopes

**Purpose:** Define allowed scopes

**Default:** `[]` (empty = any scope allowed, scopes are inferred)

**Example:**
```yaml
scopes:
  - api
  - auth
  - ui
  - db
```

**Behavior:**
- If empty: Scopes are optional and inferred from file paths
- If specified: Only listed scopes are allowed

### require_scope

**Purpose:** Make scope mandatory

**Default:** `false`

**Example:**
```yaml
require_scope: true
scopes:
  - api
  - auth
```

**Effect:** Commit must include one of the allowed scopes

### required_ticket_format

**Purpose:** Enforce ticket/issue reference format

**Default:** `""` (empty = optional)

**Format:** Regular expression pattern

**Examples:**
```yaml
# JIRA tickets: JIRA-123, PROJ-456
required_ticket_format: "[A-Z]+-\\d+"

# GitHub issues: #123, #456
required_ticket_format: "#\\d+"

# Flexible format: Refs: TICKET-123
required_ticket_format: "Refs: [A-Z]+-\\d+"
```

**Validation:** Footer must contain matching pattern

### breaking_change_marker

**Purpose:** Define symbol for breaking changes

**Default:** `"!"`

**Example:**
```yaml
breaking_change_marker: "!"
```

**Usage:** `feat(api)!: change endpoint`

### max_subject_length

**Purpose:** Maximum subject line length

**Default:** `72`

**Example:**
```yaml
max_subject_length: 50  # Stricter limit
```

### min_subject_length

**Purpose:** Minimum subject line length

**Default:** `10`

**Example:**
```yaml
min_subject_length: 15  # Require more descriptive subjects
```

### require_imperative

**Purpose:** Enforce imperative mood in subject

**Default:** `true`

**Example:**
```yaml
require_imperative: true
```

**Effect:** Reject "added", "adds", accept "add"

### require_lowercase_subject

**Purpose:** Enforce lowercase subject (after type/scope)

**Default:** `true`

**Example:**
```yaml
require_lowercase_subject: true
```

**Effect:** `feat: add feature` ✓, `feat: Add feature` ✗

### forbid_period

**Purpose:** Forbid period at end of subject

**Default:** `true`

**Example:**
```yaml
forbid_period: true
```

**Effect:** `fix: resolve issue` ✓, `fix: resolve issue.` ✗

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

**Purpose:** Additional validation constraints

#### require_body_for_types

**Example:**
```yaml
custom_rules:
  require_body_for_types:
    - feat
    - fix
```

**Effect:** These types must include commit body

#### require_breaking_change_footer

**Example:**
```yaml
custom_rules:
  require_breaking_change_footer: true
```

**Effect:** If `!` marker present, BREAKING CHANGE footer is mandatory

#### max_files_without_scope

**Example:**
```yaml
custom_rules:
  max_files_without_scope: 5
```

**Effect:** If > 5 files changed, scope is required

## Complete Configuration Examples

### Minimal Open Source Project

```yaml
---
types:
  - feat
  - fix
  - docs
  - refactor
  - test
  - chore

required_ticket_format: "#\\d+"
max_subject_length: 72
---
```

### Strict Enterprise Configuration

```yaml
---
types:
  - feat
  - fix
  - docs
  - refactor
  - test

scopes:
  - api
  - auth
  - billing
  - reporting
  - ui
  - db

require_scope: true
required_ticket_format: "JIRA-\\d+"
max_subject_length: 50
min_subject_length: 15

custom_rules:
  require_body_for_types:
    - feat
    - fix
  require_breaking_change_footer: true
  max_files_without_scope: 3

type_aliases:
  feature: feat
  bugfix: fix
  hotfix: fix

scope_aliases:
  authentication: auth
  database: db

exempt_patterns:
  - "^Merge "
  - "^Bump version"
---
```

### Flexible Team Configuration

```yaml
---
types:
  - feat
  - fix
  - docs
  - style
  - refactor
  - perf
  - test
  - build
  - ci
  - chore

scopes: []  # Inferred from file paths

required_ticket_format: ""  # Optional tickets
max_subject_length: 72
min_subject_length: 10

require_imperative: true
require_lowercase_subject: true
forbid_period: true

custom_rules:
  require_breaking_change_footer: true

exempt_patterns:
  - "^Merge "
  - "^Revert "
  - "^Initial commit$"
---
```

### Monorepo Configuration

```yaml
---
types:
  - feat
  - fix
  - docs
  - refactor
  - test
  - build
  - chore

# Use package names as scopes
scopes:
  - core
  - ui-components
  - api-client
  - utils
  - shared-types
  - docs-site

require_scope: true  # All commits must specify package

required_ticket_format: "Refs: [A-Z]+-\\d+"
max_subject_length: 72

custom_rules:
  require_body_for_types:
    - feat
  require_breaking_change_footer: true

scope_aliases:
  components: ui-components
  api: api-client
  types: shared-types
  documentation: docs-site
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
Using default conventional commits configuration.
To customize, create .commitmsgrc.md in project root.
```

**Invalid YAML:**
```
Warning: .commitmsgrc.md contains invalid YAML.
Using default configuration.

Error: unexpected character at line 3
```

**Invalid values:**
```
Warning: Invalid value for 'max_subject_length': "abc"
Expected number. Using default: 72
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

### 1. Create Configuration

```bash
# Copy template
cp plugins/git-workflow/commit-message-generator/skills/commit-message-generating/commitmsgrc-template.md .commitmsgrc.md

# Edit for your project
vim .commitmsgrc.md
```

### 2. Commit Configuration

```bash
git add .commitmsgrc.md
git commit -m "chore: add conventional commit configuration"
git push
```

### 3. Team Adoption

Team members pull the configuration:
```bash
git pull
```

Configuration is automatically detected and enforced.

### 4. Update Configuration

```bash
# Edit config
vim .commitmsgrc.md

# Commit changes
git add .commitmsgrc.md
git commit -m "chore: update commit message rules"
git push
```

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

**Q: Do I need `.commitmsgrc.md`?**
A: No, it's optional. Defaults work for most projects.

**Q: Can I use both `.commitmsgrc.md` and commitlint?**
A: Yes, keep them in sync for consistent validation.

**Q: What if team members don't have the plugin?**
A: Config still works with other tools. Plugin users get enhanced features.

**Q: How do I share config across monorepo packages?**
A: Place `.commitmsgrc.md` in monorepo root, all packages inherit.

**Q: Can I require tickets only for certain types?**
A: Not directly supported yet. Use `required_ticket_format` globally or omit for flexibility.
