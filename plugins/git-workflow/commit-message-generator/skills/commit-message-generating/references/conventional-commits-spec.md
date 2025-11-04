# Conventional Commits Specification

Reference for Conventional Commits specification v1.0.0.

## Table of Contents

- [Format](#format)
- [Components](#components)
  - [Type (Required)](#type-required)
  - [Scope (Optional)](#scope-optional)
  - [Breaking Change Marker (Optional)](#breaking-change-marker-optional)
  - [Subject (Required)](#subject-required)
  - [Body (Optional)](#body-optional)
  - [Footer (Optional)](#footer-optional)
- [Complete Examples](#complete-examples)
- [Validation Rules](#validation-rules)
- [Edge Cases](#edge-cases)
- [Anti-patterns](#anti-patterns)
- [References](#references)

## Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

## Components

### Type (Required)

**Standard types:**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `style` - Format/whitespace changes
- `refactor` - Code refactoring
- `perf` - Performance improvement
- `test` - Test additions/corrections
- `build` - Build system/dependency changes
- `ci` - CI configuration changes
- `chore` - Other non-code changes
- `revert` - Revert previous commit

**Rules:** Lowercase; one of allowed types; followed by `(scope):` or `:` + space

### Scope (Optional)

**Examples:** `feat(api): add endpoint`, `fix(auth): resolve login timeout`, `docs(readme): update installation steps`

**Rules:** Noun describing codebase section; lowercase; kebab-case for multi-word; parentheses required; omit if multi-scope

**Example scopes:**
- Web: `api`, `auth`, `ui`, `db`, `config`, `middleware`
- Library: `core`, `utils`, `types`, `exports`
- Monorepo: `package-name`

### Breaking Change Marker (Optional)

**Examples:** `feat(api)!: change authentication to OAuth2`, `refactor!: rename User class`

**Rules:** Character `!`; placed after type or scope before `:`; must include BREAKING CHANGE footer

### Subject (Required)

**Rules:**
- MUST be lowercase (first character after space)
- MUST use imperative mood ("add" not "added" or "adds")
- MUST NOT end with a period
- SHOULD be 50 characters or less
- MUST be under 72 characters
- MUST be preceded by type and colon + space

✓ `add user authentication`, `fix memory leak in parser`, `remove deprecated API endpoints`

✗ "Added authentication" (past), "Adds feature" (present), "subject." (period), "Authentication" (non-imperative)

### Body (Optional)

**Include for:**
- Complex changes
- Motivation/reasoning
- Behavior changes
- Migrations

**Rules:**
- MUST be separated from subject by blank line
- MAY contain multiple paragraphs
- SHOULD wrap at 72 characters per line
- Explain WHY, not WHAT (code shows what)

**Example:**
```
feat(cache): implement Redis-based session storage

Previous file-based sessions caused performance issues with multiple
application instances. Redis provides shared session storage and
automatic expiration handling.

Migration: Update SESSION_DRIVER in .env to 'redis'.
```

### Body Quality Guidelines

**Explain WHY, not WHAT:**

❌ `Added RateLimiter class with check() method. Implemented sliding window algorithm.`

✓ `API vulnerable to abuse (1000+ req/s). Sliding window prevents abuse while allowing legitimate burst traffic.`

**Provide Context:**

❌ `Made queries faster.`

✓ `N+1 query problem (2-3s load time). Eager loading user.posts reduces queries 100+→2, achieving <200ms load.`

**Include Migration for Breaking Changes:**

✓ Required for breaking changes:
```
feat(api)!: migrate to v2 endpoint structure

BREAKING CHANGE: API endpoints moved from /api/resource to /v2/resource.

Migration:
1. Update base URL from example.com/api to example.com/v2
2. Review endpoint changes in MIGRATION.md
3. Update authentication headers (now requires Bearer token)
4. Test in staging environment before deploying

Before: GET /api/users/{id}
After:  GET /v2/users/{id}
```

### Footer (Optional)

**Common footers:** `BREAKING CHANGE:`, `Refs:`, `Closes:`, `Co-authored-by:`

**Rules:**
- MUST be separated from body (or subject if no body) by blank line
- MUST use `key: value` or `KEY: value` format
- `BREAKING CHANGE` MUST be uppercase
- MAY contain multiple footer tokens

**Example:**
```
feat(api)!: change authentication endpoint

BREAKING CHANGE: /auth/login now requires OAuth2 instead of username/password.
Migration guide: https://docs.example.com/oauth-migration

Refs: JIRA-123
Closes: #456
Co-authored-by: Jane Doe <jane@example.com>
```

## Complete Examples

### Minimal Commit

```
fix: resolve null pointer exception
```

### With Scope

```
feat(api): add user registration endpoint
```

### With Body

```
refactor(auth): extract token generation to service

Token generation logic was duplicated across login and refresh
endpoints. Extracting to dedicated service improves maintainability
and makes testing easier.
```

### With Breaking Change

```
feat(api)!: migrate to v2 authentication

BREAKING CHANGE: Authentication now uses JWT tokens instead of session
cookies. Clients must update to include Authorization header with
Bearer token.

Migration:
1. Request token from /api/v2/auth/token
2. Include in requests: Authorization: Bearer <token>
3. Refresh tokens using /api/v2/auth/refresh

Refs: JIRA-789
```

### Multi-paragraph Body with Footers

```
perf(db): optimize user query with indexing

Added composite index on (email, status) columns for user table.
This is the most common query pattern in authentication flow.

Benchmark results show 85% reduction in query time:
- Before: 450ms average
- After: 67ms average

Query plan now uses index seek instead of table scan.

Refs: PERF-234
```

### Revert Commit

```
revert: feat(api): add user registration endpoint

This reverts commit abc123def456.

Registration endpoint had security vulnerability. Reverting until
proper input validation is implemented.

Refs: SEC-789
```

## Validation Rules

### Format Validation

**Valid patterns:** `type: subject`, `type(scope): subject`, `type!: subject`, `type(scope)!: subject`

**Invalid:** `Type: subject` (caps), `type(scope) : subject` (space before :), `type(scope): Subject` (caps subject), `type(scope): subject.` (period)

### Subject Validation

**Imperative mood check:**
- Correct: "add feature", "fix bug", "remove deprecated code"
- Incorrect: "added feature", "adding feature", "adds feature", "feature addition"

**Common verbs:** add/remove/delete, fix/resolve/correct, update/change/modify, implement/introduce, refactor/extract/move, improve/optimize/enhance, document/clarify/explain, test/verify/validate

### Length Validation

**Limits:** Subject (recommend ≤50 chars, max ≤72, min ≥10), Body lines (≤72 chars/line), Total message (no hard limit, keep concise)

### Breaking Change Validation

**If `!` marker present:**
- MUST have `BREAKING CHANGE:` footer
- MUST describe what broke + migration path

**Example validation:**
```
feat(api)!: change response format

✗ FAIL: Missing BREAKING CHANGE footer
```

```
feat(api)!: change response format

BREAKING CHANGE: API responses now use snake_case instead of camelCase

✓ PASS: Breaking change properly documented
```

## Edge Cases

### Special Cases

| Case | Format |
|------|--------|
| Merge commits | Exempt: `Merge branch 'feature/auth' into main` |
| Revert commits | Use `revert:` type: `revert: feat(api): add endpoint` |
| Initial commits | Exempt: `Initial commit` or `chore: initialize repository` |
| Multi-scope changes | (1) Omit scope, (2) Use broader scope, or (3) Multiple specific commits (preferred) |

## Anti-patterns

### Too Vague

```
fix: fix bug
update: update code
chore: changes
```

**Better:**
```
fix: resolve race condition in file upload
refactor: extract duplicate validation logic
chore: update dependencies to latest versions
```

### Wrong Type

```
fix: add new feature
```
Should be `feat:`

```
feat: fix typo in documentation
```
Should be `docs:` or `fix(docs):`

### Non-imperative

```
feat: added authentication
feat: adding authentication
feat: authentication added
```

**Correct:**
```
feat: add authentication
```

### Too Long

```
feat: this commit adds a new feature that allows users to authenticate using OAuth2 with support for multiple providers including Google, GitHub, and Facebook
```

**Better:**
```
feat(auth): add OAuth2 multi-provider support

Implements OAuth2 authentication with Google, GitHub, and Facebook
providers. Users can link multiple providers to single account.
```

## References

- Official Specification: https://www.conventionalcommits.org/
- Semantic Versioning: https://semver.org/
- Angular Commit Guidelines: https://github.com/angular/angular/blob/main/CONTRIBUTING.md
