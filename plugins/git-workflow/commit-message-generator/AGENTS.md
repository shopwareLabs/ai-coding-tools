@README.md

## Directory & File Structure

```
plugins/git-workflow/commit-message-generator/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── agents/
│   └── type-detector.md                        # Type detection agent
├── references/
│   └── type-detection.md                       # Type detection heuristics (plugin-owned)
├── commands/
│   ├── commit-gen.md                           # Generate commit message
│   └── commit-check.md                         # Validate commit message
└── skills/
    └── commit-message-generating/             # Core skill implementation
        ├── SKILL.md                            # Main skill logic
        ├── commitmsgrc-template.md             # Configuration template
        ├── scripts/                            # Utility shell scripts
        │   ├── git-commit-helpers.sh           # Git operations helpers
        │   └── clipboard-helper.sh             # Cross-platform clipboard integration
        └── references/                         # Progressive disclosure references (skill-owned)
            ├── conventional-commits-spec.md    # Full spec reference
            ├── scope-detection.md              # How to infer scope
            ├── consistency-validation.md       # Validation rules
            ├── custom-rules.md                 # Configuration guide
            ├── error-handling.md               # Error recovery patterns
            ├── examples.md                     # Example workflows
            ├── output-formats.md               # Output formatting rules
            └── validation-checklist.md         # Validation checklist
```

## Component Overview

This plugin provides:
- **Agents** (`agents/`) - Specialized subagents for complex analysis tasks
- **Slash Commands** (`commands/`) - User-facing commands that invoke the skill
- **Skill** (`skills/commit-message-generating/SKILL.md`) - Core generation and validation logic
- **Utility Scripts** (`scripts/`) - Bash helpers for git operations
- **Reference Files** (`references/`) - Progressive disclosure knowledge files
- **Config Template** - Project-specific customization template

## Agents

### Type Detector Agent

**Rationale for Haiku 4.5:** Cost/speed optimized for pattern-based commit type decisions.

**When to Modify:**
- New commit type patterns → Edit `agents/type-detector.md` + `references/type-detection.md`
- Confidence thresholds → Edit `agents/type-detector.md` decision logic
- Breaking change rules → Edit `agents/type-detector.md` API compatibility checks

## Key Navigation Points

### Finding Specific Functionality

| Task | Primary File | Secondary File | Key Concepts |
|------|--------------|----------------|--------------|
| Modify data source detection | `SKILL.md` Step 0 | `commands/commit-gen.md` | Staged vs. commit detection |
| Modify type detection logic | `agents/type-detector.md` | `references/type-detection.md` | Decision tree, heuristics, patterns |
| Modify type detection invocation | `SKILL.md` Step 2 | `agents/type-detector.md` | Agent integration, result handling |
| Modify scope inference | `SKILL.md` Step 3 | `references/scope-detection.md` | Path-based detection |
| Add validation rules | `SKILL.md` | `references/consistency-validation.md` | Type/scope/subject checks |
| Extend git operations | `scripts/git-commit-helpers.sh` | - | 14 bash functions |
| Modify clipboard integration | `scripts/clipboard-helper.sh` | `SKILL.md` Step 7 | Cross-platform clipboard |
| Add config option | `commitmsgrc-template.md` | `references/custom-rules.md` | YAML schema |
| Update spec reference | `references/conventional-commits-spec.md` | - | Format, validation rules |
| Add new agent | `agents/new-agent.md` | `SKILL.md` (invocation point) | Agent architecture, Task tool |

## When to Modify What

**Supporting new data sources** (e.g., branches, tags, commit ranges) → Edit `SKILL.md` Step 0 + update `commands/commit-gen.md` scope detection section

**Changing type detection heuristics** → Edit `agents/type-detector.md` patterns section + update `references/type-detection.md` examples

**Changing type detection agent invocation** → Edit `SKILL.md` Step 2 agent invocation + result handling logic

**Adding new commit type** → Edit `agents/type-detector.md` detection patterns + `references/conventional-commits-spec.md` + `commitmsgrc-template.md` + `SKILL.md` defaults

**Modifying scope inference** → Edit `SKILL.md` Step 3 + update `references/scope-detection.md` patterns

**Adding validation check** → Edit `SKILL.md` validation mode + document in `references/consistency-validation.md`

**Adding config option** → Edit `commitmsgrc-template.md` schema + document in `references/custom-rules.md`

**Adding git helper function** → Edit `scripts/git-commit-helpers.sh` + export function

**Adding/modifying clipboard support** → Edit `scripts/clipboard-helper.sh` + update platform detection + export function

**Updating spec compliance** → Edit `references/conventional-commits-spec.md` + adjust `SKILL.md` validation

**Creating new agent** → Create `agents/new-agent.md` + add invocation in `SKILL.md` + document in `AGENTS.md` agents section

**Modifying breaking change detection** → Edit `agents/type-detector.md` breaking change section + test with API compatibility scenarios
