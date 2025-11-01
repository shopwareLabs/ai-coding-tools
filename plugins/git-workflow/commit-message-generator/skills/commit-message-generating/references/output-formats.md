# Output Format Standards

Guidelines for adapting output verbosity based on context, user intent, and operation scope.

## Table of Contents

- [Verbosity Levels](#verbosity-levels)
- [Verbosity Selection Guidelines](#verbosity-selection-guidelines)
- [Validation Report Templates](#validation-report-templates)
- [Markdown Formatting](#markdown-formatting)

## Verbosity Levels

### Verbose Mode

**Use when:**
- User is learning conventional commits
- Single commit generation or validation
- User explicitly requests detailed explanation
- High uncertainty in type/scope detection

**Output includes:**
- Complete reasoning for type selection
- Detailed scope inference logic
- Confidence levels for decisions
- Alternative options considered
- Full reference to configuration used
- Step-by-step breakdown of analysis

**Example (Generation):**
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

**Example (Generation):**
```
Generated commit message:

feat(auth): add JWT token generation service

Implements JWT token creation with configurable expiration.
Uses HS256 algorithm with secret from environment.

---
Type: feat (new functionality detected)
Scope: auth (changes in src/auth/)
```

**Example (Validation):**
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

### Concise Mode

**Use when:**
- Batch validation of multiple commits
- User requests summary only
- Quick confirmation needed
- High confidence in all decisions

**Output includes:**
- Final result only
- Critical warnings or errors
- Minimal explanation

**Example (Generation):**
```
feat(auth): add JWT token generation service

Implements JWT token creation with configurable expiration.
```

**Example (Validation - Success):**
```
✓ Commit abc123f: Valid conventional commit
```

**Example (Validation - Failure):**
```
✗ Commit abc123f: Type mismatch
  Message says 'feat' but changes only modify existing code (should be 'refactor')
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
- "validate commit"
- "check HEAD"
- "generate commit message"

**Concise triggers:**
- "quick check"
- "just the essentials"
- "quick summary"
- Batch operations (multiple commits)

### Auto-detect based on operation scope:

- Single commit → Standard or Verbose
- Multiple commits → Concise
- Batch validation → Concise

### Auto-detect based on confidence levels:

- LOW confidence → Verbose (explain reasoning and alternatives)
- MEDIUM confidence → Standard
- HIGH confidence → Standard or Concise

### Auto-detect based on error conditions:

- Format violations → Standard (show what's wrong)
- Consistency issues → Standard (explain mismatch)
- Configuration errors → Standard (show fallback)

---

## Validation Report Templates

### Full Report (Standard/Verbose)

```
Commit Message Validation Report
=================================

Commit: <sha>
Message: "<full message>"

Format Compliance: [PASS/FAIL]
  [✓/✗] Valid type
  [✓/✗] Scope format
  [✓/✗] Subject format
  [✓/✗] Length constraints
  [✓/✗] Breaking change markers

Consistency Check: [PASS/WARN/FAIL]
  [✓/⚠/✗] Type matches changes
  [✓/⚠/✗] Scope accurate
  [✓/⚠/✗] Subject describes changes
  [✓/⚠/✗] Breaking changes marked

Recommendations:
  1. <specific suggestion>
  2. <specific suggestion>
```

### Compact Report (Concise)

```
[✓/✗] Commit <sha>: <status>
  <critical issues only>
```

---

## Markdown Formatting

Use consistent formatting:
- **Bold** for section headers and important terms
- `Code blocks` for commands and commit messages
- ✓ ✗ ⚠ symbols for pass/fail/warn status
- Indentation for nested details
- Blank lines between sections for readability
