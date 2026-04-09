---
name: adr-writing
version: 1.6.0
model: opus
description: Write and validate Architecture Decision Records following Shopware ADR conventions. Interactively creates ADRs with proper YAML front matter, structure selection (simple or multi-domain), and guided content. Validates existing ADRs against front matter rules, required coverage, structure, writing style, and Shopware-specific patterns. Use when creating new ADRs, writing architecture decisions, validating ADR files, checking ADR quality, or when user mentions "ADR", "architecture decision record", or "decision record".
allowed-tools: Read, Write, Glob, Grep, Bash, AskUserQuestion
---

# ADR Writing

## Mode Detection

- **Creation**: "create", "write", "new", "draft"
- **Validation**: "validate", "check", "verify", "review"

---

## Front Matter

```yaml
---
title: Short descriptive title
date: YYYY-MM-DD
area: core
tags: [relevant, tags]
---
```

- `title` (required): Short, descriptive. Do NOT repeat as a Markdown `#` heading
- `date` (required): `YYYY-MM-DD`
- `area` (required): One of: `core`, `checkout`, `admin`, `storefront`, `inventory`, `framework`, `discovery`, `infrastructure`, `process`
- `tags` (required): Lowercase technical terms, YAML array
- `authors`, `status` (optional)

## Required Coverage

Every ADR must address all 8 items:

1. Complete description of the requirements
2. All technical domains affected
3. All affected logic in the system
4. Pseudocode for new logic
5. All public APIs to be created or changed
6. How developers can extend the new APIs and what business cases you see
7. The reason for the decision
8. All consequences and their impact on developers

## Writing Principles

- **Audience**: Shopware developers familiar with the codebase — no need to explain DAL, Symfony, Vue, Criteria, SalesChannelContext
- **Voice**: Direct, informal, developer-to-developer
- **Factual over promotional**: Describe what changes and why ("simplifies the caching logic", "removes manual transaction handling"). Never use marketing language ("greatly enhanced", "stands to benefit significantly"). Quantitative claims only when backed by explicit data the author provides — never estimate or guess numbers
- **Prose for reasoning**, plain bullets only for discrete independent items
- **One decision per ADR**
- **Rationale focus**: The "why" is the most valuable part

**Load `references/writing-style.md` for voice examples, table/diagram guidance**

---

## Creation Workflow

### Step 1: Gather Context

AskUserQuestion to collect: topic/title, area (present enum), tags, scope (single vs multi-domain).

If topic already provided, infer what you can before asking.

### Step 2: Select Structure

**Load `references/structure-patterns.md` for templates and examples**

**Single domain** → Context / Decision / Consequences:
```markdown
## Context
[Problem, background, constraints — problem before solution]

## Decision
[What was decided, pseudocode, public API definitions]

## Consequences
[Developer impact, backward compatibility, migration path]
```

**Multi-domain** → Domain-by-domain:
1. `##` heading per domain
2. 1-2 sentences on relevance, then **Problems** (what logic to touch and why), then **Solutions** (how to change it with pseudocode)
3. Extendability section
4. Consequences section

Additional sections when appropriate: Extendability, Considered Alternatives, Backward Compatibility, Security Considerations.

### Step 3: Draft ADR

1. Front matter with today's date (use `date +%Y-%m-%d` via Bash)
2. Context first — always explain problem before solution
3. Address all 8 required coverage items
4. **Load `references/code-in-adrs.md`** when writing code sections
5. **Load `references/shopware-patterns.md`** for feature flags, cross-references, audience-specific consequences
6. **Load `references/writing-rules-anti-ai-slop.md`** to internalize style constraints and anti-slop rules

### Step 4: Self-Validate

Verify all 8 required coverage items are addressed. If gaps exist, ask user for missing information.

Also ask about optional concerns: feature flag gating, backward compatibility implications, alternative approaches considered, related ADRs to cross-reference.

### Step 5: Validate and Write

1. **Anti-slop validation pass** — load `references/writing-rules-anti-ai-slop.md`, then check the draft literally (not from memory):
   - First: search the draft text for em dash (—) and en dash (–) characters. Remove every instance. This is the most common violation and must be checked first as a literal character search, not a mental scan.
   - Then re-read each sentence against: banned vocabulary, banned sentence patterns, colon/semicolon overuse, sentence rhythm, concreteness, tone
   - If any violations found, rewrite the affected sentences and re-check
2. Filename: `YYYY-MM-DD-kebab-case-title.md`
3. Write to `adr/` directory if it exists, otherwise ask user for target directory
4. Confirm creation with file path

---

## Validation Workflow

### Step 1: Load and Parse

Read file, parse YAML front matter, identify `##` section headings.

### Step 2: Check Front Matter

Verify: title present, date valid YYYY-MM-DD, area from allowed enum, tags lowercase array, no `#` heading duplicating title.

### Step 3: Check Content

**Load `references/validation-checklist.md` for detailed criteria**

**Load `references/writing-rules-anti-ai-slop.md` for anti-slop checks**

Check all 8 required coverage items, structure compliance, writing style, anti-slop rules, code quality, Shopware-specific patterns.

### Step 4: Generate Report

```
ADR Validation Report
=====================

File: [filename]
Title: [title]

Front Matter: [✓/✗]
  [issues if any]

Required Coverage: [✓/⚠/✗]
  [per-item breakdown]

Structure: [✓/⚠]
  [type detected, issues]

Style: [✓/⚠]
  [issues if any]

Anti-Slop: [✓/⚠]
  [issues if any]

Shopware Patterns: [✓/⚠]
  [issues if any]

Recommendations:
  1. [actionable items]
```

---

## Error Handling

- **No ADR directory**: Ask user for target path
- **File exists** (creation): Ask to overwrite or rename
- **Invalid front matter** (validation): Report parsing errors
- **Missing file** (validation): Report not found
