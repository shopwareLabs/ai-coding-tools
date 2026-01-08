# Conventional Commit Configuration

Project-specific commit message rules. Copy to your project root as `.commitmsgrc.md`.

## Configuration

```yaml
---
# Allowed commit types (required)
types:
  - feat      # New feature
  - fix       # Bug fix
  - docs      # Documentation
  - style     # Code formatting (no logic change)
  - refactor  # Code restructuring
  - perf      # Performance improvement
  - test      # Tests
  - build     # Build/dependencies
  - ci        # CI/CD
  - chore     # Maintenance
  - revert    # Revert previous commit

# Allowed scopes (optional - if empty, inferred from file paths)
scopes:
  - api
  - auth
  - ui
  - db

# Require scope in all commits (default: false)
require_scope: false

# Ticket reference format regex (optional)
# required_ticket_format: "JIRA-\\d+"    # JIRA-123
# required_ticket_format: "#\\d+"         # #123

# Maximum subject line length (default: 72)
max_subject_length: 72

# Require body for breaking changes (default: true)
require_body_for_breaking: true

# Add attribution footer to generated messages (default: false)
add_attribution_footer: false
---
```

## Quick Start Examples

### Minimal

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

### Strict Enterprise

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
---
```

### Open Source

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
  - revert

required_ticket_format: "#\\d+"
add_attribution_footer: true
---
```

## Valid Commits

```
feat(api): add user registration endpoint

Implements POST /api/users with validation.

Refs: JIRA-123
```

```
fix(auth): resolve token expiration bug
```

```
docs: update README
```

## Invalid Commits

```
Added new feature
```
Missing type and conventional format

```
feat(api)!: change authentication
```
Breaking change marker without BREAKING CHANGE footer

## Integration

```bash
cp .commitmsgrc-template.md .commitmsgrc.md
# Edit for your project
git add .commitmsgrc.md
git commit -m "chore: add commit message configuration"
```
