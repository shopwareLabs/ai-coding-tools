# Custom Rules Configuration

Configure project-specific rules via `.commitmsgrc.md` in project root.

## Configuration Options

```yaml
---
# Required: Allowed commit types (example subset - see commitmsgrc-template.md for all 11 types)
types: [feat, fix, docs, refactor, test, chore]

# Optional: Allowed scopes (empty = infer from files)
scopes: [api, auth, ui, db]

# Optional: Require scope in all commits
require_scope: false

# Optional: Ticket reference pattern (regex)
required_ticket_format: "JIRA-\\d+"

# Optional: Subject line max length (default: 72)
max_subject_length: 72

# Optional: Require body for breaking changes (default: true)
require_body_for_breaking: true
---
```

## Example Configurations

### Minimal
```yaml
---
types: [feat, fix, docs, refactor, test, chore]
---
```

### Enterprise
```yaml
---
types: [feat, fix, docs, refactor, test]
scopes: [api, auth, billing, ui]
require_scope: true
required_ticket_format: "JIRA-\\d+"
max_subject_length: 50
---
```

### Open Source
```yaml
---
types: [feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert]
required_ticket_format: "#\\d+"
---
```

## Loading Behavior

1. Check for `.commitmsgrc.md` in project root
2. Parse YAML frontmatter
3. Apply custom rules (or defaults if missing/invalid)
4. Warn on invalid config, continue with defaults
