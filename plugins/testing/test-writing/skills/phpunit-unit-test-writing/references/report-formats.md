# Report Formats Reference

## Table of Contents
- [Final Report Template](#final-report-template)
- [Multi-File Summary Format](#multi-file-summary-format)

---

## Final Report Template

Use this format for Phase 4 reporting after single-file processing:

```
## Unit Test Generation Complete

**Test File**: [path]
**Status**: [final status]
**Category**: [A-E]
**Review Iterations**: [X/4]

### Applied Fixes
- [List of fixes applied during review]

### Remaining Notes
- [Any warnings user declined to fix]
- [Any recommendations for manual review]
```

### Status Values

| Status | Meaning |
|--------|---------|
| SUCCESS | Test generated and all issues resolved |
| PARTIAL | Test generated, some warnings remain |
| NEEDS_REVIEW | Test generated, user declined some fixes |

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
**Successful**: [Y]
**Failed/Skipped**: [Z]

### Results by File

| Source File | Test File | Status | Category | Iterations |
|------------|-----------|--------|----------|------------|
| src/Path/Class.php | tests/unit/Path/ClassTest.php | SUCCESS | B | 2/4 |
| src/Other/Thing.php | tests/unit/Other/ThingTest.php | PARTIAL | C | 4/4 |

### Applied Fixes Summary
- [Total fixes applied across all files]

### Issues Requiring Attention
- [Any files that need manual review]
- [Warnings that were declined]
```
