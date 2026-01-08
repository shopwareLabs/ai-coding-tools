@README.md

## Directory Structure

```
plugins/git-workflow/commit-message-generator/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── agents/
│   ├── type-detector.md         # Type detection (~156 lines)
│   ├── scope-detector.md        # Scope detection (~151 lines)
│   ├── body-validator.md        # Body validation (~124 lines)
│   └── report-generator.md      # Report formatting (~135 lines)
├── commands/
│   ├── commit-gen.md            # Generate + clipboard
│   └── commit-check.md          # Validate
├── skills/
│   └── commit-message-generating/
│       ├── SKILL.md             # Core logic (~183 lines)
│       ├── commitmsgrc-template.md  # Config template
│       └── references/          # Quick references only
│           ├── examples.md
│           ├── custom-rules.md
│           └── consistency-validation.md
└── AGENTS.md                    # This file
```

## Agents (Haiku 4.5)

| Agent | Lines | Purpose |
|-------|-------|---------|
| `type-detector` | ~156 | Analyze diff → type + confidence + breaking |
| `scope-detector` | ~151 | Analyze files → scope + confidence |
| `body-validator` | ~124 | Validate body presence/quality/migration |
| `report-generator` | ~135 | Format validation results → markdown |

## When to Modify

| Task | File |
|------|------|
| Change type detection | `agents/type-detector.md` |
| Change scope inference | `agents/scope-detector.md` |
| Change body validation | `agents/body-validator.md` |
| Change report format | `agents/report-generator.md` |
| Change generation workflow | `skills/.../SKILL.md` |
| Change config options | `skills/.../commitmsgrc-template.md` |
| Change clipboard handling | `commands/commit-gen.md` |

## Design Philosophy

1. **Trust Claude's knowledge** - No duplication of Conventional Commits spec
2. **Concise agents** - Each under 200 lines
3. **Confidence-based interaction** - Ask user only when LOW confidence
4. **Progressive disclosure** - Reference files for edge cases only
