# Generation Output Format Standards

Guidelines for formatting commit message generation output based on verbosity levels.

> **Note:** For validation report formatting, see `agents/report-generator.md`. This file covers generation mode output only.

## Table of Contents

- [Verbosity Levels](#verbosity-levels)
- [Verbosity Selection Guidelines](#verbosity-selection-guidelines)
- [Key Formatting Rules](#key-formatting-rules)

## Verbosity Levels

### Verbose Mode

**Use when:**
- User is learning conventional commits
- Single commit generation
- User explicitly requests detailed explanation
- High uncertainty in type/scope detection

**Output includes:**
- Complete reasoning for type selection
- Detailed scope inference logic
- Confidence levels for decisions
- Alternative options considered
- Step-by-step breakdown of analysis

**Example:**
```
Analyzing staged changes...

Files changed:
  A  src/auth/JwtService.ts
  M  src/auth/AuthController.ts

Type Detection:
  - New file 'JwtService.ts' detected → suggests 'feat'
  - Modified 'AuthController.ts' adds new endpoint → confirms 'feat'
  - No bug fix patterns found
  - No refactoring-only changes

  Confidence: HIGH
  Selected type: feat

Scope Inference:
  - All changes in src/auth/ directory
  - Single module affected
  - Scope: auth

Breaking Changes:
  - No public API changes detected
  - No removed functionality
  - Not a breaking change

Generated message:

feat(auth): add JWT token generation service

Implements JWT token creation with configurable expiration.
Uses HS256 algorithm with secret from environment.
```

---

### Standard Mode

**Use when:**
- Default operation (no special conditions)
- User expects normal output
- Medium confidence in decisions

**Output includes:**
- Core decisions (type, scope, subject)
- Key reasoning points
- Configuration source (if custom config used)
- Warnings or recommendations if applicable

**Example:**
```
Analysis:
- Files changed: A src/auth/JwtService.ts, M src/auth/AuthController.ts
- Type: feat (new functionality detected)
- Scope: auth (changes in src/auth/)
- Breaking changes: None detected

Generated commit message:

feat(auth): add JWT token generation service

Implements JWT token creation with configurable expiration.
Uses HS256 algorithm with secret from environment.
```

---

### Concise Mode

**Use when:**
- User requests summary only
- Quick confirmation needed
- High confidence in all decisions

**Output includes:**
- Final result only
- Critical warnings or errors
- Minimal explanation

**Example:**
```
Generated commit message:

feat(auth): add JWT token generation service

Implements JWT token creation with configurable expiration.
```

---

## Verbosity Selection Guidelines

### Auto-detect based on user request patterns:

**Verbose triggers:**
- "explain why..."
- "show me how you determined..."
- "detailed analysis"
- "walk me through..."

**Standard triggers:**
- "generate commit message"
- Default behavior

**Concise triggers:**
- "quick"
- "just the essentials"
- "summary only"

### Auto-detect based on confidence levels:

- LOW confidence → Verbose (explain reasoning and alternatives)
- MEDIUM confidence → Standard
- HIGH confidence → Standard or Concise

---

## Key Formatting Rules

1. **No Validation Checkmarks**: Generation mode NEVER shows validation checkmarks (✓/✗/⚠). These are only for validation reports.

2. **Brief Analysis Before Message**: Include relevant analysis before presenting the generated message (verbosity-dependent).

3. **Self-Validation Hidden**: Self-validation (Step 6 in SKILL.md) runs internally but is NEVER shown to users in generation output.

4. **Markdown Formatting**:
   - Use `code blocks` for commit messages
   - **Bold** for section headers
   - Blank lines between sections for readability
   - Indentation for nested details
