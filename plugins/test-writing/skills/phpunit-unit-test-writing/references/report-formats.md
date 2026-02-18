# Report Formats Reference

## Table of Contents
- [Final Report Template](#final-report-template)
- [Multi-File Summary Format](#multi-file-summary-format)

---

## Final Report Template

Use this format for Phase 4 reporting after single-file processing:

### For COMPLIANT Tests (PASS)

```
## Unit Test Generation Complete

**Test File**: [path]
**Status**: ✓ COMPLIANT
**Category**: [A-E]
**Review Iterations**: [X/4]

### Applied Fixes
- [List of fixes applied during review]

All mandatory checks passed. Test meets Shopware unit test standards.
```

### For NON-COMPLIANT Tests (ISSUES_FOUND with E-codes)

```
## Unit Test Generation Complete

**Test File**: [path]
**Status**: ✗ NON-COMPLIANT
**Category**: [A-E]
**Review Iterations**: [X/4]

### Applied Fixes
- [List of fixes applied during review]

### Mandatory Compliance Failures (E-codes)
The following errors could not be resolved. Test is NOT compliant:
- [E001] [Description] at [location]
- [E009] [Description] at [location]

These are NOT optional. The test fails compliance review.
```

### For COMPLIANT with Warnings (NEEDS_ATTENTION)

```
## Unit Test Generation Complete

**Test File**: [path]
**Status**: ✓ COMPLIANT (with warnings)
**Category**: [A-E]
**Review Iterations**: [X/4]

### Applied Fixes
- [List of fixes applied during review]

### Optional Improvements (W-codes)
The following warnings are optional but recommended:
- [W001] [Description] - user declined to fix
```

### Status Values

| Status | Symbol | Meaning |
|--------|--------|---------|
| COMPLIANT | ✓ | Test generated and all E-codes resolved |
| NON-COMPLIANT | ✗ | Test has unresolved E-codes (mandatory failures) |
| COMPLIANT (with warnings) | ✓ | E-codes resolved, W-codes remain (optional) |

**IMPORTANT**: E-codes are MANDATORY. Never use "recommendations" or "suggestions" for E-codes. Only W-codes are optional.

### Category Definitions

| Category | Name | Description |
|----------|------|-------------|
| A | DTO | Simple value objects, entities, collections |
| B | Service | Services with constructor dependencies |
| C | Flow/Event | Event subscribers, flow actions |
| D | DAL | Repository operations, Criteria building |
| E | Exception | Exception classes and handling |

---

## Multi-File Summary Format

Use this format when processing multiple files:

```
## Unit Test Generation Summary

**Files Processed**: [X]
**Compliant**: [Y]
**Non-Compliant**: [Z]
**Failed/Skipped**: [W]

### Results by File

| Source File | Test File | Status | Category | Iterations |
|------------|-----------|--------|----------|------------|
| src/Path/Class.php | tests/unit/Path/ClassTest.php | ✓ COMPLIANT | B | 2/4 |
| src/Other/Thing.php | tests/unit/Other/ThingTest.php | ✗ NON-COMPLIANT | C | 4/4 |

### Applied Fixes Summary
- [Total fixes applied across all files]

### Mandatory Compliance Failures (E-codes)
Files with unresolved E-codes:
- src/Other/Thing.php: E009 (test redundancy) at lines 45, 67

### Optional Improvements (W-codes)
Files with W-codes that user may optionally address:
- [List of warnings that were declined]
```

---

## Communication Style

When reporting test results:

- Report progress at each phase transition
- Be specific about what was changed and why
- Present issues in actionable format with clear fix suggestions
- User input only for: Phase 3 warnings (W-codes), oscillation escalation

### Terminology

Use:
- "COMPLIANT" / "NON-COMPLIANT" for final status
- "Mandatory Compliance Failures" for E-codes
- "Optional Improvements" for W-codes

Avoid:
- "Partial" or "Needs Review" which implies optionality for E-codes
- "Recommendations" or "Suggestions" for E-codes
