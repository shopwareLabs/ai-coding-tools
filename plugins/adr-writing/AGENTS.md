@README.md

## Directory Structure

```
plugins/adr-writing/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── adr-creating/
│       ├── SKILL.md                     # Core logic: creation + validation workflows
│       └── references/
│           ├── writing-style.md         # Voice, prose vs lists, anti-patterns
│           ├── structure-patterns.md    # Simple vs multi-domain templates
│           ├── code-in-adrs.md          # What/how to show code
│           ├── shopware-patterns.md     # Feature flags, cross-refs, audience split
│           └── validation-checklist.md  # 11-item checklist with severity
├── README.md
├── AGENTS.md                            # This file
├── CLAUDE.md
├── CHANGELOG.md
└── LICENSE
```

## When to Modify

| Task | File |
|------|------|
| Change creation workflow | `skills/adr-creating/SKILL.md` |
| Change validation workflow | `skills/adr-creating/SKILL.md` |
| Change front matter rules | `skills/adr-creating/SKILL.md` (inline rules) |
| Change writing style guidance | `skills/.../references/writing-style.md` |
| Change structure templates | `skills/.../references/structure-patterns.md` |
| Change code guidance | `skills/.../references/code-in-adrs.md` |
| Change Shopware patterns | `skills/.../references/shopware-patterns.md` |
| Change validation checks | `skills/.../references/validation-checklist.md` |

## Design Philosophy

1. **Skill IS the guide** — All ADR conventions are encoded directly in skill files, not referenced from external documents
2. **Trust Claude's knowledge** — No duplication of general markdown or YAML syntax rules
3. **Progressive disclosure** — Core rules inline in SKILL.md, detailed guidance in reference files loaded on demand
4. **Interactive creation** — Gather context before drafting, self-validate before writing
