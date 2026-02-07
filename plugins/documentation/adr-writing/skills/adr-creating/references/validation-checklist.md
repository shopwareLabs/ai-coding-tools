# Validation Checklist

## Front Matter

| Check | Severity | Detail |
|-------|----------|--------|
| Title present | ERROR | `title:` exists |
| Date valid | ERROR | `date:` in YYYY-MM-DD |
| Area valid | ERROR | `area:` one of: core, checkout, admin, storefront, inventory, framework, discovery, infrastructure, process |
| Tags present | ERROR | `tags:` as YAML array |
| Tags lowercase | WARN | All values lowercase |
| No duplicate heading | WARN | No `#` heading repeating title |

## Required Coverage

| # | Requirement | Severity | Detail |
|---|-------------|----------|--------|
| 1 | Requirements description | ERROR | Context explains problem and constraints |
| 2 | Technical domains affected | ERROR | All affected areas identified |
| 3 | Affected logic listed | ERROR | Specific classes, services, or processes named |
| 4 | Pseudocode for new logic | ERROR | Code blocks for new interfaces, classes, or behavior |
| 5 | Public APIs defined | ERROR | Every new/changed public interface shown |
| 6 | Extendability addressed | WARN | How developers extend new APIs, with business cases |
| 7 | Reason for decision | ERROR | WHY this approach was chosen (not just what) |
| 8 | Consequences for developers | ERROR | Impact on developers using the code/product |

## Structure Compliance

| Check | Severity | Detail |
|-------|----------|--------|
| Recognized structure | WARN | Context/Decision/Consequences OR domain-by-domain with Problems/Solutions |
| Context before solution | WARN | Problem explained before solution |
| Consequences present | ERROR | Consequences/impact section exists |

## Writing Style

| Check | Severity | Detail |
|-------|----------|--------|
| No promotional language | WARN | No: "greatly improved", "enhancing usability", "stands to benefit significantly", "powerful" |
| Prose for reasoning | WARN | Trade-offs use prose, not just bullets |
| No numbered-bold-label pattern | WARN | No `1. **Label**: explanation` replacing prose |
| Quantitative claims sourced | WARN | Numbers backed by explicit data, not estimated |

## Shopware Patterns

| Check | Severity | Detail |
|-------|----------|--------|
| Feature flag mentioned | WARN | If change is flag-gated, state the flag |
| Related ADRs cross-referenced | WARN | If related ADRs exist, link them |
| Audience-split consequences | WARN | If platform/third-party impact differs, split consequences |

## Report Template

```
ADR Validation Report
=====================

File: {filename}
Title: {title}

Front Matter: {PASS|FAIL}
  {✓|✗} title: {detail}
  {✓|✗} date: {detail}
  {✓|✗} area: {detail}
  {✓|✗} tags: {detail}
  {✓|⚠} no duplicate heading: {detail}

Required Coverage: {PASS|WARN|FAIL}
  {✓|⚠|✗} Requirements description
  {✓|⚠|✗} Technical domains affected
  {✓|⚠|✗} Affected logic listed
  {✓|⚠|✗} Pseudocode for new logic
  {✓|⚠|✗} Public APIs defined
  {✓|⚠|✗} Extendability addressed
  {✓|⚠|✗} Reason for decision
  {✓|⚠|✗} Consequences for developers

Structure: {PASS|WARN}
  Type: {simple|multi-domain|unrecognized}
  {issues if any}

Style: {PASS|WARN}
  {issues if any}

Shopware Patterns: {PASS|WARN}
  {issues if any}

Recommendations:
  1. {most important actionable item}
  2. {next actionable item}
```

**Severity:** ERROR (✗) = required, incomplete without it. WARN (⚠) = recommended. PASS (✓) = met.

**Status:** PASS = no errors. WARN = no errors, notable warnings. FAIL = errors present.
