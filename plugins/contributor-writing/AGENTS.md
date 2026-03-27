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
    └── release-info-writing/
        ├── SKILL.md              # Release info/upgrade entry drafting
        └── references/
            ├── writing-rules.md  # Style guide, do's/don'ts, tense, anti-slop rules
            ├── entry-examples.md # Sizing tiers with real examples
            └── file-structure.md # Heading hierarchy, categories, placement
```

## Skills

### release-info-writing
- **Workflow changes** → Edit `skills/release-info-writing/SKILL.md`
- **Writing style/rules** → Edit `skills/release-info-writing/references/writing-rules.md`
- **Example entries** → Edit `skills/release-info-writing/references/entry-examples.md`
- **File structure/categories** → Edit `skills/release-info-writing/references/file-structure.md`

## Key Design Decisions

- `.danger.php` parsing logic is inline in SKILL.md (Phase 1) because it runs before references load
- The skill uses `Edit` (not `Write`) to insert into existing files only
- Classification uses the full branch diff against `trunk`, not individual commits
- Category detection scans the entire target file, not just the upcoming section
