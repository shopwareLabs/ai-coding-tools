# Validation Checklist

## Front Matter

| Check | Severity | What to look for |
|-------|----------|------------------|
| Title present | ERROR | `title:` field exists in YAML front matter |
| Date present and valid | ERROR | `date:` field in YYYY-MM-DD format |
| Area present and valid | ERROR | `area:` is one of: core, checkout, admin, storefront, inventory, framework, discovery, infrastructure, process |
| Tags present | ERROR | `tags:` field exists as YAML array |
| Tags lowercase | WARN | All tag values are lowercase |
| No duplicate heading | WARN | No `#` heading that repeats the front matter title |

## Required Coverage (from coding guideline)

Each item maps to a Shopware coding guideline expectation:

| # | Requirement | Severity | What to look for |
|---|-------------|----------|------------------|
| 1 | Requirements description | ERROR | Context section explains what problem needs solving and what constraints exist |
| 2 | Technical domains affected | ERROR | All affected areas of the system are identified (either as separate sections or listed explicitly) |
| 3 | Affected logic listed | ERROR | Specific classes, services, or processes that will be modified are named |
| 4 | Pseudocode for new logic | ERROR | Code blocks showing new interfaces, classes, or behavioral logic |
| 5 | Public APIs defined | ERROR | Every new or changed public interface/API contract is shown |
| 6 | Extendability addressed | WARN | Description of how developers can extend the new APIs, with business cases |
| 7 | Reason for decision | ERROR | Clear statement of WHY this approach was chosen (not just what it does) |
| 8 | Consequences for developers | ERROR | Impact section addressing how this affects developers using the code/product |

## Structure Compliance

| Check | Severity | What to look for |
|-------|----------|------------------|
| Recognized structure | WARN | Either Context/Decision/Consequences OR domain-by-domain with Problems/Solutions |
| Context before solution | WARN | Problem is explained before the solution is introduced |
| Consequences present | ERROR | A consequences/impact section exists |

## Writing Style

| Check | Severity | What to look for |
|-------|----------|------------------|
| No promotional language | WARN | Absence of: "greatly improved", "enhancing usability", "stands to benefit significantly", "powerful" |
| Prose for reasoning | WARN | Trade-offs and explanations use flowing prose, not just bullet lists |
| No numbered-bold-label anti-pattern | WARN | No pattern of `1. **Label**: explanation` replacing prose reasoning |
| Quantitative claims sourced | WARN | Any numbers (percentages, timings) are backed by explicit data, not estimated or guessed |

## Shopware Patterns

| Check | Severity | What to look for |
|-------|----------|------------------|
| Feature flag mentioned | WARN | If the change is gated behind a feature flag, it should be stated |
| Related ADRs cross-referenced | WARN | If related ADRs exist, they should be linked |
| Audience-split consequences | WARN | If the decision affects platform and third-party devs differently, consequences should be split |

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

**Severity guide:**
- **ERROR** (✗): Required by coding guideline. The ADR is incomplete without this.
- **WARN** (⚠): Recommended by conventions. The ADR would be better with this addressed.
- **PASS** (✓): Meets the requirement.

**Overall status:**
- **PASS**: No ERRORs, at most minor WARNs
- **WARN**: No ERRORs, but notable WARNs that should be addressed
- **FAIL**: One or more ERRORs present
