@README.md

## Directory Structure

```
plugins/git-workflow/commit-message-generator/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── commands/
│   ├── commit-gen.md            # Generate + clipboard
│   └── commit-check.md          # Validate
├── skills/
│   └── commit-message-generating/
│       ├── SKILL.md             # Core logic (~185 lines)
│       ├── commitmsgrc-template.md  # Config template
│       └── references/
│           ├── examples.md
│           ├── custom-rules.md
│           ├── consistency-validation.md
│           ├── type-detection.md      # Type detection rules
│           ├── scope-detection.md     # Scope inference rules
│           └── body-validation.md     # Body validation rules
└── AGENTS.md                    # This file
```

## Agents

None. All detection and validation logic is inlined into the skill using progressive disclosure references.

## When to Modify

| Task | File |
|------|------|
| Change type detection | `skills/.../references/type-detection.md` |
| Change scope inference | `skills/.../references/scope-detection.md` |
| Change body validation | `skills/.../references/body-validation.md` |
| Change report format | `skills/.../SKILL.md` (Step 5) |
| Change generation workflow | `skills/.../SKILL.md` |
| Change config options | `skills/.../commitmsgrc-template.md` |
| Change clipboard handling | `commands/commit-gen.md` |

## Design Philosophy

1. **Trust Claude's knowledge** - No duplication of Conventional Commits spec
2. **Inline logic** - No agent overhead for deterministic tasks
3. **Confidence-based interaction** - Ask user only when LOW confidence
4. **Progressive disclosure** - Reference files for detailed rules
