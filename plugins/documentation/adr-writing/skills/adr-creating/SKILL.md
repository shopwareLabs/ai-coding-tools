---
name: adr-creating
version: 1.0.0
description: Write and validate Architecture Decision Records following Shopware ADR conventions. Interactively creates ADRs with proper YAML front matter, structure selection (simple or multi-domain), and guided content. Validates existing ADRs against front matter rules, required coverage, structure, writing style, and Shopware-specific patterns. Use when creating new ADRs, writing architecture decisions, validating ADR files, checking ADR quality, or when user mentions "ADR", "architecture decision record", or "decision record".
allowed-tools: Read, Write, Glob, Grep, Bash, AskUserQuestion
---

# ADR Creating

Write and validate Architecture Decision Records for Shopware projects.

## Mode Detection

- **Creation**: "create", "write", "new", "draft"
- **Validation**: "validate", "check", "verify", "review"

---

## Front Matter Rules

Every ADR starts with YAML front matter:

```yaml
---
title: Short descriptive title
date: YYYY-MM-DD
area: core
tags: [relevant, tags]
---
```

**Fields:**
- `title` (required): Short, descriptive. This is the only title — do NOT repeat it as a Markdown `#` heading
- `date` (required): ISO format `YYYY-MM-DD`
- `area` (required): Lowercase, single value from: `core`, `checkout`, `admin`, `storefront`, `inventory`, `framework`, `discovery`, `infrastructure`, `process`
- `tags` (required): Lowercase technical terms as YAML array
- `authors` (optional): List of authors
- `status` (optional): e.g., `accepted`, `superseded`

## Required Coverage

From Shopware's coding guidelines, every ADR must address:

1. Complete description of the requirements
2. All technical domains affected
3. All affected logic in the system
4. Pseudocode for new logic
5. All public APIs to be created or changed
6. How developers can extend the new APIs and what business cases you see
7. The reason for the decision
8. All consequences and their impact on developers

## Writing Principles

- **Audience**: Shopware developers familiar with the codebase. No need to explain DAL, Symfony, Vue, Criteria, or SalesChannelContext
- **Voice**: Direct, informal, developer-to-developer. Explain decisions like you're talking to a colleague
- **Factual over promotional**: Describe what changes and why ("simplifies the caching logic", "removes the need for manual transaction handling") — never use marketing language ("greatly enhanced", "stands to benefit significantly", "powerful new capability"). Quantitative claims (percentages, timings) are only acceptable when backed by explicit data the author provides — never estimate or guess numbers
- **Prose for reasoning**: Use flowing prose when explaining trade-offs, context, and why a decision was made
- **Bullets for lists**: Use plain bullets only for discrete, independent items
- **One decision per ADR**: Each ADR addresses a single architectural decision
- **Rationale focus**: The "why" is the most valuable part — decisions without context become meaningless over time

**Load `references/writing-style.md` for detailed voice guidance, examples from real ADRs, and anti-patterns to avoid**

---

## Creation Workflow

### Step 1: Gather Context

Use AskUserQuestion to collect:
- **Topic/title**: What architectural decision is being made?
- **Area**: Which area does this primarily affect? (present the enum)
- **Tags**: What technical terms are relevant?
- **Scope**: Does this decision span multiple technical domains, or is it focused on one?

If the user provided a topic, use it as the starting point and infer what you can before asking.

### Step 2: Select Structure

**Load `references/structure-patterns.md` for templates and decision guidance**

Based on scope:

**Single domain** → Context / Decision / Consequences structure:
```markdown
## Context
[Problem description, background, constraints — explain the problem before introducing any solution]

## Decision
[What was decided, pseudocode for new logic, all public API definitions]

## Consequences
[Impact on developers, backward compatibility, migration path]
```

**Multi-domain** → Domain-by-domain structure:
1. List every domain being touched
2. Create a `##` heading for each domain
3. Under each domain: 1-2 sentences on why it's relevant, then Problems (what logic to touch and why), then Solutions (how to change it with pseudocode)
4. Add Extendability section: how developers extend, what business cases you see
5. Add Consequences section

Suggest additional sections where appropriate:
- **Extendability**: When new APIs or extension points are introduced
- **Considered Alternatives**: When multiple viable approaches existed
- **Backward Compatibility**: When BC impact deserves detailed explanation
- **Security Considerations**: When features have trust boundaries

### Step 3: Draft ADR

Generate the ADR content:

1. **Front matter**: title, today's date (use `date +%Y-%m-%d` via Bash), area, tags
2. **No `#` heading** — the front matter title is sufficient
3. **Context first**: Always explain the problem before the solution
4. **Include pseudocode** for all new logic
5. **Define all public APIs** being created or changed
6. **Address extendability**: How should developers extend this?
7. **State consequences**: Impact on both platform developers and third-party developers where applicable

**Load `references/code-in-adrs.md` when writing code sections**

**Load `references/shopware-patterns.md` when addressing feature flags, cross-references, or audience-specific consequences**

### Step 4: Self-Validate

Before writing the file, verify all 8 required coverage items are addressed. Check:

- [ ] Requirements described completely
- [ ] All affected technical domains identified
- [ ] All affected logic listed
- [ ] Pseudocode present for new logic
- [ ] All new/changed public APIs defined
- [ ] Extendability addressed with business cases
- [ ] Reason for the decision clearly stated
- [ ] Consequences address developer impact

If gaps exist, ask the user to provide the missing information. Also ask about optional concerns:
- Is this gated behind a feature flag?
- Are there backward compatibility implications?
- Were alternative approaches considered?
- Are there related ADRs to cross-reference?

### Step 5: Write File

1. Generate filename: `YYYY-MM-DD-kebab-case-title.md`
2. Determine output directory:
   - Check if `adr/` directory exists in project root
   - If not, ask user for the target directory
3. Write the complete ADR file using the Write tool
4. Confirm creation with the file path

---

## Validation Workflow

### Step 1: Load and Parse

1. Read the ADR file
2. Parse YAML front matter (between `---` markers)
3. Identify all `##` section headings

### Step 2: Check Front Matter

- `title`: Present and descriptive?
- `date`: Present and valid YYYY-MM-DD format?
- `area`: Present and from the allowed enum?
- `tags`: Present, array format, all lowercase?
- No `#` heading that duplicates the title?

### Step 3: Check Content

**Load `references/validation-checklist.md` for detailed validation criteria**

Check all 8 required coverage items, structure compliance, writing style, code quality, and Shopware-specific patterns.

### Step 4: Generate Report

```
ADR Validation Report
=====================

File: [filename]
Title: [title from front matter]

Front Matter: [✓/✗]
  [specific issues if any]

Required Coverage: [✓/⚠/✗]
  [per-item breakdown with ✓/⚠/✗]

Structure: [✓/⚠]
  [structure type detected, issues if any]

Style: [✓/⚠]
  [issues if any]

Shopware Patterns: [✓/⚠]
  [issues if any]

Recommendations:
  1. [specific actionable items]
```

---

## Error Handling

- **No ADR directory found**: Ask user for the target directory path
- **File already exists** (creation): Ask whether to overwrite or choose a different name
- **Invalid front matter** (validation): Report specific parsing errors
- **Missing file** (validation): Report file not found with suggestions
