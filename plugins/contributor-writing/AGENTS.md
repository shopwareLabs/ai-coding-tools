# Contributor Writing Plugin

## Plugin Structure

```
plugins/contributor-writing/
├── .claude-plugin/plugin.json    # Plugin metadata
├── CHANGELOG.md                  # Version history
├── CLAUDE.md                     # Points to AGENTS.md
├── AGENTS.md                     # This file
├── README.md                     # User documentation
└── skills/
    ├── release-info-writing/
    │   ├── SKILL.md              # Release info/upgrade entry drafting
    │   └── references/
    │       ├── writing-rules.md  # Style guide, do's/don'ts, tense, anti-slop rules
    │       ├── entry-examples.md # Sizing tiers with real examples
    │       └── file-structure.md # Heading hierarchy, categories, placement
    └── pr-description-writing/
        ├── SKILL.md              # PR title and description drafting
        └── references/
            ├── writing-rules.md      # Style guide and anti-slop rules for PR descriptions
            ├── pr-description-examples.md # Density tier examples from real PRs
            └── template-structure.md     # Output format, title rules, section guidance
```

## Skills

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

## Key Design Decisions

- `.danger.php` parsing logic is inline in release-info-writing SKILL.md (Phase 1) because it runs before references load
- release-info-writing uses `Edit` (not `Write`) to insert into existing files only
- pr-description-writing is output-only — no file writes, no GitHub operations
- Both skills classify from the full branch diff against `trunk`, not individual commits
- Reference files are self-contained per skill — no sharing between skills
