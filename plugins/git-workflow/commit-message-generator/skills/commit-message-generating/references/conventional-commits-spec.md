# Conventional Commits Specification

Complete reference for the Conventional Commits specification v1.0.0.

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

**Rules:**
- MUST be lowercase
- MUST be one of the allowed types
- MUST be followed by `(scope):` or `:` and space

### Scope (Optional)

**Examples:** `feat(api): add endpoint`, `fix(auth): resolve login timeout`, `docs(readme): update installation steps`

**Rules:**
- MUST be noun describing section of codebase
- MUST be lowercase
- MUST use kebab-case for multi-word scopes
- MUST be enclosed in parentheses
- MAY be omitted if change affects multiple scopes

**Example scopes:**
- Web: `api`, `auth`, `ui`, `db`, `config`, `middleware`
- Library: `core`, `utils`, `types`, `exports`
- Monorepo: `package-name`

### Breaking Change Marker (Optional)

**Examples:** `feat(api)!: change authentication to OAuth2`, `refactor!: rename User class`

**Rules:**
- MUST be `!` character
- MUST be placed after type or scope, before `:`
- MUST be accompanied by BREAKING CHANGE in footer

### Subject (Required)

**Rules:**
- MUST be lowercase (first character after space)
- MUST use imperative mood ("add" not "added" or "adds")
- MUST NOT end with a period
- SHOULD be 50 characters or less
- MUST be under 72 characters
- MUST be preceded by type and colon + space

**Correct:** `add user authentication`, `fix memory leak in parser`, `remove deprecated API endpoints`

**Incorrect:** "Added authentication" (past tense), "Adds feature" (present), "subject." (period), "Authentication" (non-imperative)

### Body (Optional)

**When to include:**
- Complex changes requiring explanation
- Motivation for the change
- Contrast with previous behavior
- Migration instructions

**Rules:**
- MUST be separated from subject by blank line
- MAY contain multiple paragraphs
- SHOULD wrap at 72 characters per line
- SHOULD explain WHY, not WHAT (code shows what)

**Example:**
```
feat(cache): implement Redis-based session storage

Previous file-based sessions caused performance issues with multiple
application instances. Redis provides shared session storage and
automatic expiration handling.

Migration: Update SESSION_DRIVER in .env to 'redis'.
```

### Footer (Optional)

**Common footers:** `BREAKING CHANGE:` (breaking change), `Refs:` (related tickets), `Closes:` (closed issues), `Co-authored-by:` (additional authors)

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

**Common imperative verbs:**
- add, remove, delete
- fix, resolve, correct
- update, change, modify
- implement, introduce
- refactor, extract, move
- improve, optimize, enhance
- document, clarify, explain
- test, verify, validate

### Length Validation

**Subject:**
- Recommended: ≤ 50 characters
- Maximum: ≤ 72 characters
- Minimum: ≥ 10 characters (to ensure meaningful description)

**Body lines:**
- Recommended: ≤ 72 characters per line
- Allows for readability in terminal and git log

**Total message:**
- No hard limit, but keep concise

### Breaking Change Validation

**If `!` marker is present:**
- MUST have `BREAKING CHANGE:` in footer
- Footer MUST describe what broke and migration path

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

### Merge Commits
Merge commits MAY be exempt: `Merge branch 'feature/auth' into main`

### Revert Commits
Use `revert:` type: `revert: feat(api): add endpoint` with reverting commit message

### Initial Commits
Exempt: `Initial commit` or `chore: initialize repository`

### Multi-scope Changes
When affecting multiple scopes:
1. Omit scope: `refactor: reorganize authentication logic`
2. Use broader scope: `refactor(auth): reorganize login and registration`
3. Multiple commits (preferred): Separate commits with specific scopes

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
