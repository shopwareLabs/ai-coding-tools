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

### For NON-COMPLIANT Tests (ISSUES_FOUND with must-fix rules)

```
## Unit Test Generation Complete

**Test File**: [path]
**Status**: ✗ NON-COMPLIANT
**Category**: [A-E]
**Review Iterations**: [X/4]

### Applied Fixes
- [List of fixes applied during review]

### Mandatory Compliance Failures
The following errors could not be resolved. Test is NOT compliant:
- [{RULE-ID}] [Description] at [location] (legacy: {LEGACY})
- [{RULE-ID}] [Description] at [location] (legacy: {LEGACY})

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

### Optional Improvements
The following warnings are optional but recommended:
- [{RULE-ID}] [Description] - user declined to fix (legacy: {LEGACY})
```

### Status Values

| Status | Symbol | Meaning |
|--------|--------|---------|
| COMPLIANT | ✓ | Test generated and all must-fix rules resolved |
| NON-COMPLIANT | ✗ | Test has unresolved must-fix rules (mandatory failures) |
| COMPLIANT (with warnings) | ✓ | Must-fix resolved, should-fix rules remain (optional) |

**IMPORTANT**: Must-fix rules are MANDATORY. Never use "recommendations" or "suggestions" for must-fix rules. Only should-fix rules are optional.

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

### Mandatory Compliance Failures
Files with unresolved must-fix rules:
- src/Other/Thing.php: {RULE-ID} ({title}) at lines 45, 67 (legacy: {LEGACY})

### Optional Improvements
Files with should-fix rules that user may optionally address:
- [List of warnings that were declined]
```

---

## Communication Style

When reporting test results:

- Report progress at each phase transition
- Be specific about what was changed and why
- Present issues in actionable format with clear fix suggestions
- User input only for: Phase 3 warnings (should-fix rules), oscillation escalation

### Terminology

Use:
- "COMPLIANT" / "NON-COMPLIANT" for final status
- "Mandatory Compliance Failures" for must-fix rules
- "Optional Improvements" for should-fix rules

Avoid:
- "Partial" or "Needs Review" which implies optionality for must-fix rules
- "Recommendations" or "Suggestions" for must-fix rules
