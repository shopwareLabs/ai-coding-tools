# Conventional Commit Configuration

This file configures commit message conventions for your project. Copy to your project root as `.commitmsgrc.md`.

## Configuration

```yaml
---
# Allowed commit types
types:
  - feat        # New feature
  - fix         # Bug fix
  - docs        # Documentation only
  - style       # Code style (formatting, semicolons, etc.)
  - refactor    # Code restructuring without behavior change
  - perf        # Performance improvement
  - test        # Adding or updating tests
  - build       # Build system or dependencies
  - ci          # CI/CD configuration
  - chore       # Maintenance tasks
  - revert      # Revert previous commit

# Allowed or required scopes (optional)
# If empty, scopes are inferred from changed files
# If specified, only listed scopes are allowed
scopes:
  - api
  - auth
  - ui
  - db
  - config
  - docs

# Require scope in all commits (default: false)
require_scope: false

# Ticket/issue reference format (regex pattern)
# If specified, commits must include matching reference in footer
# Leave empty to make optional
required_ticket_format: ""
# Examples:
# required_ticket_format: "JIRA-\\d+"           # Requires: JIRA-123
# required_ticket_format: "#\\d+"               # Requires: #123
# required_ticket_format: "Refs: [A-Z]+-\\d+"  # Requires: Refs: PROJ-456

# Breaking change marker (default: "!")
breaking_change_marker: "!"

# Maximum subject line length (default: 72)
max_subject_length: 72

# Minimum subject line length (default: 10)
min_subject_length: 10

# Require imperative mood in subject (default: true)
require_imperative: true

# Require lowercase subject (after type/scope) (default: true)
require_lowercase_subject: true

# Forbid period at end of subject (default: true)
forbid_period: true

# Custom type aliases (map aliases to standard types)
type_aliases:
  feature: feat
  bugfix: fix
  documentation: docs
  hotfix: fix

# Scope aliases (normalize scope names)
scope_aliases:
  authentication: auth
  database: db
  frontend: ui
  backend: api

# Exempt patterns (commits matching these patterns skip validation)
exempt_patterns:
  - "^Merge "
  - "^Revert "
  - "^Initial commit$"

# Custom validation rules (advanced)
custom_rules:
  # Require body for certain types
  require_body_for_types:
    - feat
    - fix
    - perf

  # Require breaking change footer when ! is used
  require_breaking_change_footer: true

  # Maximum changed files before scope is required
  max_files_without_scope: 5

---
```

## Quick Start Examples

### Minimal Configuration (Use Defaults)

```yaml
---
types:
  - feat
  - fix
  - docs
  - refactor
  - test
  - chore
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
  - ui

require_scope: true
required_ticket_format: "JIRA-\\d+"
max_subject_length: 50
require_body_for_types:
  - feat
  - fix
---
```

### Open Source Project Configuration

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

required_ticket_format: "#\\d+"  # Require GitHub issue reference
max_subject_length: 72
---
```

## Validation Examples

With the configuration above, these commits would be validated:

### Valid Commits

```
feat(api): add user registration endpoint

Implements POST /api/users with email validation.
Includes rate limiting and spam protection.

Refs: JIRA-123
```

```
fix(auth): resolve token expiration bug

Tokens were expiring 1 hour early due to timezone conversion.
Now correctly uses UTC timestamps.

Refs: #456
```

```
docs: update API documentation
```

### Invalid Commits (with explanations)

```
Added new feature
```
❌ Missing type and conventional format

```
feat: added new feature
```
❌ Wrong tense ("added" instead of "add")

```
feat(invalidscope): add feature
```
❌ Invalid scope (not in allowed list)

```
feat: add feature
```
❌ Missing required ticket reference

```
feat(api)!: change authentication

Changed auth to use OAuth2 tokens.
```
❌ Breaking change marker (!) without BREAKING CHANGE footer

## Integration

Place this file as `.commitmsgrc.md` in your project root:

```bash
# Copy template to project
cp .commitmsgrc-template.md .commitmsgrc.md

# Edit for your project
vim .commitmsgrc.md

# Commit the config
git add .commitmsgrc.md
git commit -m "chore: add conventional commit configuration"
```

The `commit-message-generating` skill will automatically detect and use this configuration.

## See Also

- Full specification: `references/conventional-commits-spec.md`
- Custom rules guide: `references/custom-rules.md`
- Type detection: See `../../agents/type-detector.md` and `../../references/type-detection.md`
- Scope detection: `references/scope-detection.md`
