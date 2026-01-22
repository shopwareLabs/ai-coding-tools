# Type Detection

Determine conventional commit type from git diffs with confidence-based analysis.

## Decision Tree

Apply in priority order:

1. Reverting commit? → `revert`
2. Only docs (*.md, comments)? → `docs`
3. Only formatting/whitespace? → `style`
4. Only test files? → `test`
5. Only build/deps (package.json, Dockerfile)? → `build`
6. Only CI configs (.github/workflows)? → `ci`
7. New functionality added? → `feat`
8. Fixes broken behavior? → `fix`
9. Performance improvements? → `perf`
10. Code restructuring (same behavior)? → `refactor`
11. Otherwise → `chore`

## Confidence Levels

**HIGH**: Single type clearly dominates, no conflicting signals
- New files + exports + routes → feat
- Logic error fix → fix
- Only README.md → docs

**MEDIUM**: Primary type clear with secondary changes
- feat + minor refactor → feat
- Multi-module but related changes

**LOW**: Multiple types equally valid → use AskUserQuestion
- feat + fix equally present
- refactor + perf ambiguous

## User Question Format (LOW Confidence)

When confidence is LOW, ask the user:

```
AskUserQuestion(
  question="Which commit type best describes these changes?",
  header="Commit Type",
  multiSelect=false,
  options=[
    {label: "feat - New feature", description: "Specific reason from diff (~100 chars)"},
    {label: "fix - Bug fix", description: "Specific reason from diff (~100 chars)"}
  ]
)
```

Include 2-4 plausible options. Best guess first.

## Breaking Change Detection

Mark as breaking when:
- API signature changes (required params added/removed)
- Public methods removed or renamed
- Return types changed
- Database schema breaking changes
- Default behavior changed

NOT breaking:
- Internal/private changes
- Optional parameters added
- New methods (additive)

## Examples

### HIGH Confidence: New Feature
Type: `feat`
Reasoning: "New OAuth2Service class with authenticate() method and POST /auth/oauth2 endpoint added"
Breaking: false

### HIGH Confidence: Bug Fix
Type: `fix`
Reasoning: "Changed age check from > to >= to include 18-year-olds - fixes incorrect denial of access"
Breaking: false

### LOW Confidence: Ambiguous
Type: Best guess `feat`
Reasoning: "New v2 API endpoint (feat) and v1 bug fix (fix) both present. Primary unclear."
Action: Ask user with options for feat and fix

### Breaking Change Detected
Type: `feat`
Reasoning: "Response property 'userId' renamed to 'id' - clients expecting userId will fail"
Breaking: true
Breaking reasoning: "Response format changed: userId → id. Existing clients will break."

## Key Principles

1. **Be specific in reasoning** - Reference actual code patterns observed
2. **Don't inflate confidence** - LOW is fine when genuinely uncertain
3. **Breaking changes are critical** - Analyze API compatibility carefully
4. **Mixed changes** - Use dominant type if 80%+, otherwise LOW confidence
