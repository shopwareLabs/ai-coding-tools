# Complete Examples

## Contents
- [Generation](#generation-examples) | [Validation](#validation-examples) | [Edge Cases](#edge-cases) | [Workflows](#using-examples-in-workflows)

## Generation Examples

### Ex1: New Feature Generation (User adds new authentication service)

```
A  src/auth/JwtService.ts
M  src/auth/AuthController.ts
```

**Workflow:**
→ Get staged changes (2 files)
→ Analyze diff (new JwtService.ts, modified AuthController.ts)
→ Type: `feat` | Scope: `auth` | Breaking: No
→ Subject: "add JWT token generation service"
→ Body: Motivation and implementation details

**Generated message:**
```
feat(auth): add JWT token generation service

Implements JWT token creation with configurable expiration.
Uses HS256 algorithm with secret from environment.
```

### Ex2: Bug Fix Generation (User fixes authentication bug)

```diff
M  src/auth/LoginService.ts
- if (user.age > 18) {
+ if (user.age >= 18) {
```

**Workflow:**
→ Get staged changes (1 file)
→ Analyze diff (logic fix in conditional)
→ Type: `fix` | Scope: `auth`
→ Subject: "correct age validation boundary"

**Generated message:**
```
fix(auth): correct age validation boundary

Allows 18-year-olds to register (was incorrectly requiring >18).
```

### Ex3: Breaking Change Generation (User migrates API endpoints)

```diff
M  src/api/routes.ts
- app.get('/api/user/:id', handler)
+ app.get('/api/v2/users/:id', handler)
```

**Workflow:**
→ Get staged changes (1 file)
→ Analyze diff (API endpoint path changed)
→ Type: `refactor` | Scope: `api` | Breaking: YES
→ Subject: "migrate user endpoints to v2"
→ Add BREAKING CHANGE footer

**Generated message:**
```
refactor(api)!: migrate user endpoints to v2

BREAKING CHANGE: User endpoints moved from /api/user to /api/v2/users.
Update client requests to new endpoint paths.
```

### Ex4: Multi-Scope Changes (Changes span multiple modules, requires user input)

```
M  src/auth/LoginService.ts
M  src/api/UserController.ts
M  tests/auth.test.ts
```

**Workflow:**
→ Get staged changes (3 files in auth/, api/, tests/)
→ Type: `feat` | Scope: AMBIGUOUS
→ **Ask user**: "Choose scope (auth/api/tests) or omit?"
→ User selects: "api"
→ Craft subject with selected scope

**Generated message:**
```
feat(api): add user profile update endpoint

Implements PUT /api/users/:id with validation.
Includes authentication check and tests.
```

## Validation Examples

### Ex5: Successful Validation (Validate well-formed commit)

**Commit:** `abc123f`
**Message:** `fix(api): resolve token expiration bug`

**Workflow:**
→ Get commit message and diff
→ Parse: type=fix, scope=api
→ Format check: ✓ (type, scope, subject valid)
→ Consistency check: ✓ (type matches changes, scope accurate, subject precise)

**Validation report:**
```
Validation Report (abc123f)
============================
Message: fix(api): resolve token expiration bug
Format Compliance: ✓ PASS
Consistency Check: ✓ PASS
Result: ✓ Well-formed and accurate
```

### Ex6: Failed Validation - Type Mismatch (Commit message doesn't match actual changes)

**Commit:** `def456a`
**Message:** `fix: update authentication`

**Actual changes:** New OAuth2 implementation (adds new files and endpoints)

**Workflow:**
→ Get commit message and diff
→ Parse: type=fix, no scope
→ Format check: ✓ PASS
→ Consistency check: ✗ FAIL
  - Type mismatch (should be `feat`)
  - Missing scope (recommend `auth`)
  - Subject too vague

**Validation report:**
```
Commit Message Validation Report
=================================

Commit: def456a
Message: "fix: update authentication"

Format Compliance: ✓ PASS
  ✓ Valid type: fix
  ✓ Subject format correct

Consistency Check: ✗ FAIL
  ✗ Type mismatch: Changes add new /auth/oauth endpoint, should be 'feat' not 'fix'
  ⚠ Missing scope: Consider 'auth' scope
  ⚠ Subject too vague: Doesn't specify what was updated

Recommendations:
  1. Change type from 'fix' to 'feat' (new endpoint added)
  2. Add scope: 'feat(auth)'
  3. Be specific: "add OAuth2 authentication" instead of "update authentication"

Suggested message:
feat(auth): add OAuth2 authentication support
```

### Ex7: Format Violation (Commit doesn't follow conventional commits format)

**Commit:** `ghi789b`
**Message:** `Added new login feature.`

**Workflow execution:**
1. Attempt to parse message
2. Format check: ✗ FAIL
   - ✗ No type prefix
   - ✗ Past tense instead of imperative
   - ✗ Ends with period

**Validation report:**
```
Commit Message Validation Report
=================================

Commit: ghi789b
Message: "Added new login feature."

Format Compliance: ✗ FAIL
  ✗ Missing type (should start with feat, fix, etc.)
  ✗ Uses past tense 'Added' instead of imperative 'add'
  ✗ Subject ends with period

Consistency Check: SKIPPED (format must pass first)

Recommendations:
  1. Add type prefix based on changes
  2. Use imperative mood: 'add' not 'Added'
  3. Remove trailing period
  4. Consider adding scope if changes are scoped

Suggested message:
feat(auth): add login feature
```

### Ex8: Missing Breaking Change Marker (Breaking change not marked in message)

**Commit:** `jkl012c`
**Message:** `refactor(api): update authentication endpoint`

**Actual changes:** Endpoint path changed from `/auth` to `/auth/v2` (breaking)

**Workflow execution:**
1. Parse message: type=refactor, scope=api
2. Format compliance: ✓ PASS
3. Consistency check:
   - ⚠ Type acceptable (refactor for restructuring)
   - ✓ Scope accurate
   - ✗ Breaking change not marked (should have `!` and BREAKING CHANGE footer)

**Validation report:**
```
Commit: jkl012c
Message: "refactor(api): update authentication endpoint"

Format Compliance: ✓ PASS
  ✓ Valid type: refactor
  ✓ Scope format: api
  ✓ Subject format correct

Consistency Check: ⚠ WARN
  ✓ Type matches changes (code restructuring)
  ✓ Scope accurate
  ✗ Breaking change not marked: Endpoint path changed (breaking for clients)

Recommendations:
  1. Add breaking change marker: 'refactor(api)!'
  2. Add BREAKING CHANGE footer explaining migration
  3. Document new endpoint path

Suggested message:
refactor(api)!: migrate authentication to v2 endpoint

BREAKING CHANGE: Authentication endpoint moved from /auth to /auth/v2.
Update API clients to use new endpoint path.
```

## Edge Cases

### Ex9: Revert Commit

**Message:** `revert: feat(auth): add OAuth2 support` with footer explaining reason

**Type:** `revert` (special type for reverts)

### Ex10: Documentation-Only Changes

**Message:** `docs: update API documentation` (no scope; docs are cross-cutting)

**Type:** `docs` (no code changes)

### Ex11: Mixed Change Types (User Guidance Needed)

```
M  src/auth/LoginService.ts  (bug fix)
A  src/auth/OAuthService.ts  (new feature)
M  tests/auth.test.ts        (tests)
```

**Workflow:** Detects mixed types (fix + feat + test), asks user to select primary type, user chooses 'feat'

**Generated message:**
```
feat(auth): add OAuth2 support and fix login bug

Implements OAuth2 authentication with Google provider.
Also resolves token validation bug in existing login flow.
```

**Recommendation to user:** "Consider splitting into two commits: one feat, one fix"

## Common Mistakes to Avoid

### Mistake 1: Wrong Tense (Not Imperative)

**❌ WRONG:** `Added new login feature` | `Adds OAuth2 support` | `Fixed memory leak`

**✅ CORRECT:** `feat(auth): add login feature` | `feat(auth): add OAuth2 support` | `fix(memory): fix memory leak`

**Why:** Imperative mood makes messages actionable, not descriptive.

### Mistake 2: Vague Subject Line

**❌ WRONG:** `feat: add feature` | `fix: fix bug` | `refactor: update code` | `docs: fix typo`

**✅ CORRECT:** `feat(auth): add OAuth2 authentication support` | `fix(cache): resolve memory leak in LRU cache` | `refactor(api): extract validation logic to service` | `docs(README): add installation instructions`

**Why:** Specific descriptions enable git history searching and clarity.

### Mistake 3: Missing Breaking Change Marker

**❌ WRONG:**
```
refactor(api): migrate user endpoints

BREAKING CHANGE: User endpoints moved from /api/user to /api/v2/users.
```

**✅ CORRECT:**
```
refactor(api)!: migrate user endpoints to v2

BREAKING CHANGE: User endpoints moved from /api/user to /api/v2/users.
Update clients to use new endpoint paths.
```

**Why:** The `!` marker is required for automated changelog generators to detect breaking changes.

### Mistake 4: No Scope When Changes Are Scoped

**❌ WRONG:**
```
feat: add JWT authentication

Changes only in src/auth/ directory.
```

**✅ CORRECT:**
```
feat(auth): add JWT authentication

Changes only in src/auth/ directory.
```

**Why:** Scope identifies affected system areas and enables history filtering.

### Mistake 5: Inconsistent Type Selection

**❌ WRONG:**
```
# Changed parameter type (breaking) but marked as refactor
refactor(api): update parameter types

# Actually added new feature but marked as fix
fix(api): add user registration endpoint

# Only improved performance but marked as feat
feat(cache): add LRU caching
```

**✅ CORRECT:**
```
# Changed parameter type (breaking)
refactor(api)!: update parameter types to match spec

# Added new feature
feat(api): add user registration endpoint

# Improved performance
perf(cache): add LRU caching strategy
```

**Why:** Correct types enable semantic versioning, automated changelogs, and clear history.

### Mistake 6: Too Long Subject Line

**❌ WRONG (90 chars - exceeds limit):**
```
feat(auth): implement JWT authentication with refresh token rotation and multiple provider support
```

**✅ CORRECT (44 chars - concise):**
```
feat(auth): add JWT authentication with refresh tokens

Implements JWT token generation and refresh rotation.
Supports multiple OAuth2 providers (Google, GitHub, Facebook).
```

**Why:** Readable subjects in git logs; use body for details.

### Mistake 7: Subject Ending with Period

**❌ WRONG:**
```
feat(auth): add authentication.
fix(api): resolve timeout bug.
docs: update README.
```

**✅ CORRECT:**
```
feat(auth): add authentication
fix(api): resolve timeout bug
docs: update README
```

**Why:** Style consistency per Conventional Commits spec.

### Mistake 8: Missing Motivation in Body

**❌ WRONG:**
```
perf(db): optimize user query
```

**✅ CORRECT:**
```
perf(db): optimize user query with indexing

Added composite index on (email, status) columns which is the most
common query pattern in authentication flow.

Benchmark: Query time reduced from 450ms to 67ms (85% improvement).
```

**Why:** Body explains WHY, not WHAT (code shows that), helping maintainers understand decisions.

## Using Examples in Workflows

**Load when:**
- User requests examples or guidance
- Output format uncertain
- Teaching conventional commits or correcting mistakes

**Skip for:** Routine generation, high-confidence operations
