# Commit Type Detection

Guide for determining the correct conventional commit type based on code changes.

## Table of Contents

- [Decision Tree](#decision-tree)
- [Type-Specific Detection Patterns](#type-specific-detection-patterns)
- [Complex Scenarios](#complex-scenarios)
- [Ambiguous Cases Decision Guide](#ambiguous-cases-decision-guide)
- [File Pattern Recognition](#file-pattern-recognition)
- [Quick Reference](#quick-reference)

## Decision Tree

```
New functionality/capability? → feat
  └─ Fixes a bug? → fix
      └─ Only docs changed? → docs
          └─ Only formatting/style? → style
              └─ Restructures code (no behavior change)? → refactor
                  └─ Improves performance? → perf
                      └─ Adds/updates tests? → test
                          └─ Build/dependencies? → build/ci
                              └─ Other maintenance? → chore
```

## Type-Specific Detection Patterns

### `feat` - New Feature

**Indicators:**
- New files with actual functionality (not just config/tests)
- New public API methods/functions
- New user-facing capabilities
- New configuration options that enable new behavior
- New routes/endpoints

**Code patterns:**
```diff
+ export function newFeature() {
+   // implementation
+ }

+ router.post('/api/new-endpoint', handler)

+ <NewComponent />
```

**File patterns:**
- `+src/services/NewService.ts` (new service file)
- `+src/components/NewFeature.tsx` (new component)
- `+routes/newRoutes.ts` (new routes)

**NOT feat if:**
- Only internal/private changes (use `refactor`)
- Fixes existing broken functionality (use `fix`)
- Only improves performance of existing feature (use `perf`)

### `fix` - Bug Fix

**Indicators:**
- Resolves incorrect behavior
- Fixes crashes/exceptions
- Corrects logic errors
- Patches security vulnerabilities
- Fixes data corruption issues

**Code patterns:**
```diff
- if (user.age > 18) {
+ if (user.age >= 18) {

- return results[0]  // crashed on empty array
+ return results.length > 0 ? results[0] : null

- password === hashedPassword  // security issue
+ bcrypt.compare(password, hashedPassword)
```

**Commit message patterns:**
- "resolve", "correct", "fix", "patch"
- References to bugs/issues: "Closes #123"
- Error/exception mentions

**NOT fix if:**
- Adding missing functionality (use `feat`)
- Improving existing working code (use `refactor` or `perf`)

### `refactor` - Code Restructuring

**Indicators:**
- Moves code to different files
- Extracts functions/classes
- Renames variables/functions for clarity
- Simplifies complex logic (same behavior)
- Removes dead code
- Changes internal implementation (same API)

**Code patterns:**
```diff
// Extract function
- function processUser() {
-   validateEmail(user.email)
-   validateAge(user.age)
-   validateName(user.name)
+ function processUser() {
+   validateUserFields(user)
  }

+ function validateUserFields(user) {
+   validateEmail(user.email)
+   validateAge(user.age)
+   validateName(user.name)
+ }

// Rename for clarity
- const x = getUserData()
+ const userData = getUserData()
```

**Key distinction:**
- Behavior unchanged (same inputs → same outputs)
- Tests should still pass without modification
- No user-facing changes

### `perf` - Performance Improvement

**Indicators:**
- Optimizes algorithms
- Adds caching
- Reduces database queries
- Improves load times
- Reduces memory usage

**Code patterns:**
```diff
// Add caching
+ const cache = new Map()
  function expensiveOperation(input) {
+   if (cache.has(input)) return cache.get(input)
    const result = complexCalculation(input)
+   cache.set(input, result)
    return result
  }

// Optimize algorithm
- for (const item of items) {
-   for (const other of items) {
-     compare(item, other)
-   }
- }
+ items.sort().forEach((item, i) => {
+   compare(item, items[i + 1])
+ })

// Reduce queries (N+1 problem)
- users.forEach(user => {
-   user.posts = db.query('SELECT * FROM posts WHERE user_id = ?', user.id)
- })
+ const posts = db.query('SELECT * FROM posts WHERE user_id IN (?)', userIds)
+ users.forEach(user => {
+   user.posts = posts.filter(p => p.user_id === user.id)
+ })
```

**Measurable improvements:**
- Execution time reduced
- Memory usage decreased
- Network requests reduced
- Database queries optimized

### `docs` - Documentation Only

**Indicators:**
- Changes only to documentation files
- Comment updates without code changes
- README updates
- API documentation
- Code examples in docs

**File patterns:**
- `*.md` files only
- `docs/**` directory only
- JSDoc/PHPDoc comments only (no code)

**NOT docs if:**
- Code changes accompany docs (use primary type + update docs)
- Example: `feat(api): add endpoint` (docs updated as part of feature)

### `style` - Formatting Changes

**Indicators:**
- Whitespace changes
- Semicolon additions/removals
- Code formatting (prettier/eslint fixes)
- Line wrapping
- Import statement ordering

**Code patterns:**
```diff
- function hello(){
+ function hello() {

- const x=1,y=2,z=3;
+ const x = 1;
+ const y = 2;
+ const z = 3;

- import {B,A,C} from 'module'
+ import {A,B,C} from 'module'
```

**Key distinction:**
- Zero functional changes
- Compiler output identical (or nearly so)
- Only affects code readability/consistency

### `test` - Test Changes

**Indicators:**
- Adds missing tests
- Updates existing tests
- Fixes broken tests
- Improves test coverage

**File patterns:**
- Changes to `*.test.ts`, `*.spec.ts`
- Changes to `__tests__/` directory
- Changes to test fixtures/mocks

**NOT test if:**
- Tests added as part of new feature (include in `feat` commit)
- Tests updated due to bug fix (include in `fix` commit)
- Use `test:` only for standalone test improvements

### `build` - Build System

**Indicators:**
- Build script changes
- Dependency updates
- Bundler configuration
- Compiler settings

**File patterns:**
- `package.json` (dependencies)
- `webpack.config.js`
- `tsconfig.json`
- `babel.config.js`
- `Dockerfile`
- `docker-compose.yml`

**Examples:**
- `build: update webpack to v5`
- `build(deps): upgrade react to v18`
- `build: enable source maps in production`

### `ci` - CI/CD Configuration

**Indicators:**
- CI pipeline changes
- GitHub Actions workflows
- GitLab CI configuration
- Deployment scripts

**File patterns:**
- `.github/workflows/**`
- `.gitlab-ci.yml`
- `Jenkinsfile`
- `.circleci/**`

**Examples:**
- `ci: add automated testing workflow`
- `ci: enable caching for npm dependencies`
- `ci: fix deploy script timeout`

### `chore` - Maintenance

**Indicators:**
- Configuration changes
- Tooling updates
- License updates
- .gitignore updates
- Things that don't fit other categories

**Examples:**
- `chore: update .gitignore for IDE files`
- `chore: add LICENSE file`
- `chore: configure renovate bot`

**NOT chore if:**
- It fits a more specific type
- Last resort category only

## Complex Scenarios

### Multiple Types in One Change

**Scenario:** Added feature + fixed related bug

**Options:**
1. **Separate commits** (preferred):
   ```
   feat(auth): add OAuth2 support
   fix(auth): resolve token expiration bug
   ```

2. **Use primary type:**
   ```
   feat(auth): add OAuth2 with token fix

   Also resolved token expiration issue in existing auth.
   ```

### Feature That Fixes a Problem

**If the feature's purpose is to fix a problem:**
- Use `fix` if problem was broken/incorrect
- Use `feat` if problem was missing capability

**Example:**
```
# Missing capability → feat
feat(api): add rate limiting

Prevents API abuse by limiting requests per client.

# Broken behavior → fix
fix(api): enforce rate limiting

Rate limiting was implemented but not enforced due to middleware ordering.
```

### Refactor That Improves Performance

**If primary goal is performance:**
```
perf(db): optimize user query with caching
```

**If primary goal is clean code (performance is bonus):**
```
refactor(db): simplify user query logic

Also improves performance by 30%.
```

### Dependency Update That Adds Features

**If dependency update is transparent:**
```
build(deps): update library to v2.0
```

**If dependency update enables new usage:**
```
feat(ui): enable dark mode using updated theme library

Updated theme-library to v2.0 which adds dark mode support.
```

## Ambiguous Cases Decision Guide

### Is it feat or refactor?

**Ask:** Does it add user-visible capability?
- Yes → `feat`
- No → `refactor`

### Is it fix or refactor?

**Ask:** Was the previous behavior wrong/broken?
- Yes → `fix`
- No (just improving code quality) → `refactor`

### Is it perf or refactor?

**Ask:** Is performance the PRIMARY goal?
- Yes, measured improvement → `perf`
- No, just cleaner code → `refactor`

### Is it feat or fix?

**Ask:** Did this functionality exist before?
- No, it's new → `feat`
- Yes, but broken → `fix`

### Is it build or chore?

**Ask:** Does it affect build output or dependencies?
- Yes → `build`
- No → `chore`

## File Pattern Recognition

| File Pattern | Likely Type |
|--------------|-------------|
| `+src/features/NewFeature.ts` | feat |
| `M src/auth/login.ts` (logic fix) | fix |
| `M src/auth/login.ts` (rename vars) | refactor |
| `+__tests__/newFeature.test.ts` only | test |
| `M README.md` only | docs |
| `M package.json` (deps) | build |
| `M .github/workflows/test.yml` | ci |
| `M .gitignore` | chore |
| `+src/cache/` (new cache system) | perf |
| `M src/**/*.ts` (prettier) | style |

## Quick Reference

| Type | User Impact | Semver |
|------|-------------|--------|
| feat | New capability | MINOR |
| fix | Bug resolved | PATCH |
| perf | Faster/efficient | PATCH |
| docs | Better docs | - |
| style | None | - |
| refactor | None (internal) | - |
| test | Better coverage | - |
| build | Build changes | - |
| ci | CI changes | - |
| chore | Maintenance | - |
| BREAKING | API changed | MAJOR |
