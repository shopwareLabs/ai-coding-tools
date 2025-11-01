@README.md

## Directory & File Structure

```
plugins/git-workflow/commit-message-generator/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── commands/
│   ├── commit-gen.md                           # Generate commit message
│   └── commit-check.md                         # Validate commit message
└── skills/
    └── commit-message-generating/             # Core skill implementation
        ├── SKILL.md                            # Main skill logic
        ├── commitmsgrc-template.md             # Configuration template
        ├── scripts/                            # Utility shell scripts
        │   └── git-commit-helpers.sh           # Git operations helpers
        └── references/                         # Progressive disclosure references
            ├── conventional-commits-spec.md    # Full spec reference
            ├── type-detection.md               # How to determine commit type
            ├── scope-detection.md              # How to infer scope
            ├── consistency-validation.md       # Validation rules
            └── custom-rules.md                 # Configuration guide
```

## Component Overview

This plugin provides:
- **Slash Commands** (`commands/`) - User-facing commands that invoke the skill
- **Skill** (`skills/commit-message-generating/SKILL.md`) - Core generation and validation logic
- **Utility Scripts** (`scripts/`) - Bash helpers for git operations
- **Reference Files** (`references/`) - Progressive disclosure knowledge files
- **Config Template** - Project-specific customization template

## Key Navigation Points

### Finding Specific Functionality

| Task | Primary File | Secondary File | Key Concepts |
|------|--------------|----------------|--------------|
| Modify data source detection | `SKILL.md` Step 0 | `commands/commit-gen.md` | Staged vs. commit detection |
| Modify type detection logic | `SKILL.md` | `references/type-detection.md` | Decision tree, heuristics |
| Modify scope inference | `SKILL.md` | `references/scope-detection.md` | Path-based detection |
| Add validation rules | `SKILL.md` | `references/consistency-validation.md` | Type/scope/subject checks |
| Extend git operations | `scripts/git-commit-helpers.sh` | - | 13 bash functions |
| Add config option | `commitmsgrc-template.md` | `references/custom-rules.md` | YAML schema |
| Update spec reference | `references/conventional-commits-spec.md` | - | Format, validation rules |

## When to Modify What

**Supporting new data sources** (e.g., branches, tags, commit ranges) → Edit `SKILL.md` Step 0 + update `commands/commit-gen.md` scope detection section

**Changing type detection heuristics** → Edit `SKILL.md` Step 2 + update `references/type-detection.md` examples

**Adding new commit type** → Edit `SKILL.md` defaults + `references/conventional-commits-spec.md` + `commitmsgrc-template.md`

**Modifying scope inference** → Edit `SKILL.md` Step 3 + update `references/scope-detection.md` patterns

**Adding validation check** → Edit `SKILL.md` validation mode + document in `references/consistency-validation.md`

**Adding config option** → Edit `commitmsgrc-template.md` schema + document in `references/custom-rules.md`

**Adding git helper function** → Edit `scripts/git-commit-helpers.sh` + export function

**Updating spec compliance** → Edit `references/conventional-commits-spec.md` + adjust `SKILL.md` validation
