# Generation Output Format Standards

Format commit message generation output based on verbosity levels.

> **Note:** For validation reports, see `agents/report-generator.md`.

## Verbosity Levels

### Verbose Mode

**Use when:** Learning mode, explicit detail request, or low confidence in type/scope detection

**Output includes:** Complete reasoning (type, scope, alternatives), confidence levels, step-by-step analysis

**Example:**
```
Files: A src/auth/JwtService.ts, M src/auth/AuthController.ts

Type Detection:
  - New file + new endpoint → feat (HIGH confidence)

Scope: auth (all changes in src/auth/)

Breaking: None detected

Generated:
feat(auth): add JWT token generation service

Implements JWT token creation with configurable expiration.
Uses HS256 algorithm with secret from environment.
```

---

### Standard Mode

**Use when:** Default operation, medium confidence

**Output includes:** Core decisions (type, scope, subject), key reasoning, config source, warnings

**Example:**
```
Files: A src/auth/JwtService.ts, M src/auth/AuthController.ts
Type: feat (new functionality)
Scope: auth
Breaking: None

Generated:
feat(auth): add JWT token generation service

Implements JWT token creation with configurable expiration.
Uses HS256 algorithm with secret from environment.
```

---

### Concise Mode

**Use when:** Summary request, quick confirmation, or high confidence

**Output includes:** Final result, critical warnings only

**Example:**
```
feat(auth): add JWT token generation service

Implements JWT token creation with configurable expiration.
```

---

## Selection Guidelines

**User request patterns:**
- Verbose: "explain why", "show me how", "detailed analysis", "walk me through"
- Standard: "generate commit message" or default
- Concise: "quick", "essentials", "summary only"

**Confidence levels:**
- LOW → Verbose (explain reasoning and alternatives)
- MEDIUM → Standard
- HIGH → Standard or Concise

---

## Formatting Rules

1. **No Validation Checkmarks**: Never show ✓/✗/⚠ in generation mode (validation reports only)
2. **Analysis Before Message**: Include relevant analysis before message (verbosity-dependent)
3. **Self-Validation Hidden**: Runs internally (Step 6), never shown to users
4. **Markdown**: Code blocks for messages, bold headers, blank lines between sections, indented details
