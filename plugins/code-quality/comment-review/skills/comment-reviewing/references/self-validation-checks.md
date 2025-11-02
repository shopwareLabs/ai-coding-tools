# Self-Validation Checks

Detailed validation rules and auto-correction logic for comment review categorizations. Load this reference when validation issues are detected during the review process.

## Table of Contents

- [Overview](#overview)
- [Validation Categories](#validation-categories)
  - [1. Configuration Compliance Checks](#1-configuration-compliance-checks)
    - [Check 1.1: Preserve Pattern Violations](#check-11-preserve-pattern-violations)
    - [Check 1.2: Ignore Paths Violations](#check-12-ignore-paths-violations)
    - [Check 1.3: Exemption Marker Violations](#check-13-exemption-marker-violations)
    - [Check 1.4: Conservative Paths Violations](#check-14-conservative-paths-violations)
  - [2. Consistency Checks](#2-consistency-checks)
    - [Check 2.1: Duplicate Comment Categorization](#check-21-duplicate-comment-categorization)
    - [Check 2.2: Conflicting Categorizations](#check-22-conflicting-categorizations)
    - [Check 2.3: Circular Logic Violations](#check-23-circular-logic-violations)
  - [3. Categorization Logic Checks](#3-categorization-logic-checks)
    - [Check 3.1: Obvious Removal Contains External References](#check-31-obvious-removal-contains-external-references)
    - [Check 3.2: Obvious Removal Contains Warnings](#check-32-obvious-removal-contains-warnings)
    - [Check 3.3: Improvement Still Vague](#check-33-improvement-still-vague)
    - [Check 3.4: Condensation Removes Essential Information](#check-34-condensation-removes-essential-information)
  - [4. Uncertainty Alignment Checks](#4-uncertainty-alignment-checks)
    - [Check 4.1: High Uncertainty Tracking](#check-41-high-uncertainty-tracking)
    - [Check 4.2: Conservative Paths Uncertainty Escalation](#check-42-conservative-paths-uncertainty-escalation)
    - [Check 4.3: Content Signal Detection](#check-43-content-signal-detection)
  - [5. Completeness Checks](#5-completeness-checks)
    - [Check 5.1: Files in Scope Not Reviewed](#check-51-files-in-scope-not-reviewed)
    - [Check 5.2: Comments Not Categorized](#check-52-comments-not-categorized)
- [Validation Flow Logic](#validation-flow-logic)
  - [Single-Pass Validation](#single-pass-validation)
  - [Auto-Correction Priority](#auto-correction-priority)
- [Escalation Conditions](#escalation-conditions)
  - [Immediate Escalation (Stop Review)](#immediate-escalation-stop-review)
  - [Log and Continue](#log-and-continue)
- [Edge Case Handling](#edge-case-handling)
  - [Conflicting Rules](#conflicting-rules)
  - [Large Batch Operations](#large-batch-operations)
  - [Read-Only Mode](#read-only-mode)
  - [Interactive Mode](#interactive-mode)
- [Validation Report Format](#validation-report-format)
  - [Standard Verbosity](#standard-verbosity)
  - [Example Report](#example-report)
  - [Verbose Report](#verbose-report)
  - [Concise Report](#concise-report)
- [Summary](#summary)

## Overview

Self-validation runs **after comment categorization** and **before editing** to ensure:
- Configuration rules are respected
- Categorizations are internally consistent
- Logic rules are followed
- Uncertainty evaluation is aligned
- Review scope is complete

## Validation Categories

### 1. Configuration Compliance Checks

**Purpose:** Ensure project configuration rules are respected

#### Check 1.1: Preserve Pattern Violations

**Rule:** Comments matching `preserve_patterns` must not be removed, improved, or condensed

**Detection:**
```
FOR each categorization in [REMOVE, IMPROVE, CONDENSE]:
  IF comment text matches any preserve_pattern:
    VIOLATION DETECTED
```

**Auto-correction:**
- Re-categorize to PRESERVE
- Log: "File:line - {category} → PRESERVE (matches preserve_pattern '{pattern}')"
- Remove from change list

**Example:**
```
Comment: // TODO(john): Refactor after Q1 release - JIRA-1234
preserve_patterns: ["TODO\\(\\w+\\): .+ - [A-Z]+-\\d+"]
Initial: REMOVE (looks complete, but matches pattern)
Validation: FAIL - Matches preserve_pattern
Auto-fix: Re-categorize to PRESERVE
```

#### Check 1.2: Ignore Paths Violations

**Rule:** Files in `ignore_paths` must not be edited

**Detection:**
```
FOR each file with categorizations:
  IF file path matches any ignore_paths pattern:
    VIOLATION DETECTED
```

**Auto-correction:**
- Remove all categorizations for that file
- Log: "File {path} - Excluded (matches ignore_paths pattern '{pattern}')"
- Skip file entirely

**Example:**
```
File: vendor/symfony/Component.php
ignore_paths: ["vendor/**"]
Initial: 5 comments categorized
Validation: FAIL - File in ignore_paths
Auto-fix: Remove all categorizations, skip file
```

#### Check 1.3: Exemption Marker Violations

**Rule:** Comments containing `exemption_markers` must not be modified

**Detection:**
```
FOR each categorization in [REMOVE, IMPROVE, CONDENSE]:
  IF comment contains any exemption_marker:
    VIOLATION DETECTED
```

**Auto-correction:**
- Re-categorize to PRESERVE
- Log: "File:line - {category} → PRESERVE (contains exemption marker '{marker}')"

**Example:**
```
Comment: // @no-review This is a complex workaround
exemption_markers: ["@no-review"]
Initial: IMPROVE (vague)
Validation: FAIL - Contains exemption marker
Auto-fix: Re-categorize to PRESERVE
```

#### Check 1.4: Conservative Paths Violations

**Rule:** Changes in `conservative_paths` require explicit HIGH uncertainty justification

**Detection:**
```
FOR each categorization in conservative_paths files:
  IF categorization is substantive (not typo/formatting):
    IF uncertainty level != HIGH:
      VIOLATION DETECTED
```

**Auto-correction:**
- Escalate uncertainty to HIGH
- Add to verification tracking
- Generate specific verification prompt
- Log: "File:line - Uncertainty LOW → HIGH (file in conservative_paths)"

**Example:**
```
File: src/Legacy/OldSystem.php (in conservative_paths)
Comment: // Process data
Initial: IMPROVE → "// Sanitize input" (uncertainty: MEDIUM)
Validation: FAIL - Substantive change in conservative path without HIGH uncertainty
Auto-fix: Escalate uncertainty to HIGH, add verification prompt
```

### 2. Consistency Checks

**Purpose:** Ensure categorizations are internally coherent

#### Check 2.1: Duplicate Comment Categorization

**Rule:** Identical comment text should be categorized consistently across files

**Detection:**
```
BUILD map: comment_text → [categorizations]
FOR each comment_text with multiple categorizations:
  IF categorizations differ:
    VIOLATION DETECTED
```

**Auto-correction:**
- Apply most conservative categorization to all instances
- Conservative order: PRESERVE > FLAG > IMPROVE > CONDENSE > REMOVE
- Log: "Comments '{text}' - Standardized to {conservative_category} across {count} files"

**Example:**
```
Comment: "// Validate input"
File A: REMOVE (obvious)
File B: PRESERVE (might have context)
Validation: FAIL - Inconsistent categorization
Auto-fix: Both → PRESERVE (most conservative)
```

#### Check 2.2: Conflicting Categorizations

**Rule:** A comment cannot be both flagged and modified

**Detection:**
```
FOR each comment:
  IF categorization == FLAG:
    IF also in [REMOVE, IMPROVE, CONDENSE]:
      VIOLATION DETECTED
```

**Auto-correction:**
- Keep FLAG, remove other categorization
- Log: "File:line - Removed {category}, kept FLAG (conflicting actions)"

**Example:**
```
Comment: // Returns user name
Function: getUserEmail()
Initial: FLAG (inconsistent) + REMOVE (obvious)
Validation: FAIL - Cannot flag and remove
Auto-fix: Keep FLAG, remove REMOVE categorization
```

#### Check 2.3: Circular Logic Violations

**Rule:** Cannot mark for removal if already identified as valuable

**Detection:**
```
FOR each REMOVE categorization:
  IF comment contains preservation signals:
    - External references (ticket #, RFC, bug #)
    - Security/performance warnings
    - Algorithm explanations
    - Design decisions
    VIOLATION DETECTED
```

**Auto-correction:**
- Re-categorize to PRESERVE
- Log: "File:line - REMOVE → PRESERVE (contains preservation signal: {signal})"

**Example:**
```
Comment: // Workaround for MySQL bug #4521 - returns cached value
Initial: REMOVE (redundant with function name getCachedValue)
Validation: FAIL - Contains preservation signal (bug #4521)
Auto-fix: Re-categorize to PRESERVE
```

### 3. Categorization Logic Checks

**Purpose:** Validate quality of categorization reasoning

#### Check 3.1: Obvious Removal Contains External References

**Rule:** "Obvious" removals must not contain external references

**Detection:**
```
FOR each REMOVE categorization:
  IF removal reason == "obvious":
    IF comment matches external_ref_patterns:
      - Ticket: JIRA-\d+, #\d+, TICKET-\d+
      - RFC: RFC \d+, RFC-\d+
      - Bug: bug #\d+, issue #\d+
      - Standard: ISO \d+, OWASP, PCI-DSS
      VIOLATION DETECTED
```

**Auto-correction:**
- Re-categorize to PRESERVE
- Log: "File:line - REMOVE → PRESERVE (obvious but has external ref: {ref})"

**Example:**
```
Comment: // Implements RFC 6749 OAuth 2.0
Function: authenticateUser()
Initial: REMOVE (obvious from function name)
Validation: FAIL - Contains external reference RFC 6749
Auto-fix: Re-categorize to PRESERVE
```

#### Check 3.2: Obvious Removal Contains Warnings

**Rule:** "Obvious" removals must not contain security/performance/safety warnings

**Detection:**
```
FOR each REMOVE categorization:
  IF comment contains warning keywords:
    - Security: XSS, injection, CSRF, sanitize, escape, auth
    - Performance: O(n), complexity, cache, optimize, slow
    - Safety: critical, dangerous, careful, must, never
    VIOLATION DETECTED
```

**Auto-correction:**
- Re-categorize to PRESERVE
- Log: "File:line - REMOVE → PRESERVE (contains warning: {keyword})"

**Example:**
```
Comment: // Sanitize to prevent XSS
Function: renderHtml(input)
Initial: REMOVE (obvious from function name)
Validation: FAIL - Contains security warning (XSS)
Auto-fix: Re-categorize to PRESERVE
```

#### Check 3.3: Improvement Still Vague

**Rule:** Improved comments must add WHY context, not just rephrase WHAT

**Detection:**
```
FOR each IMPROVE categorization:
  IF improved_text contains only generic verbs:
    - Process, handle, manage, deal with, work with
  AND lacks WHY signals:
    - No: because, due to, prevents, avoids, enables, ensures
    - No: external references
    - No: specific constraints/thresholds
    VIOLATION DETECTED
```

**Auto-correction:**
- Escalate uncertainty to HIGH
- Add to verification tracking with prompt: "Verify improvement adds WHY context"
- Do NOT block the improvement (might be best effort)
- Log: "File:line - IMPROVE flagged for verification (may still be vague)"

**Example:**
```
Original: // Process data
Improved: // Handle user data processing
Validation: FAIL - Still vague, lacks WHY
Auto-fix: Keep improvement but escalate to HIGH uncertainty with verification prompt
```

#### Check 3.4: Condensation Removes Essential Information

**Rule:** Condensed comments must preserve all essential information

**Detection:**
```
FOR each CONDENSE categorization:
  IF removed_content contains:
    - Specific numbers/thresholds
    - External references (tickets, RFCs)
    - Constraint language (must, cannot, only, never)
    - Trade-off explanations (but, however, vs)
    VIOLATION DETECTED
```

**Auto-correction:**
- Re-categorize to PRESERVE (keep original)
- OR: Escalate to HIGH uncertainty if condensation seems valuable
- Log: "File:line - CONDENSE → PRESERVE (removes essential info: {type})"

**Example:**
```
Original: // Cache expires after 300 seconds due to OAuth token lifetime per RFC 6749
Condensed: // Cache expires after 5 minutes
Validation: FAIL - Removed external reference (RFC 6749) and rationale
Auto-fix: Re-categorize to PRESERVE
```

### 4. Uncertainty Alignment Checks

**Purpose:** Ensure uncertainty evaluation integrates with validation

#### Check 4.1: High Uncertainty Tracking

**Rule:** All HIGH uncertainty items must be tracked in verification list

**Detection:**
```
FOR each categorization with uncertainty == HIGH:
  IF NOT in verification_tracking_list:
    VIOLATION DETECTED
```

**Auto-correction:**
- Add to verification tracking
- Generate specific verification prompt based on change type
- Log: "File:line - Added HIGH uncertainty item to verification tracking"

**Example:**
```
Comment: Examples removed from interface documentation
Uncertainty: HIGH
Verification list: [empty]
Validation: FAIL - HIGH uncertainty not tracked
Auto-fix: Add to tracking with prompt "Verify examples documented elsewhere"
```

#### Check 4.2: Conservative Paths Uncertainty Escalation

**Rule:** Substantive changes in `conservative_paths` must have HIGH uncertainty

**Detection:**
```
FOR each categorization in conservative_paths:
  IF change is substantive (not typo/formatting):
    IF uncertainty < HIGH:
      VIOLATION DETECTED
```

**Auto-correction:**
- Escalate uncertainty to HIGH
- Add to verification tracking
- Log: "File:line - Uncertainty escalated to HIGH (conservative path)"

**Example:**
```
File: src/Legacy/OldPaymentSystem.php (in conservative_paths)
Change: Remove algorithm explanation
Uncertainty: MEDIUM
Validation: FAIL - Conservative path requires HIGH uncertainty
Auto-fix: Escalate to HIGH, add verification prompt
```

#### Check 4.3: Content Signal Detection

**Rule:** Changes removing content signals must be evaluated for uncertainty

**Detection:**
```
FOR each categorization that removes content:
  IF removed_content contains content_signals:
    - References: ticket #, RFC, bug #, issue #
    - Examples: "e.g.", "like", quoted patterns
    - Constraints: must, cannot, only, required
    - Rationale: because, prevents, due to
    - Trade-offs: but, however, X vs Y
    - Behavior: ORM terms, SQL terms, framework APIs
    - Context: specific numbers, thresholds, formats
  IF uncertainty == LOW:
    VIOLATION DETECTED
```

**Auto-correction:**
- Escalate uncertainty to at least MEDIUM
- If multiple signals: escalate to HIGH
- Log: "File:line - Uncertainty LOW → {MEDIUM|HIGH} (content signals: {signals})"

**Example:**
```
Comment: // Must validate email format per RFC 5322 because downstream systems require it
Change: REMOVE (obvious)
Uncertainty: LOW
Validation: FAIL - Contains multiple content signals (constraint "must", reference "RFC 5322", rationale "because")
Auto-fix: Escalate to HIGH uncertainty, add verification tracking
```

### 5. Completeness Checks

**Purpose:** Ensure review scope is complete

#### Check 5.1: Files in Scope Not Reviewed

**Rule:** All files in review scope should be analyzed

**Detection:**
```
expected_files = get_files_in_scope(scope_pattern)
reviewed_files = get_reviewed_files()
IF expected_files - reviewed_files != empty:
  VIOLATION DETECTED
```

**Auto-correction:**
- CANNOT auto-fix
- Report to user with file list
- User decides: expand review or accept partial coverage

**Example:**
```
Scope: src/services/
Expected: 15 files
Reviewed: 12 files
Missing: AuthService.php, CacheService.php, LoggerService.php
Validation: FAIL - Incomplete coverage
Escalation: "Review incomplete. Missing files: {list}. Continue with partial review?"
```

#### Check 5.2: Comments Not Categorized

**Rule:** All comments in reviewed files should be categorized

**Detection:**
```
FOR each reviewed_file:
  all_comments = extract_all_comments(file)
  categorized_comments = get_categorized_comments(file)
  IF all_comments - categorized_comments != empty:
    VIOLATION DETECTED
```

**Auto-correction:**
- CANNOT fully auto-fix
- Default uncategorized to PRESERVE (safe)
- Log: "File:line - Comment not categorized, defaulted to PRESERVE"

**Example:**
```
File: UserService.php
All comments: 20
Categorized: 18
Uncategorized: 2 (lines 45, 78)
Validation: FAIL - Missing categorizations
Auto-fix: Default to PRESERVE, log for transparency
```

## Validation Flow Logic

### Single-Pass Validation

```
FUNCTION validate_categorizations():
  violations = []
  corrections = []

  // Run all 5 validation categories
  violations_1 = check_configuration_compliance()
  violations_2 = check_consistency()
  violations_3 = check_categorization_logic()
  violations_4 = check_uncertainty_alignment()
  violations_5 = check_completeness()

  violations = violations_1 + violations_2 + violations_3 + violations_4 + violations_5

  // Apply auto-corrections
  FOR each violation in violations:
    IF violation.can_auto_correct:
      correction = apply_auto_correction(violation)
      corrections.append(correction)
    ELSE:
      escalate_to_user(violation)

  // Detect systematic issues
  IF has_systematic_pattern(violations):
    escalate_immediately(violations)
    STOP

  // Generate validation report
  report = generate_validation_report(violations, corrections)

  RETURN report
```

### Auto-Correction Priority

When multiple violations affect the same comment, apply in this order:

1. **Configuration compliance** (highest priority)
   - preserve_patterns, exemption_markers override all other logic

2. **Consistency checks**
   - Apply most conservative categorization

3. **Logic checks**
   - Preserve over modify when in doubt

4. **Uncertainty alignment**
   - Escalate to higher uncertainty level

5. **Completeness**
   - Default to PRESERVE for uncategorized

## Escalation Conditions

### Immediate Escalation (Stop Review)

**Systematic rule violations:**
```
IF count(same_violation_type) > 10% of total_categorizations:
  STOP and escalate:
  "Systematic issue detected: {violation_type} affects {count} comments ({percentage}%).
   Examples: {first_3_examples}
   This suggests a pattern. Should the categorization strategy be adjusted?"
```

**Example:**
```
Total categorizations: 100
REMOVE → PRESERVE corrections (preserve_pattern): 15
Validation: STOP - 15% of removals violated preserve_pattern
Escalation: User must review preserve_pattern configuration or categorization approach
```

**Configuration pattern errors:**
```
IF preserve_pattern matches 0 comments:
  WARN: "preserve_pattern '{pattern}' didn't match any comments. Is this intentional?"

IF preserve_pattern matches >80% of comments:
  STOP and escalate:
  "preserve_pattern '{pattern}' matches {percentage}% of comments.
   This effectively prevents most changes. Review pattern?"
```

**Conflicting configuration:**
```
IF same comment matches:
  - preserve_pattern (keep)
  - ignore_paths (skip)
  - conservative_paths (caution)

  STOP and escalate:
  "Configuration conflict: {file}:{line} matches multiple rules.
   Precedence: ignore_paths > preserve_pattern > conservative_paths
   Is this configuration correct?"
```

### Log and Continue

**Individual auto-correctable violations:**
- Apply correction
- Log in validation report
- No user intervention needed

**Minor inconsistencies:**
- Apply conservative choice
- Document reasoning
- Continue review

## Edge Case Handling

### Conflicting Rules

**preserve_pattern + conservative_paths:**
- Precedence: preserve_pattern wins
- Action: PRESERVE comment
- Log: "Preserved due to preserve_pattern (overrides conservative_paths)"

**exemption_marker + FLAG:**
- Precedence: exemption_marker wins
- Action: PRESERVE (don't flag)
- Log: "Preserved due to exemption marker (overrides FLAG)"

**ignore_paths + everything:**
- Precedence: ignore_paths wins
- Action: Skip file entirely
- Log: "File skipped (matches ignore_paths)"

### Large Batch Operations

**Performance optimization:**
```
IF total_categorizations > 1000:
  // Batch validation checks
  group_by_violation_type()
  apply_corrections_in_batch()
  summarize_instead_of_itemize()
```

**Example:**
```
Total: 2,500 categorizations across 150 files
Validation approach:
- Group similar violations
- Apply batch corrections
- Report: "15 preserve_pattern violations corrected across 8 files"
  (instead of listing all 15 individually)
```

### Read-Only Mode

**When user requested analysis without edits:**
```
IF mode == READ_ONLY:
  // Still run validation
  violations = validate_categorizations()
  // Don't auto-correct
  REPORT violations instead of correcting
```

**Example output:**
```
Validation Issues (Read-Only Mode):
- 3 categorizations would violate preserve_patterns
- 2 inconsistent categorizations detected
- 1 obvious removal contains external reference

These would be auto-corrected in edit mode.
```

### Interactive Mode

**When user wants to approve changes:**
```
IF mode == INTERACTIVE:
  violations = validate_categorizations()
  corrections = apply_auto_corrections(violations)

  // Present corrected categorizations to user
  show_preview_with_corrections()
  wait_for_user_approval()
```

## Validation Report Format

### Standard Verbosity

```markdown
### Validation Report ✓

**Checks Run:** 5 categories, {count} items validated
**Auto-Corrections:** {correction_count} applied
{correction_list}

**Result:** {PASS|WARNINGS|ESCALATED}
```

### Example Report

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

### Verbose Report

Include reasoning for each check:

```markdown
### Validation Report ✓ (Detailed)

**Configuration Compliance:** PASS (3 corrections)
1. Preserve Pattern Violations: 2 found, corrected
   - UserService.php:45 - Comment matched "TODO\\(\\w+\\)" pattern
   - Helper.php:120 - Comment matched "@internal" pattern
2. Exemption Markers: 1 found, corrected
   - CacheService.php:67 - Contains @no-review marker

**Consistency Checks:** PASS (1 correction)
- Duplicate categorization: "// Validate input" standardized to PRESERVE across 3 files

**Categorization Logic:** PASS
- No obvious removals with external references
- No improvements lacking WHY context

**Uncertainty Alignment:** PASS (1 escalation)
- CacheService.php:102 - Escalated to HIGH (in conservative_paths)

**Completeness:** WARNINGS (non-critical)
- LogService.php - 2 uncategorized comments defaulted to PRESERVE

**Result:** All critical checks passed. 4 corrections applied. Review proceeding.
```

### Concise Report

Only if issues escalated:

```markdown
### Validation Report ⚠️

**ESCALATION REQUIRED**

Systematic issue detected: preserve_pattern violations affect 15 comments (15%).
Configuration may need review.

[See details above]
```

## Summary

Self-validation ensures:
- ✅ Configuration rules respected
- ✅ Internal consistency maintained
- ✅ Categorization logic sound
- ✅ Uncertainty properly tracked
- ✅ Scope completely covered

**Key principle:** Auto-correct what's safe, escalate what's ambiguous, report what's systematic.
