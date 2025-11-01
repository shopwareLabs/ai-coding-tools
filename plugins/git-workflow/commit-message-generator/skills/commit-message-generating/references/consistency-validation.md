# Consistency Validation

Guide for validating that commit messages accurately describe the actual code changes.

## Table of Contents

- [Validation Dimensions](#validation-dimensions)
- [Type Consistency Checks](#type-consistency-checks)
- [Scope Accuracy Checks](#scope-accuracy-checks)
- [Subject Precision Checks](#subject-precision-checks)
- [Breaking Change Validation](#breaking-change-validation)
- [Validation Workflow](#validation-workflow)
- [Common Inconsistency Patterns](#common-inconsistency-patterns)
- [Validation Severity Levels](#validation-severity-levels)
- [Automated vs Manual Checks](#automated-vs-manual-checks)
- [Validation Report Template](#validation-report-template)
- [Examples](#examples)

## Validation Dimensions

1. **Type consistency** - Does type match the nature of changes?
2. **Scope accuracy** - Does scope match changed files?
3. **Subject precision** - Does subject describe what changed?
4. **Breaking changes** - Are breaking changes properly marked?

## Type Consistency Checks

### feat vs actual changes

**Claimed:** `feat(api): add user endpoint`

**Check diff for:**
- ✓ New route/endpoint defined
- ✓ New functionality implemented
- ✓ New public API surface

**Inconsistencies:**
```diff
# Says "add" but only modifies existing
- return user.name
+ return user.fullName
```
→ This is `refactor` or `fix`, not `feat`

```diff
# Says "feat" but fixes broken feature
+ if (!user) throw new Error()  // was crashing
```
→ This is `fix`, not `feat`

### fix vs actual changes

**Claimed:** `fix(auth): resolve login issue`

**Check diff for:**
- ✓ Corrects wrong behavior
- ✓ Fixes error/exception
- ✓ Patches security issue

**Inconsistencies:**
```diff
# Says "fix" but adds new capability
+ export function refreshToken() {
+   // new feature, not fixing broken code
+ }
```
→ This is `feat`, not `fix`

### refactor vs actual changes

**Claimed:** `refactor(db): simplify query logic`

**Check diff for:**
- ✓ Code reorganization
- ✓ No behavior changes
- ✓ Tests still pass (implied)

**Inconsistencies:**
```diff
# Says "refactor" but changes behavior
- return users.filter(u => u.age > 18)
+ return users.filter(u => u.age >= 18)  // logic change!
```
→ This is `fix`, not `refactor`

## Scope Accuracy Checks

### File paths match scope

**Claimed:** `feat(auth): add login endpoint`

**Check files:**
```
✓ src/auth/LoginController.ts
✓ src/auth/types.ts
✗ src/api/PublicController.ts  // different scope!
```

**Validation:**
- All files should be under `src/auth/` or related to auth
- If files span multiple scopes, scope should be broader or omitted

### Scope too specific

**Claimed:** `fix(LoginController): resolve timeout`

**Better:** `fix(auth): resolve login timeout`
- Scope should be module/feature, not file/class name

### Scope too broad

**Claimed:** `feat(app): add login`

**Check files:**
```
src/auth/LoginController.ts
src/auth/LoginService.ts
```

**Better:** `feat(auth): add login endpoint`
- Scope should be specific when changes are localized

## Subject Precision Checks

### Too vague

**Claimed:** `feat: add feature`
**Diff shows:** New OAuth2 authentication

**Better:** `feat(auth): add OAuth2 authentication`

**Claimed:** `fix: fix bug`
**Diff shows:** Resolved memory leak in image processor

**Better:** `fix(image-processor): resolve memory leak`

### Inaccurate description

**Claimed:** `feat(api): add user registration`
**Diff shows:**
```diff
- app.post('/register', oldHandler)
+ app.post('/register', newHandler)  // replacing, not adding
```

**Better:** `refactor(api): replace user registration handler`

**Claimed:** `fix(db): improve query performance`
**Diff shows:**
```diff
+ createIndex('users', 'email')  // not fixing, optimizing
```

**Better:** `perf(db): add index to user email column`

### Missing key details

**Claimed:** `feat(api): add endpoint`

**What endpoint? For what?**
**Better:** `feat(api): add user profile endpoint`

**Claimed:** `fix(auth): resolve issue`

**What issue?**
**Better:** `fix(auth): resolve token expiration edge case`

## Breaking Change Validation

### Missing ! marker

**Commit message:**
```
feat(api): change authentication format

BREAKING CHANGE: /auth endpoints now require OAuth2
```

**Issue:** Has BREAKING CHANGE but missing `!`

**Correct:**
```
feat(api)!: change authentication format

BREAKING CHANGE: /auth endpoints now require OAuth2
```

### ! without BREAKING CHANGE footer

**Commit message:**
```
feat(api)!: update authentication
```

**Issue:** Has `!` but no BREAKING CHANGE footer

**Required:**
```
feat(api)!: update authentication

BREAKING CHANGE: Authentication now requires OAuth2 tokens.
Migration: Update clients to use /auth/token endpoint.
```

### Not actually breaking

**Claimed:**
```
feat(api)!: add optional parameter

BREAKING CHANGE: Added optional theme parameter to getUserProfile
```

**Issue:** Adding optional parameter is NOT breaking (backward compatible)

**Correct:**
```
feat(api): add optional theme parameter to getUserProfile
```

### Actually breaking but not marked

**Commit:**
```
refactor(api): simplify user endpoints
```

**Diff shows:**
```diff
- app.get('/api/user/:id', handler)
+ app.get('/api/v2/users/:id', handler)  // URL changed!
```

**Issue:** URL change breaks existing clients

**Correct:**
```
refactor(api)!: migrate user endpoints to v2

BREAKING CHANGE: User endpoints moved from /api/user to /api/v2/users.
Update client requests to new endpoint paths.
```

## Validation Workflow

### Step 1: Extract Claimed Information

From message: `feat(auth): add OAuth2 support`

```
Type: feat
Scope: auth
Subject: add OAuth2 support
Breaking: no
```

### Step 2: Analyze Actual Changes

From diff:
```diff
+src/auth/OAuth2Service.ts
+src/auth/OAuth2Middleware.ts
Mssrc/auth/AuthController.ts
```

**Actual type:** New files, new functionality → feat ✓
**Actual scope:** auth directory → auth ✓
**Actual changes:** OAuth2 implementation → matches subject ✓

### Step 3: Check Consistency

- ✓ Type matches changes (new functionality)
- ✓ Scope matches file paths (auth)
- ✓ Subject accurately describes changes
- ✓ No breaking changes (additive)

**Result: CONSISTENT**

### Step 4: Generate Report

```
Consistency Check: ✓ PASS
  ✓ Type 'feat' matches new functionality added
  ✓ Scope 'auth' matches changed files
  ✓ Subject accurately describes OAuth2 addition
  ✓ No breaking changes detected
```

## Common Inconsistency Patterns

### Pattern 1: Wrong Type

**Message:** `fix: improve performance`
**Reality:** Performance optimization
**Should be:** `perf: optimize query performance`

### Pattern 2: Missing Scope

**Message:** `feat: add feature`
**Reality:** Only changes auth module
**Should be:** `feat(auth): add OAuth2 support`

### Pattern 3: Vague Subject

**Message:** `refactor: update code`
**Reality:** Extracted validation logic to service
**Should be:** `refactor(validation): extract logic to dedicated service`

### Pattern 4: Type Mismatch

**Message:** `feat: fix login timeout`
**Reality:** Bug fix
**Should be:** `fix(auth): resolve login timeout issue`

### Pattern 5: Scope Mismatch

**Message:** `feat(ui): add API endpoint`
**Reality:** Backend API changes
**Should be:** `feat(api): add user registration endpoint`

### Pattern 6: Incomplete Breaking Change

**Message:** `refactor(api)!: update endpoints`
**Reality:** Missing BREAKING CHANGE footer
**Needs:** BREAKING CHANGE description in footer

## Validation Severity Levels

### Critical (FAIL)

- Wrong type (feat vs fix vs refactor)
- Breaking change not marked
- Subject completely wrong

### Warning (WARN)

- Scope could be more specific
- Subject could be more descriptive
- Minor type ambiguity (refactor vs perf)

### Info (PASS)

- Scope omitted (acceptable)
- Subject adequate but could improve
- Minor wording issues

## Automated vs Manual Checks

### Automated Checks

- Format validation (regex)
- Type in allowed list
- Subject length
- Breaking change marker consistency

### Manual/AI Checks (This Skill)

- Type matches actual changes
- Scope matches file paths
- Subject accurately describes changes
- Breaking changes correctly identified

## Validation Report Template

```
Commit Message Validation Report
=================================

Commit: <sha>
Message: "<subject>"

Format Compliance: [PASS/FAIL]
  [✓/✗] Valid type: <type>
  [✓/✗] Scope format: <scope>
  [✓/✗] Subject format
  [✓/✗] Length constraints
  [✓/✗] Breaking change markers

Consistency Check: [PASS/WARN/FAIL]
  [✓/⚠/✗] Type matches changes
    Analysis: <explanation>
  [✓/⚠/✗] Scope accurate
    Analysis: <explanation>
  [✓/⚠/✗] Subject describes changes
    Analysis: <explanation>
  [✓/⚠/✗] Breaking changes marked
    Analysis: <explanation>

Recommendations:
  1. <specific suggestion>
  2. <specific suggestion>

[Optional] Suggested message:
<better version>
```

## Examples

### Example 1: Type Mismatch

**Message:** `feat(api): fix user registration`

**Analysis:**
- Claimed type: feat (new feature)
- Subject says: "fix" (bug fix)
- Diff shows: Corrected validation logic

**Result:** INCONSISTENT

**Report:**
```
✗ Type mismatch: Subject says "fix" but type is "feat"
  The changes correct validation logic (a bug fix)

Recommendation: Change type to "fix"

Suggested: fix(api): correct user registration validation
```

### Example 2: Missing Breaking Change

**Message:**
```
refactor(api): update response format
```

**Diff:**
```diff
- return { userId: user.id }
+ return { id: user.id }  // property name changed!
```

**Result:** INCONSISTENT

**Report:**
```
✗ Breaking change not marked: Response property renamed
  Clients expecting 'userId' will break

Recommendation: Add breaking change marker and footer

Suggested:
refactor(api)!: update response format to use 'id'

BREAKING CHANGE: Response property changed from 'userId' to 'id'.
Update clients to use response.id instead of response.userId.
```

### Example 3: Scope Inaccuracy

**Message:** `feat(auth): add dashboard widgets`

**Diff:**
```
+src/components/DashboardWidget.tsx
+src/components/ChartWidget.tsx
```

**Result:** INCONSISTENT

**Report:**
```
⚠ Scope mismatch: Files are in 'components' not 'auth'

Recommendation: Update scope to match changed files

Suggested: feat(components): add dashboard widgets
or
feat(ui): add dashboard widgets
```
