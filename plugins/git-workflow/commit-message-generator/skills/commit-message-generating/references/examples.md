# Complete Examples

End-to-end examples demonstrating generation and validation workflows.

## Table of Contents

- [Generation Examples](#generation-examples)
- [Validation Examples](#validation-examples)
- [Edge Cases](#edge-cases)
- [Using Examples in Workflows](#using-examples-in-workflows)

## Generation Examples

### Example 1: New Feature Generation

**Scenario:** User adds new authentication service

**Staged changes:**
```
A  src/auth/JwtService.ts
M  src/auth/AuthController.ts
```

**Workflow execution:**
1. Get staged changes → 2 files detected
2. Analyze diff: New file `JwtService.ts`, modified `AuthController.ts` adds new endpoint
3. Determine type: `feat` (new functionality)
4. Infer scope: `auth` (all changes in src/auth/)
5. Detect breaking change: No
6. Craft subject: "add JWT token generation service"
7. Add body: Motivation and implementation details

**Generated message:**
```
feat(auth): add JWT token generation service

Implements JWT token creation with configurable expiration.
Uses HS256 algorithm with secret from environment.
```

**Confidence:** HIGH
**Self-validation:** ✓ PASS

---

### Example 2: Bug Fix Generation

**Scenario:** User fixes authentication bug

**Staged changes:**
```diff
M  src/auth/LoginService.ts
- if (user.age > 18) {
+ if (user.age >= 18) {
```

**Workflow execution:**
1. Get staged changes → 1 file modified
2. Analyze diff: Logic fix in conditional
3. Determine type: `fix` (bug correction)
4. Infer scope: `auth` (change in src/auth/)
5. Craft subject: "correct age validation boundary"

**Generated message:**
```
fix(auth): correct age validation boundary

Allows 18-year-olds to register (was incorrectly requiring >18).
```

**Confidence:** HIGH
**Self-validation:** ✓ PASS

---

### Example 3: Breaking Change Generation

**Scenario:** User migrates API endpoints

**Staged changes:**
```diff
M  src/api/routes.ts
- app.get('/api/user/:id', handler)
+ app.get('/api/v2/users/:id', handler)
```

**Workflow execution:**
1. Get staged changes → 1 file modified
2. Analyze diff: API endpoint path changed (breaking)
3. Determine type: `refactor` (code restructuring)
4. Infer scope: `api`
5. Detect breaking change: YES (endpoint path change)
6. Add breaking change marker: `!`
7. Craft subject: "migrate user endpoints to v2"
8. Add breaking change documentation in footer

**Generated message:**
```
refactor(api)!: migrate user endpoints to v2

BREAKING CHANGE: User endpoints moved from /api/user to /api/v2/users.
Update client requests to new endpoint paths.
```

**Confidence:** HIGH
**Self-validation:** ✓ PASS (breaking change properly marked)

---

### Example 4: Multi-Scope Changes (Requires User Input)

**Scenario:** Changes span multiple modules

**Staged changes:**
```
M  src/auth/LoginService.ts
M  src/api/UserController.ts
M  tests/auth.test.ts
```

**Workflow execution:**
1. Get staged changes → 3 files in different scopes
2. Analyze diff: Changes in auth/, api/, and tests/
3. Determine type: `feat` (new functionality across modules)
4. Attempt scope inference: AMBIGUOUS (multiple scopes)
5. **Ask user**: "Changes in: auth, api, tests. Choose scope or omit?"
6. User selects: "api"
7. Craft subject with user's scope choice

**Generated message:**
```
feat(api): add user profile update endpoint

Implements PUT /api/users/:id with validation.
Includes authentication check and tests.
```

**Confidence:** MEDIUM (scope user-selected)

---

## Validation Examples

### Example 5: Successful Validation

**Scenario:** Validate well-formed commit

**Commit:** `abc123f`
**Message:** `fix(api): resolve token expiration bug`

**Workflow execution:**
1. Get commit message and diff
2. Parse message: type=fix, scope=api, subject="resolve token expiration bug"
3. Format compliance check:
   - ✓ Valid type
   - ✓ Scope format correct
   - ✓ Subject format correct
4. Consistency check:
   - ✓ Type matches changes (bug fix in TokenService.ts)
   - ✓ Scope accurate (changes in src/api/)
   - ✓ Subject describes actual changes

**Validation report:**
```
Commit Message Validation Report
=================================

Commit: abc123f
Message: "fix(api): resolve token expiration bug"

Format Compliance: ✓ PASS
  ✓ Valid type: fix
  ✓ Scope format: api
  ✓ Subject format correct

Consistency Check: ✓ PASS
  ✓ Type matches changes (bug fix in token handling)
  ✓ Scope accurate (changes in src/api/)
  ✓ Subject describes changes precisely

Result: Message is well-formed and accurate.
```

---

### Example 6: Failed Validation - Type Mismatch

**Scenario:** Commit message doesn't match actual changes

**Commit:** `def456a`
**Message:** `fix: update authentication`

**Actual changes:** New OAuth2 implementation (adds new files and endpoints)

**Workflow execution:**
1. Get commit message and diff
2. Parse message: type=fix, no scope, subject="update authentication"
3. Format compliance: ✓ PASS
4. Consistency check:
   - ✗ Type mismatch: Changes add new functionality, should be `feat` not `fix`
   - ⚠ Missing scope: Could use `auth` scope
   - ⚠ Subject vague: Doesn't specify what was added

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

---

### Example 7: Format Violation

**Scenario:** Commit doesn't follow conventional commits format

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

---

### Example 8: Missing Breaking Change Marker

**Scenario:** Breaking change not marked in message

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
Commit Message Validation Report
=================================

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

---

## Edge Cases

### Example 9: Revert Commit

**Staged changes:**
```
Reverts commit abc123f
```

**Generated message:**
```
revert: feat(auth): add OAuth2 support

This reverts commit abc123f.

Reason: OAuth2 integration causing production issues.
```

**Type:** `revert` (special type for reverts)

---

### Example 10: Documentation-Only Changes

**Staged changes:**
```
M  README.md
M  docs/api.md
```

**Generated message:**
```
docs: update API documentation

Adds examples for authentication endpoints.
Fixes outdated token generation docs.
```

**Type:** `docs` (documentation only, no code changes)
**Scope:** Omitted (docs are cross-cutting)

---

### Example 11: Mixed Change Types (User Guidance Needed)

**Staged changes:**
```
M  src/auth/LoginService.ts  (bug fix)
A  src/auth/OAuthService.ts  (new feature)
M  tests/auth.test.ts        (tests)
```

**Workflow execution:**
1. Detect mixed types: fix + feat + test
2. **Ask user**: "Changes include both bug fix and new feature. Should these be separate commits?"
3. User chooses: "Use 'feat' (new feature is primary)"

**Generated message:**
```
feat(auth): add OAuth2 support and fix login bug

Implements OAuth2 authentication with Google provider.
Also resolves token validation bug in existing login flow.
```

**Recommendation to user:** "Consider splitting into two commits: one feat, one fix"

---

## Common Mistakes to Avoid

### Mistake 1: Wrong Tense (Not Imperative)

**❌ WRONG:**
```
commit -m "Added new login feature"
commit -m "Adds OAuth2 support"
commit -m "Fixed memory leak"
```

**✅ CORRECT:**
```
commit -m "feat(auth): add login feature"
commit -m "feat(auth): add OAuth2 support"
commit -m "fix(memory): fix memory leak"
```

**Why:** Conventional commits require imperative mood. The message should read as instructions to apply the change.

---

### Mistake 2: Vague Subject Line

**❌ WRONG:**
```
feat: add feature
fix: fix bug
refactor: update code
docs: fix typo
```

**✅ CORRECT:**
```
feat(auth): add OAuth2 authentication support
fix(cache): resolve memory leak in LRU cache
refactor(api): extract validation logic to service
docs(README): add installation instructions
```

**Why:** The subject should describe WHAT was added/fixed specifically. This makes history searchable and meaningful.

---

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

**Why:** The `!` marker signals to tooling that this is breaking. Without it, automated changelog generators miss the breaking change.

---

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

**Why:** Scope helps identify which part of the system is affected. It makes filtering history and impact analysis easier.

---

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

**Why:** Type must match the nature of the change. Using correct types enables:
- Semantic versioning (feat = minor bump, fix = patch bump)
- Automated changelog generation
- Project history understanding

---

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

**Why:** Long subjects reduce readability in git logs and history viewers. Use the body for detailed explanation.

---

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

**Why:** Conventional commits omit the period. It's a style consistency rule.

---

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

**Why:** The body explains WHY the change was made, not WHAT changed (code shows that). This helps future maintainers understand decisions.

---

## Using Examples in Workflows

**When to load this file:**
- User asks for examples: "Show me an example"
- Uncertain about output format for edge case
- Need to demonstrate proper conventional commit structure
- Teaching user about conventional commits
- **User makes mistakes** (wrong tense, vague subjects, missing markers)

**Do not load for:**
- Routine generation or validation (use quick heuristics)
- High-confidence operations (unnecessary overhead)
