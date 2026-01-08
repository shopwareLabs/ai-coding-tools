# Consistency Validation

Validate that commit messages accurately describe code changes.

## Validation Dimensions

1. **Type** - Does type match change nature?
2. **Scope** - Does scope match changed files?
3. **Subject** - Does subject describe what changed?
4. **Breaking** - Are breaking changes marked?
5. **Body** - Present when needed? Explains WHY?

## Common Inconsistencies

| Issue | Example | Fix |
|-------|---------|-----|
| Type mismatch | `fix: add feature` | `feat: add feature` |
| Wrong scope | `feat(auth): add API endpoint` | `feat(api): add endpoint` |
| Vague subject | `fix: fix bug` | `fix(cache): resolve memory leak` |
| Missing `!` | `refactor(api): change endpoints` + BREAKING | `refactor(api)!: change endpoints` |
| Missing footer | `feat(api)!: change auth` (no BREAKING CHANGE) | Add BREAKING CHANGE footer |

## Type Validation

- **feat** → New functionality, endpoints, features
- **fix** → Corrects wrong behavior, patches bugs
- **docs** → Documentation only
- **style** → Code formatting (no logic change)
- **refactor** → Code restructuring, no behavior change
- **perf** → Performance optimization
- **test** → Test changes only
- **build** → Build system, dependencies
- **ci** → CI/CD configuration
- **chore** → Maintenance tasks
- **revert** → Revert previous commit

## Breaking Change Rules

Mark as breaking when:
- API signature changes (params added/removed)
- Public methods removed/renamed
- Return types changed
- URL/endpoint paths changed

NOT breaking:
- Optional parameters added
- New methods (additive)
- Internal changes

## Severity Levels

- **FAIL**: Wrong type, unmarked breaking change, completely wrong subject
- **WARN**: Scope too broad, subject vague, minor ambiguity
- **PASS**: Minor wording, acceptable omissions
