# Contributor Writing Plugin

## Plugin Structure

```
plugins/contributor-writing/
├── .claude-plugin/plugin.json    # Plugin metadata
├── CHANGELOG.md                  # Version history
├── CLAUDE.md                     # Points to AGENTS.md
├── AGENTS.md                     # This file
├── README.md                     # User documentation
├── references/
│   └── writing-rules-anti-ai-slop.md  # Shared anti-slop rules (source of truth)
└── skills/
    ├── adr-writing/
    │   ├── SKILL.md              # ADR creation and validation
    │   └── references/
    │       ├── writing-style.md           # Voice, prose vs lists, table/diagram guidance
    │       ├── structure-patterns.md      # Simple vs multi-domain templates
    │       ├── code-in-adrs.md            # What/how to show code
    │       ├── shopware-patterns.md       # Feature flags, cross-refs, audience split
    │       ├── validation-checklist.md    # Checklist with severity levels
    │       └── writing-rules-anti-ai-slop.md  # Anti-slop rules (copy)
    ├── release-info-writing/
    │   ├── SKILL.md              # Release info/upgrade entry drafting
    │   └── references/
    │       ├── writing-rules.md  # Style guide, do's/don'ts, tense, anti-slop rules
    │       ├── entry-examples.md # Sizing tiers with real examples
    │       └── file-structure.md # Heading hierarchy, categories, placement
    ├── pr-description-writing/
    │   ├── SKILL.md              # PR title and description drafting (trunk target)
    │   └── references/
    │       ├── writing-rules.md      # Style guide and anti-slop rules for PR descriptions
    │       ├── pr-description-examples.md # Density tier examples from real PRs
    │       └── template-structure.md     # Output format, title rules, section guidance
    └── feature-branch-pr-writing/
        ├── SKILL.md              # Feature-branch PR description drafting (non-trunk target)
        └── references/
            ├── writing-rules.md          # Style guide and anti-slop rules
            └── description-examples.md   # Sizing tier examples from real PRs
```

## Skills

### adr-writing
- **Workflow changes** → Edit `skills/adr-writing/SKILL.md`
- **Writing style/voice** → Edit `skills/adr-writing/references/writing-style.md`
- **Structure templates** → Edit `skills/adr-writing/references/structure-patterns.md`
- **Code guidance** → Edit `skills/adr-writing/references/code-in-adrs.md`
- **Shopware patterns** → Edit `skills/adr-writing/references/shopware-patterns.md`
- **Validation checks** → Edit `skills/adr-writing/references/validation-checklist.md`

### release-info-writing
- **Workflow changes** → Edit `skills/release-info-writing/SKILL.md`
- **Writing style/rules** → Edit `skills/release-info-writing/references/writing-rules.md`
- **Example entries** → Edit `skills/release-info-writing/references/entry-examples.md`
- **File structure/categories** → Edit `skills/release-info-writing/references/file-structure.md`

### pr-description-writing
- **Workflow changes** → Edit `skills/pr-description-writing/SKILL.md`
- **Writing style/rules** → Edit `skills/pr-description-writing/references/writing-rules.md`
- **Example descriptions** → Edit `skills/pr-description-writing/references/pr-description-examples.md`
- **Template/title format** → Edit `skills/pr-description-writing/references/template-structure.md`

### feature-branch-pr-writing
- **Workflow changes** → Edit `skills/feature-branch-pr-writing/SKILL.md`
- **Writing style/rules** → Edit `skills/feature-branch-pr-writing/references/writing-rules.md`
- **Example descriptions** → Edit `skills/feature-branch-pr-writing/references/description-examples.md`

## Key Design Decisions

- `.danger.php` parsing logic is inline in release-info-writing SKILL.md (Phase 1) because it runs before references load
- release-info-writing uses `Edit` (not `Write`) to insert into existing files only
- pr-description-writing is output-only — no file writes, no GitHub operations
- release-info-writing and pr-description-writing classify from the full branch diff against `trunk`, not individual commits
- adr-writing loads anti-slop rules directly from its own `references/writing-rules-anti-ai-slop.md` copy
- release-info-writing and pr-description-writing embed anti-slop rules in their `references/writing-rules.md` files
- feature-branch-pr-writing is output-only — no file writes, no GitHub operations
- feature-branch-pr-writing classifies from the diff against the target feature branch, not trunk
- feature-branch-pr-writing embeds anti-slop rules in its `references/writing-rules.md`
- pr-description-writing hands off to feature-branch-pr-writing when PR target is not trunk
- Anti-slop rules source of truth is `references/writing-rules-anti-ai-slop.md`. When updating: edit the shared file first, then copy into each skill's anti-slop reference (adr-writing's `references/writing-rules-anti-ai-slop.md` and the anti-slop section of each other skill's `references/writing-rules.md`)
