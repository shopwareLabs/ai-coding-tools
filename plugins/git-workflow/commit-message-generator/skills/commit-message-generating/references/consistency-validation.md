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

1. **Type consistency** - Match type to change nature?
2. **Scope accuracy** - Match scope to files?
3. **Subject precision** - Describe what changed?
4. **Breaking changes** - Properly marked?

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
→ This is `refactor` or `fix`

```diff
# Says "feat" but fixes broken feature
+ if (!user) throw new Error()  // was crashing
```
→ This is `fix`

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
→ This is `feat`

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
→ This is `fix`

## Scope Accuracy Checks

### Scope Validation Rules

**Match files to scope:** All files under `src/auth/` → scope: `auth`; spanning multiple scopes → broader scope or omit

**Too specific:** `fix(LoginController)` → use module: `fix(auth)`

**Too broad:** `feat(app): add login` for `src/auth/*` files → use specific scope: `feat(auth)`

## Subject Precision Checks

### Too vague

`feat: add feature` → `feat(auth): add OAuth2 authentication`
`fix: fix bug` → `fix(image-processor): resolve memory leak`

### Inaccurate description

`feat(api): add user registration` (actually replacing) → `refactor(api): replace user registration handler`
`fix(db): improve query performance` (actually optimizing) → `perf(db): add index to user email column`

### Missing key details

`feat(api): add endpoint` → `feat(api): add user profile endpoint` (specify what)
`fix(auth): resolve issue` → `fix(auth): resolve token expiration edge case` (specify which)

## Breaking Change Validation

### Missing ! marker

**Problem:** `feat(api): change authentication format` with BREAKING CHANGE footer lacks `!`
**Fix:** Add `!`: `feat(api)!: change authentication format`

### ! without BREAKING CHANGE footer

**Problem:** `feat(api)!: update authentication` lacks BREAKING CHANGE footer
**Fix:** Add footer: `BREAKING CHANGE: Authentication now requires OAuth2 tokens.`

### Not actually breaking

**Problem:** `feat(api)!: add optional parameter` marked as breaking (but optional = backward compatible)
**Fix:** Remove `!`: `feat(api): add optional theme parameter to getUserProfile`

### Actually breaking but not marked

**Problem:** `refactor(api): simplify user endpoints` with URL change (`/api/user` → `/api/v2/users`) lacks breaking marker
**Fix:** Add `!` and footer: `refactor(api)!: migrate user endpoints to v2`; add `BREAKING CHANGE: User endpoints moved from /api/user to /api/v2/users`

## Validation Workflow

### Step 1: Extract Claimed Information

From `feat(auth): add OAuth2 support` → Type: feat | Scope: auth | Subject: add OAuth2 support | Breaking: no

### Step 2: Analyze Actual Changes

From diff with `+src/auth/OAuth2*.ts` (new files) and modified `AuthController.ts`:
- **Type:** New files/functionality → feat ✓
- **Scope:** auth directory → auth ✓
- **Changes:** OAuth2 implementation → matches subject ✓

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

| Pattern | Wrong | Reality | Should Be |
|---------|-------|---------|-----------|
| **Wrong Type** | `fix: improve performance` | Performance optimization | `perf: optimize query performance` |
| **Missing Scope** | `feat: add feature` | Only changes auth module | `feat(auth): add OAuth2 support` |
| **Vague Subject** | `refactor: update code` | Extracted validation logic | `refactor(validation): extract logic to dedicated service` |
| **Type Mismatch** | `feat: fix login timeout` | Bug fix | `fix(auth): resolve login timeout issue` |
| **Scope Mismatch** | `feat(ui): add API endpoint` | Backend API changes | `feat(api): add user registration endpoint` |
| **Incomplete Breaking** | `refactor(api)!: update endpoints` | Missing BREAKING CHANGE footer | Add BREAKING CHANGE description |

## Validation Severity Levels

**Critical (FAIL):** Wrong type, breaking change not marked, subject completely wrong

**Warning (WARN):** Scope could be more specific, subject could be more descriptive, minor type ambiguity

**Info (PASS):** Scope omitted (acceptable), subject adequate but improvable, minor wording issues

## Automated vs Manual Checks

**Automated:** Format validation (regex), type in allowed list, subject length, breaking change marker consistency

**Manual/AI (This Skill):** Type matches changes, scope matches file paths, subject accuracy, breaking change identification

## Validation Report Template

```
Commit Message Validation Report
=================================
Commit: <sha>  |  Message: <subject>

Format Compliance: [PASS/FAIL]
  [✓/✗] Valid type: <type>
  [✓/✗] Scope format: <scope>
  [✓/✗] Subject/length/markers

Consistency Check: [PASS/WARN/FAIL]
  [✓/⚠/✗] Type matches changes: <explanation>
  [✓/⚠/✗] Scope accurate: <explanation>
  [✓/⚠/✗] Subject describes changes: <explanation>
  [✓/⚠/✗] Breaking changes marked: <explanation>

Recommendations:
  <suggestions>

Suggested message:
<better version>
```

## Examples

### Example 1: Type Mismatch

`feat(api): fix user registration` → Claimed: feat, Subject: "fix", Reality: bug fix

**Issue:** Type/subject mismatch
**Fix:** `fix(api): correct user registration validation`

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
