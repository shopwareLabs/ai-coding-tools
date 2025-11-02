# Output Format Guidelines

Complete templates and guidance for formatting comment review results with adaptive verbosity levels.

## Table of Contents

- [Output Verbosity Levels](#output-verbosity-levels)
  - [Concise Output](#concise-output)
  - [Standard Output](#standard-output)
  - [Verbose Output](#verbose-output)
- [Choosing Output Verbosity](#choosing-output-verbosity)
- [Validation Report Section](#validation-report-section)
  - [When to Include](#when-to-include)
  - [Verbosity Adaptations](#verbosity-adaptations)
  - [Format Examples](#format-examples)
- [Format Templates](#format-templates)
  - [Concise Format Template](#concise-format-template)
  - [Standard Format Template](#standard-format-template)
  - [Verbose Format Template](#verbose-format-template)
- [Special Cases](#special-cases)

## Output Verbosity Levels

Adapt output detail based on scope size and user intent to balance transparency with token efficiency. The context window is a public good—avoid repetitive detail for large reviews while maintaining clarity.

### Concise Output

**When to use:**
- Large scope reviews
- Batch processing
- User requests summary
- Multiple review sessions

**What to include:**
- Summary statistics (counts by category)
- Flagged comments list (critical issues)
- File count and scope description
- Configuration status

**What to omit:**
- Per-file line-by-line details
- Individual change rationale
- Preserve explanations

**Use case:** User wants quick overview focused on critical issues requiring attention

### Standard Output

**When to use:**
- Medium scope reviews
- Typical use cases
- Default for most reviews
- When transparency matters

**What to include:**
- Configuration details
- Per-file changes with line numbers and categories
- Summary statistics
- Flagged comments section with details

**Use case:** Detailed review with full transparency on what changed and why

### Verbose Output

**When to use:**
- Small scope reviews
- User explicitly requests detailed analysis
- Learning/understanding decisions
- Review-only mode (no edits)

**What to include:**
- Everything in Standard format PLUS:
- Rationale for PRESERVED comments (why preserved)
- Before/after text for improvements
- Configuration pattern matches
- Suggested alternatives for flagged comments
- Decision explanations

**Use case:** Maximum transparency for learning, understanding all decisions made during review

## Choosing Output Verbosity

### Context-Based Selection

**Use Verbose when:**
- Scope is small
- User explicitly requests "detailed report" or "detailed analysis"
- Learning/educational context
- Review-only mode (transparency important)
- Understanding decision rationale matters

**Use Standard when:**
- Typical review workflow
- Transparency expected
- Medium scope
- Default for most use cases
- Full accountability needed

**Use Concise when:**
- Scope is large
- User requests "summary," "overview," or "brief"
- Batch processing workflow
- Focus on critical issues only
- Context efficiency important

### User Intent Overrides

User's explicit request always takes priority:
- "detailed report" → Verbose
- "summary only" → Concise
- "brief overview" → Concise
- No explicit request → Use judgment based on scope and context

### Special Cases

- **Many flagged comments:** Include flagged details even in Concise format
- **No changes needed:** Use minimal format regardless of scope size
- **Errors occurred:** Include error details in any verbosity level
- **User asks questions:** Use Standard or Verbose to explain decisions

## Validation Report Section

Self-validation runs after categorization and before editing to ensure configuration compliance, internal consistency, and logic soundness. Include a validation report section when validation issues are detected or corrections are applied.

### When to Include

**Always include validation report when:**
- Auto-corrections were applied (preserve_pattern violations, consistency issues, logic errors)
- Systematic issues detected (escalation to user required)
- Configuration warnings generated

**Omit validation report when:**
- All validation checks passed with zero corrections
- No issues detected (clean review)

**Placement in output:**
- After "Configuration" section
- Before "Files Reviewed" section

### Verbosity Adaptations

**Concise verbosity:**
- Include only if issues escalated
- Show summary counts only: "Validation: 3 corrections applied"
- Omit correction details

**Standard verbosity:**
- Show summary + correction list
- Include auto-correction log (file:line, before → after, reason)
- Show warnings if present

**Verbose verbosity:**
- Full validation details
- Reasoning for each check category
- Complete correction log with explanations
- Validation decision explanations

### Format Examples

#### Standard Verbosity Template

```markdown
### Validation Report ✓

**Checks Run:** 5 categories, {N} items validated

**Auto-Corrections:** {M} applied
- {File}:{line} - {OLD_CATEGORY} → {NEW_CATEGORY} (reason: {explanation})
- {File}:{line} - Uncertainty {OLD_LEVEL} → {NEW_LEVEL} (reason: {explanation})
[... list all corrections ...]

**Warnings:** {W} (if any)
- {Warning description}

**Result:** {All checks passed | Issues escalated requiring user review}
```

**Example (with corrections):**
```markdown
### Validation Report ✓

**Checks Run:** 5 categories, 247 items validated

**Auto-Corrections:** 4 applied
- UserService.php:45 - REMOVE → PRESERVE (matches preserve_pattern "TODO\\(\\w+\\)")
- AuthService.php:78 - REMOVE → PRESERVE (obvious but has external ref: RFC 6749)
- CacheService.php:102 - Uncertainty MEDIUM → HIGH (file in conservative_paths)
- PaymentService.php:134 - IMPROVE added to verification (may still be vague)

**Warnings:** 1
- LogService.php - 2 comments not categorized, defaulted to PRESERVE

**Result:** All critical checks passed. Review can proceed.
```

**Example (clean review, no corrections):**
```markdown
### Validation Report ✓

**Checks Run:** 5 categories, 89 items validated

**Result:** All checks passed. No corrections needed.
```

#### Verbose Verbosity Template

```markdown
### Validation Report ✓ (Detailed)

**Configuration Compliance:** {PASS|FAIL} ({N} corrections)
1. Preserve Pattern Violations: {count} found, corrected
   - {File}:{line} - Comment matched "{pattern}" pattern
   [... detail each violation ...]

2. Exemption Markers: {count} found, corrected
   - {File}:{line} - Contains {marker} marker

**Consistency Checks:** {PASS|FAIL} ({N} corrections)
- Duplicate categorization: "{comment text}" standardized to {CATEGORY} across {count} files
- Conflicting categorizations: {count} resolved

**Categorization Logic:** {PASS|FAIL}
- Obvious removals with external references: {count} recategorized to PRESERVE
- Improvements lacking WHY context: {count} escalated to HIGH uncertainty

**Uncertainty Alignment:** {PASS|FAIL} ({N} escalations)
- {File}:{line} - Escalated to HIGH (in conservative_paths)

**Completeness:** {PASS|WARNINGS}
- {File} - {count} uncategorized comments defaulted to PRESERVE

**Result:** All critical checks passed. {N} corrections applied. Review proceeding.
```

#### Concise Verbosity Template

Only include if systematic issues require escalation:

```markdown
### Validation Report ⚠️

**ESCALATION REQUIRED**

Systematic issue detected: {violation_type} affects {count} comments ({percentage}%).
Configuration may need review.

[Details above]
```

Otherwise omit entirely for concise output.

#### Escalation Format (all verbosity levels)

When validation detects systematic issues:

```markdown
### Validation Report ⚠️

**CRITICAL: Systematic Issue Detected**

**Issue:** {violation_type} violations affect {count} comments ({percentage}% of categorizations)

**Examples:**
1. {File}:{line} - {description}
2. {File}:{line} - {description}
3. {File}:{line} - {description}

**Recommendation:** {specific guidance for user}

**Options:**
1. Review configuration ({setting}) and adjust pattern/rules
2. Continue with current categorizations (accept corrections)
3. Cancel review and reconsider approach

Please indicate how to proceed.
```

### Integration with Existing Sections

**Complete output structure:**

```markdown
## Comment Review Results

### Configuration
[Configuration details]

### Validation Report ✓
[Validation report - only if corrections applied or issues detected]

### Files Reviewed: [scope]
[Per-file changes or summary]

### Changes Requiring Verification ⚠️
[HIGH/MEDIUM uncertainty items]

### Summary
[Statistics]

### Flagged Comments
[Inconsistencies requiring attention]
```

**Note:** Validation report appears after Configuration but before Files Reviewed, providing transparency about categorization quality before showing the actual changes.

## Format Templates

### Concise Format Template

```markdown
## Comment Review Results

### Files Reviewed: [scope description] ([N] files)
Configuration: [Loaded from .reviewrc.md | Using default rules]

### Summary
- **Removed**: X redundant comments
- **Improved**: Y vague implementation comments with specific "why" context
- **Condensed (implementation)**: Z verbose implementation comments (preserved WHY, removed redundancy)
- **Condensed (API)**: N verbose API documentation (made concise with vital info only)
- **Flagged**: M comments requiring human verification (potential inconsistencies)
- **Preserved**: P valuable comments with important context
- **Files changed**: Q

### Flagged Comments Requiring Attention
[Only if flagged > 0]
Review these for potential inconsistencies:
1. **file.php:102** - Comment claims "returns full name" but code returns email (comment vs code mismatch)
2. **file.ts:56** - TODO missing owner and ticket - suggest: `TODO(owner): specific action - TICKET-123`
3. **utils.js:89** - Comment describes sorting but function filters (behavior mismatch)
[...more as needed]
```

**Example (No Flagged Comments):**
```markdown
## Comment Review Results

### Files Reviewed: src/services/ (45 files)
Configuration: Loaded from .reviewrc.md (3 ignore paths, 2 preserve patterns)

### Summary
- **Removed**: 23 redundant comments
- **Improved**: 12 vague implementation comments with specific "why" context
- **Condensed (implementation)**: 8 verbose implementation comments (preserved WHY, removed redundancy)
- **Condensed (API)**: 5 verbose API documentation (made concise with vital info only)
- **Flagged**: 3 comments requiring human verification (potential inconsistencies)
- **Preserved**: 15 valuable comments with important context
- **Files changed**: 32

### Flagged Comments Requiring Attention
Review these for potential inconsistencies:
1. **UserService.php:234** - TODO missing owner and ticket
2. **PaymentService.php:156** - Comment claims "never null" but code allows null
3. **OrderService.php:89** - Return value mismatch: comment says array, code returns object
```

### Standard Format Template

```markdown
## Comment Review Results

### Configuration
[If loaded]: Loaded from .reviewrc.md (X ignore paths, Y preserve patterns, Z ticket format, ...)
[If not found]: Using default rules (no configuration file found)
[If errors]: Warning: [specific error message] - continuing with defaults

### Files Reviewed: [scope description]

**Per-File Changes** (list each modified file with line-specific details):

**path/to/file.php**
- Line 45: Removed "// Get user by ID" (redundant implementation comment)
- Line 67: Improved "// Process data" → "// Sanitize HTML to prevent XSS attacks per OWASP" (vague implementation comment)
- Line 89: CONDENSED "// Normalize path for consistent matching regardless of format" → "// Normalize path to match stored URL patterns (leading slash, no trailing slash)" (verbose implementation comment with good WHY)
- Line 102: PRESERVED "// Workaround for bug #4521 - remove after v6.7" (important context)
- Line 120: FLAGGED "// Returns full name" but function get_email() returns email (inconsistent with implementation)
- Line 145: CONDENSED PHPDoc from 15 lines listing implementation phases → brief purpose + vital info only (verbose API documentation)

**path/to/another-file.ts**
- Line 23: Removed "// Constructor" (obvious)
- Line 56: FLAGGED "// TODO: fix this" missing owner and ticket reference
- Line 78: PRESERVED "// Implements RFC 6749 OAuth 2.0 section 4.1" (external reference)

### Summary
- **Removed**: X redundant comments
- **Improved**: Y vague implementation comments with specific "why" context
- **Condensed (implementation)**: Z verbose implementation comments (preserved WHY, removed redundancy)
- **Condensed (API)**: N verbose API documentation (made concise with vital info only)
- **Flagged**: M comments requiring human verification (potential inconsistencies)
- **Preserved**: P valuable comments with important context
- **Files changed**: Q

### Flagged Comments Requiring Attention
Review these for potential inconsistencies:
1. **file.php:102** - Comment claims "returns full name" but code returns email (comment vs code mismatch)
2. **file.ts:56** - TODO missing owner and ticket - suggest: `TODO(owner): specific action - TICKET-123`
```

**No Changes Case:**
```markdown
## Comment Review Results

### Files Reviewed: [scope description]

All comments in [scope] follow best practices. No changes needed.
```

### Verbose Format Template

Verbose format includes everything from Standard format, PLUS additional decision details:

```markdown
[Start with Standard Format]

### Preserved Comments (Detailed Rationale)

**path/to/file.php**
- Line 102: PRESERVED "// Workaround for bug #4521 - remove after v6.7"
  - **Reason**: Bug reference with removal timeline
  - **Category**: Workaround with tracking
  - **Matches config pattern**: `preserve_patterns: "bug #\d+"`

- Line 234: PRESERVED "// Implements OAuth 2.0 RFC 6749 section 4.1"
  - **Reason**: External specification reference
  - **Category**: External reference
  - **Standard**: RFC 6749

- Line 345: PRESERVED "// Use binary search for O(log n) lookup - required for <50ms SLA"
  - **Reason**: Algorithm choice with performance constraint
  - **Category**: Performance requirement
  - **Constraint**: 50ms SLA

### Improvement Details (Before/After)

**path/to/file.php**
- Line 67: Improved vague comment
  - **Before**: `// Process data`
  - **After**: `// Sanitize HTML to prevent XSS attacks per OWASP guidelines`
  - **Why improved**: Added specific threat (XSS), action (sanitize), and standard (OWASP)
  - **Category**: Vague → Specific with security context

- Line 156: Improved vague comment
  - **Before**: `// Validate input`
  - **After**: `// Ensure amount doesn't exceed $10,000 per business rule BR-2019`
  - **Why improved**: Added constraint ($10,000) and business rule reference (BR-2019)
  - **Category**: Vague → Specific with constraint

### Condensation Details

**path/to/file.php**
- Line 89: Condensed verbose implementation comment
  - **Before**: `// Normalize path to match stored URL patterns. Routes are persisted with leading slash and no trailing slash. This normalization ensures consistent matching regardless of how the client formats the request path.`
  - **After**: `// Normalize path to match stored URL patterns (leading slash, no trailing slash)`
  - **Token savings**: 35 words → 12 words (66% reduction)
  - **WHY preserved**: Match stored patterns, format constraint

- Line 145: Condensed verbose API documentation
  - **Before**: 15-line PHPDoc listing all pipeline phases, internal service calls, and data flow
  - **After**: Brief purpose + performance constraint + exception conditions only
  - **Token savings**: ~200 tokens → ~60 tokens (70% reduction)
  - **Contract preserved**: What it does, what it throws, performance characteristics
```

## Special Cases

### Large Batch Reviews

For very large reviews where scope is overwhelming:
- Use Concise format
- Consider reporting in batches with progress indicators
- Focus summary on high-priority issues
- Always include flagged comments (critical)

### Review-Only Mode (No Edits)

When user requests analysis without changes:
- Default to Standard format (transparency)
- Include proposed changes with "WOULD" language:
  - "WOULD Remove", "WOULD Improve", "WOULD Condense"
- No confirmation prompts needed
- Focus on recommendations

### Interactive Mode

When user wants to review before applying:
- Use Standard format for proposal
- After user confirms, use Concise for applied changes
- Focus final report on "Changes Applied" summary

### Error Cases

If errors occur during review:
- Always include error details regardless of verbosity
- List affected files
- Explain what was skipped and why
- Provide suggestions for resolution

### Mixed Results

If some files succeeded and others failed:
- Separate successful changes from errors
- Use appropriate verbosity for successful portion
- Always detail errors (critical information)

Example:
```markdown
## Comment Review Results

### Successfully Reviewed: src/services/ (42 of 45 files)

[Concise/Standard/Verbose format for successful files]

### Errors Encountered (3 files)
1. **src/LegacyService.php** - File not writable (permissions issue)
2. **src/GeneratedProxy.php** - Skipped (detected @generated marker)
3. **src/ConfigService.php** - Edit failed: string not unique (line 234)
```
