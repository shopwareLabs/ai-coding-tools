# Oscillation Handling

## Table of Contents
- [When to Escalate](#when-to-escalate)
- [Escalation Formats](#escalation-formats)
- [After Escalation](#after-escalation)

---

## When to Escalate

Escalate to user if you observe either pattern:

**Code-based oscillation**: The same error/warning code at the same location appears in the current iteration AND any earlier non-consecutive iteration.

Example: E003 at line 45 in iteration 1, resolved in iteration 2, returns in iteration 3.

**Location-based churn**: The same location is flagged with different codes following an A→B→A pattern.

Example: E003 at line 45 in iteration 1, W001 at line 45 in iteration 2, E003 at line 45 in iteration 3.

---

## Escalation Formats

### For Code-Based Oscillation

Present to user:

```
## Review Oscillation Detected

The reviewer is oscillating on **{code}** at `{location}`.

**Pattern**: Iteration {first_occurrence} → fixed → Iteration {current} (returned)

### Alternative A (Iteration {first_occurrence}):
**Issue**: {title_from_first}
**Suggested fix**:
{suggested_fix_from_first}

### Alternative B (Current):
**Issue**: {title_current}
**Suggested fix**:
{suggested_fix_current}

Which approach should I apply?
```

Use AskUserQuestion with options:
- "Apply Alternative A (iteration {first_occurrence} fix)"
- "Apply Alternative B (current fix)"
- "Keep current code as-is (skip this issue)"

### For Location-Based Churn

Present to user:

```
## Review Churn Detected

Location `{location}` has been flagged with different issues across iterations:

| Iteration | Code | Issue |
|-----------|------|-------|
| {iter_1} | {code_1} | {title_1} |
| {iter_2} | {code_2} | {title_2} |
| {iter_3} | {code_1} | {title_1} (returned) |

**Options**:
1. Apply {code_1} fix: {suggested_fix_1}
2. Apply {code_2} fix: {suggested_fix_2}
3. Keep current code as-is
```

Use AskUserQuestion with the three options above.

---

## After Escalation

After user makes a choice:
1. Apply the selected fix (or skip if "keep as-is")
2. Exit the review loop
3. Proceed to Phase 4 (Final Report)
