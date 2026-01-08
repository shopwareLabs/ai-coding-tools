# Examples

Quick reference examples for generation and validation.

## Generation

### New Feature
```
feat(auth): add JWT token generation service

Implements JWT token creation with configurable expiration.
Uses HS256 algorithm with secret from environment.
```

### Bug Fix
```
fix(auth): correct age validation boundary

Allows 18-year-olds to register (was incorrectly requiring >18).
```

### Breaking Change
```
refactor(api)!: migrate user endpoints to v2

BREAKING CHANGE: User endpoints moved from /api/user to /api/v2/users.
Update client requests to new endpoint paths.
```

### Performance
```
perf(db): optimize user query with indexing

Added composite index on (email, status) columns.
Query time reduced from 450ms to 67ms (85% improvement).
```

## Validation Reports

### Pass
```
Commit: abc123f
Message: "fix(api): resolve token expiration bug"

Format Compliance: PASS ✓
Consistency Check: PASS ✓
```

### Fail - Type Mismatch
```
Commit: def456a
Message: "fix: update authentication"

Format Compliance: PASS ✓
Consistency Check: FAIL ✗
  ✗ Type mismatch: New endpoint added, should be 'feat'

Recommendations:
  1. Change type from 'fix' to 'feat'
```

## Common Mistakes

| Mistake | Wrong | Correct |
|---------|-------|---------|
| Wrong tense | `Added feature` | `add feature` |
| Vague subject | `fix: fix bug` | `fix(cache): resolve memory leak` |
| Missing `!` | `refactor(api): change endpoints` + BREAKING footer | `refactor(api)!: change endpoints` |
| Ends with period | `feat: add auth.` | `feat: add auth` |
| Too long | 90+ char subject | 50-72 chars, details in body |
