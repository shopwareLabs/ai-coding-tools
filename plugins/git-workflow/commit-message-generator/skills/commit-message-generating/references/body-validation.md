# Body Validation

Validate commit message body: presence, content quality, and migration instructions.

## Presence Checks

**Body Required (FAIL if missing):**
- Breaking changes (when config.require_body_for_breaking: true)
- Type in config.require_body_for_types list

**Body Recommended (WARN if missing):**
- 5+ files changed

**Body Optional:**
- Simple changes, trivial commits (style, docs, chore)

## Content Quality

Check if body explains **WHY** (motivation) not **WHAT** (obvious from code).

**Good signals (WHY):** "caused", "because", "motivation", metrics, user impact, trade-offs

**Bad signals (WHAT):** "Added", "Created", "Updated", "Modified", file names

**Examples:**
- Bad: "Added RedisService class with cache methods"
- Good: "File-based caching caused 60% slower responses with multiple servers. Redis provides shared cache."

## Structure Rules

- Blank line after subject (FAIL if missing)
- Lines ~72 chars (WARN if >87)

## Migration Instructions (Breaking Changes)

For breaking changes, verify body includes:
1. Clear statement of what broke
2. Step-by-step migration instructions
3. Before/after examples

**Bad:** "BREAKING CHANGE: API changed. Update your code."

**Good:**
```
BREAKING CHANGE: Auth endpoint changed from /auth/login to /auth/oauth.

Migration:
1. Register OAuth app
2. Update endpoints
3. Handle redirect flow
```

## Validation Algorithm

1. Check if body required → FAIL if missing when required
2. Check content quality → WARN if just restates code
3. Check structure → FAIL if no blank line after subject
4. For breaking changes: Check migration → FAIL if missing/vague

**Overall Status:** Any FAIL → FAIL | Any WARN → WARN | All PASS → PASS

## Examples

### Missing Body for Breaking Change
Status: FAIL
Checks:
- Presence: FAIL - "Body required for breaking changes"
- Migration: FAIL - "No migration instructions"

Recommendation: Add body explaining impact and migration with step-by-step instructions and before/after examples.

### Good Body
Status: PASS
Checks:
- Presence: PASS - "Body present and provides context"
- Content: PASS - "Explains motivation and includes metrics"
- Structure: PASS - "Proper formatting with paragraphs"

### Body Restates Code
Status: WARN
Checks:
- Presence: PASS - "Body present"
- Content: WARN - "Body describes WHAT changed, not WHY"

Recommendation: Explain motivation - why was this change needed? What problem does it solve?

## Key Principles

1. **Breaking changes always need body + migration**
2. **WHY over WHAT** - Motivation matters more than description
3. **Specific is better** - Metrics, examples, clear steps
4. **Actionable recommendations** - Tell exactly what to add
