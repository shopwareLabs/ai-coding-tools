# ADR Writing

Write and validate Architecture Decision Records following Shopware's ADR conventions. Encodes rules from Shopware's coding guidelines, patterns from 80+ existing ADRs, and general ADR best practices.

## Quick Start

Use natural language — the `adr-creating` skill is automatically invoked:

```
Write an ADR about switching to Redis for cart persistence
Create an ADR for introducing tax providers
Validate the ADR at adr/2023-05-22-switch-to-uuidv7.md
Check the ADR at adr/2025-01-29-make-rule-classes-internal.md
```

## Features

- Interactive ADR creation with guided prompts for topic, area, tags, and structure
- Two structure modes: simple (Context/Decision/Consequences) and multi-domain (domain-by-domain with Problems/Solutions)
- YAML front matter generation with area validation
- Self-validation against 8 required coverage items before writing
- Validation of existing ADRs with structured reports
- Writing style enforcement (developer-to-developer voice, prose for reasoning, anti-pattern detection)
- Shopware-specific pattern support (feature flag gating, cross-references, audience-split consequences)

## What an ADR Must Cover

From Shopware's coding guidelines, every ADR must address:

1. Complete description of the requirements
2. All technical domains affected
3. All affected logic in the system
4. Pseudocode for new logic
5. All public APIs to be created or changed
6. How developers can extend the new APIs and what business cases you see
7. The reason for the decision
8. All consequences and their impact on developers

## Structure Options

**Simple** — For focused decisions touching one domain:
- Context / Decision / Consequences
- Best for: deprecations, policy changes, single new interfaces

**Multi-Domain** — For decisions spanning multiple areas:
- Domain-by-domain with Problems / Solutions per domain
- Best for: Store API + Storefront + App System, or new subsystems with indexing + API + admin

## Example Output

### Creation

```
Created: adr/2025-02-07-switch-to-uuidv7.md

---
title: Switch to UUIDv7
date: 2025-02-07
area: core
tags: [dal, uuid, performance]
---

## Context

Currently, we're using UUIDv4, which is a random UUID...

## Decision

Considering there is little risk to using UUIDv7...

## Consequences

We will switch to UUIDv7 as default...
```

### Validation

```
ADR Validation Report
=====================

File: adr/2025-01-29-make-rule-classes-internal.md
Title: Make Rule classes internal

Front Matter: PASS
  ✓ title, date, area, tags all present and valid

Required Coverage: PASS
  ✓ Requirements description
  ✓ Technical domains affected
  ...

Recommendations:
  None — this ADR meets all requirements.
```

## Documentation

- **Writing style**: `skills/adr-creating/references/writing-style.md`
- **Structure patterns**: `skills/adr-creating/references/structure-patterns.md`
- **Code in ADRs**: `skills/adr-creating/references/code-in-adrs.md`
- **Shopware patterns**: `skills/adr-creating/references/shopware-patterns.md`
- **Validation checklist**: `skills/adr-creating/references/validation-checklist.md`

## Developer Guide

See `AGENTS.md` for plugin architecture and development guidance.

## License

MIT
