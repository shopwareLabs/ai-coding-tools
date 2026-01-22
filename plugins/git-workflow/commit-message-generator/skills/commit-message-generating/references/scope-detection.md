# Scope Detection

Determine conventional commit scope from file paths with confidence-based analysis.

## Scope Inference

Map directory structure to scope:
- `src/auth/**` → auth
- `src/api/**` → api
- `src/components/**` → ui
- `packages/core/**` → core (monorepo)
- `apps/web/**` → web (monorepo)

**Naming conventions:**
- Lowercase, kebab-case: `user-profile` not `UserProfile`
- Singular preferred: `user` not `users`
- Concise (1-2 words): `api` not `api-v2-users`

## Confidence Levels

**HIGH**: All files in single clear module
- `src/auth/LoginService.ts`, `src/auth/types.ts` → auth

**MEDIUM**: Related modules with clear feature
- `src/api/users.ts`, `src/services/UserService.ts` → user (feature-based)

**LOW**: Multiple unrelated modules → use AskUserQuestion
- `src/auth/`, `src/database/`, `src/cache/` → ask user

## When to Omit Scope

Omit scope when:
- Type is `docs` with project-wide docs (README.md)
- Type is `style` (formatting only)
- Type is `ci` (CI config only)
- Root-level config files (.gitignore, LICENSE)
- Cross-cutting changes with no clear module

## Config Validation

If project config has `scopes` list:
1. Check if inferred scope is in allowed list
2. If not found → LOW confidence, ask user for closest match
3. If `require_scope: true` → never suggest omitting

## User Question Format (LOW Confidence)

When confidence is LOW, ask the user:

```
AskUserQuestion(
  question="Which scope best describes these changes?",
  header="Commit Scope",
  multiSelect=false,
  options=[
    {label: "auth", description: "Changes in src/auth/ directory"},
    {label: "db", description: "Database migration changes"},
    {label: "Omit scope", description: "Cross-cutting concern"}
  ]
)
```

Include 2-4 options. Best guess first, "Omit scope" last.

## Examples

### HIGH Confidence: Single Module
Scope: `auth`
Reasoning: "All files in src/auth/ directory: LoginService.ts, AuthMiddleware.ts, types.ts"

### MEDIUM Confidence: Feature-based
Scope: `user`
Reasoning: "Files span api, services, models but all relate to user management"

### HIGH Confidence: Omit Scope
Scope: (omit)
Reasoning: "Only README.md changed. Type is 'docs' - scope redundant."

### LOW Confidence: Ask User
Reasoning: "Files in auth/, database/, cache/ - no clear primary module"
Action: Ask user with options for auth, db, and "Omit scope"

## Key Principles

1. **Infer from paths** - Directory structure is the primary signal
2. **Be specific but not granular** - `auth` not `AuthController`
3. **Omit when redundant** - docs type + README = no scope needed
4. **Respect project config** - Use allowed scopes when configured
