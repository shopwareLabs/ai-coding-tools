# Scope Detection

Guide for determining commit scope from changed files and code patterns.

## Table of Contents

- [Principles](#principles)
- [Path-Based Detection](#path-based-detection)
- [Multi-File Changes](#multi-file-changes)
- [Scope Naming Conventions](#scope-naming-conventions)
- [Feature-Based Scopes](#feature-based-scopes)
- [Edge Cases](#edge-cases)
- [Scope Detection Algorithm](#scope-detection-algorithm)
- [Project-Specific Scopes](#project-specific-scopes)
- [When to Omit Scope](#when-to-omit-scope)
- [Quick Reference](#quick-reference)

## Principles

1. **Infer from file paths** - Most reliable indicator
2. **Use common conventions** - Follow project standards
3. **Be specific but not granular** - Module level, not file level
4. **Omit if unclear** - Scope is optional

## Path-Based Detection

### Web Application Structure

```
src/
├── api/          → scope: api
├── auth/         → scope: auth
├── components/   → scope: ui or component-name
├── database/     → scope: db
├── middleware/   → scope: middleware
├── services/     → scope: service-name
├── utils/        → scope: utils
└── config/       → scope: config
```

**Examples:**
```
src/auth/LoginController.ts  → scope: auth
src/api/v2/users.ts          → scope: api
src/components/Button.tsx    → scope: ui
src/database/migrations/     → scope: db
```

### Monorepo Structure

```
packages/
├── core/         → scope: core
├── ui-components/→ scope: ui-components
├── utils/        → scope: utils
└── api-client/   → scope: api-client
```

**Examples:**
```
packages/core/src/index.ts         → scope: core
packages/ui-components/Button.tsx  → scope: ui-components
```

### Backend Service Structure

```
src/
├── controllers/  → scope: controller-name
├── models/       → scope: model-name
├── repositories/ → scope: repo or data
├── services/     → scope: service-name
└── middleware/   → scope: middleware
```

## Multi-File Changes

### Same Module

**All files in one scope:**
```
src/auth/LoginService.ts
src/auth/AuthMiddleware.ts
src/auth/types.ts
```
→ scope: `auth`

### Related Modules

**Closely related scopes:**
```
src/api/users.ts
src/services/UserService.ts
src/models/User.ts
```
→ scope: `users` or `user-management`

### Unrelated Modules

**Option 1: Omit scope**
```
feat: add logging and error handling
```

**Option 2: Use broader scope**
```
feat(core): add logging and error handling
```

**Option 3: Separate commits** (preferred)
```
feat(logging): add structured logging
feat(errors): add error handling middleware
```

## Scope Naming Conventions

### Format Rules

- **Lowercase** - Always use lowercase
- **Kebab-case** - Multi-word scopes: `user-management`, `api-client`
- **Singular nouns** - Prefer `user` over `users`
- **Concise** - 1-3 words maximum
- **No special chars** - Alphanumeric and hyphens only

### Common Scopes by Project Type

**Web API:**
- `api`, `auth`, `db`, `cache`, `queue`, `middleware`, `config`

**Frontend Application:**
- `ui`, `components`, `routing`, `state`, `api-client`, `hooks`, `utils`

**Full-stack:**
- `frontend`, `backend`, `shared`, `api`, `db`, `auth`

**Library:**
- `core`, `types`, `utils`, `exports`, `api`

**CLI Tool:**
- `cli`, `commands`, `config`, `output`, `parser`

## Feature-Based Scopes

### When Path Doesn't Help

If files don't fit clear module structure, use feature name:

```
src/various/files/for/user-profile.ts
```
→ scope: `user-profile`

```
Multiple files implementing search feature
```
→ scope: `search`

### Domain-Driven Scopes

For DDD/domain-driven projects:

```
src/user/domain/User.ts
src/user/application/UserService.ts
src/user/infrastructure/UserRepository.ts
```
→ scope: `user` (domain)

## Edge Cases

### Root-Level Files

**Configuration files:**
```
package.json, tsconfig.json, .eslintrc
```
→ scope: `config` or omit

**Documentation:**
```
README.md, CONTRIBUTING.md
```
→ scope: `docs` or omit (type: docs already clear)

**Build files:**
```
webpack.config.js, Dockerfile
```
→ scope: `build` or omit

### Test Files

**Tests for specific module:**
```
src/auth/__tests__/LoginService.test.ts
```
→ scope: `auth` (the module being tested)

**General test infrastructure:**
```
tests/setup.ts, tests/helpers.ts
```
→ scope: `test` or omit

### Mixed Frontend/Backend

**Backend change:**
```
server/src/api/users.ts
```
→ scope: `api` or `backend`

**Frontend change:**
```
client/src/components/UserList.tsx
```
→ scope: `ui` or `frontend`

**Both:**
- Separate commits (preferred)
- Use feature scope: `user-management`
- Omit scope

## Scope Detection Algorithm

```
1. Extract file paths from diff
2. Identify common path prefix
3. If all files share module directory:
   → Use module name as scope
4. Else if files belong to feature:
   → Use feature name as scope
5. Else if < 3 unrelated files:
   → Omit scope
6. Else:
   → Use broader scope or omit
```

**Example:**
```
Files changed:
- src/auth/LoginController.ts
- src/auth/AuthMiddleware.ts
- src/auth/TokenService.ts

Common prefix: src/auth/
→ scope: auth
```

```
Files changed:
- src/api/users.ts
- src/components/UserList.tsx
- src/services/UserService.ts

Common feature: user management
→ scope: users or user-management
```

## Project-Specific Scopes

### Configure in .commitmsgrc.md

```yaml
scopes:
  - api
  - auth
  - billing
  - ui
  - db
```

Then enforce allowed scopes only.

### Scope Aliases

Normalize variations:
```yaml
scope_aliases:
  authentication: auth
  database: db
  frontend: ui
  backend: api
```

## When to Omit Scope

**Valid reasons:**
- Changes affect entire codebase
- No clear module boundary
- Cross-cutting concerns (logging, error handling)
- Initial setup commits
- Tooling/meta changes

**Examples without scope:**
```
chore: initial commit
style: apply prettier formatting
build: update all dependencies
ci: add GitHub Actions workflow
```

## Quick Reference

| File Pattern | Suggested Scope |
|--------------|-----------------|
| `src/auth/**` | auth |
| `src/api/**` | api |
| `src/components/**` | ui or component-name |
| `src/services/UserService.ts` | users or user-service |
| `src/models/User.ts` | users or models |
| `tests/**` | test or module-being-tested |
| `docs/**` | docs (or omit with docs type) |
| `config/**` | config |
| `packages/core/**` | core |
| Root config files | config or omit |
| Multiple unrelated | omit or use feature name |
