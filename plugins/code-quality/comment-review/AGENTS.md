@README.md

## Directory & File Structure

```
plugins/code-quality/comment-review/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── commands/
│   ├── comment-review.md                       # Main command (review & edit)
│   └── comment-check.md                        # Read-only analysis command
└── skills/
    └── comment-reviewing/                      # Core skill implementation
        ├── SKILL.md                            # Main skill logic & orchestration
        ├── reviewrc-template.md                # Configuration template
        ├── scripts/                            # Utility shell scripts
        │   ├── git-helpers.sh                  # Git operations & scope detection
        │   └── validate-edit.sh                # Edit pre-validation functions
        └── references/                         # Progressive disclosure references
            ├── api-docs-core-principles.md     # Public/private visibility rules
            ├── api-docs-parameters-and-returns.md  # Parameter documentation guidelines
            ├── api-docs-contracts.md           # Preconditions, postconditions, invariants
            ├── removal-patterns.md             # Examples of removable comments
            ├── improvement-examples.md         # Before/after vague comment fixes
            ├── implementation-comment-condensation.md  # Condense WHY comments
            ├── preservation-guidelines.md      # Valuable comment checklist
            ├── consistency-checking.md         # Detect code/comment mismatches
            ├── uncertainty-patterns.md         # HIGH/MEDIUM/LOW classification rules
            ├── self-validation-checks.md       # Validation rules & auto-correction logic
            ├── special-cases.md                # Legacy code, algorithms, generated files
            ├── config-overview.md              # Configuration quick start
            ├── config-options-reference.md     # Detailed config option docs
            ├── config-recipes.md               # Tool-specific patterns (JIRA, GitHub)
            ├── workflow-examples.md            # Complete workflow examples
            └── output-formats.md               # Report templates & verbosity levels
```

## Component Overview

This plugin provides:
- **Slash Commands** (`commands/`) - User-facing commands that invoke the skill
- **Skill** (`skills/comment-reviewing/SKILL.md`) - Core review logic and orchestration
- **Utility Scripts** (`scripts/`) - Bash helpers for git operations and validation
- **Reference Files** (`references/`) - 16 progressive disclosure knowledge files

## Key Navigation Points

### Finding Specific Functionality

| Task | Primary File | Secondary File | Key Concepts |
|------|--------------|----------------|--------------|
| Add removal pattern | `references/removal-patterns.md` | - | Examples section |
| Add improvement example | `references/improvement-examples.md` | - | Before/after pairs |
| Modify uncertainty logic | `SKILL.md` | `references/uncertainty-patterns.md` | Two-stage evaluation |
| Add config option | `reviewrc-template.md` | `references/config-options-reference.md` | Option definitions |
| Extend git support | `scripts/git-helpers.sh` | - | 6 git functions |
| Add pre-edit check | `scripts/validate-edit.sh` | - | Validation functions |
| Modify output format | `SKILL.md` | `references/output-formats.md` | Template section |


## When to Modify What

**Adding removal/improvement patterns** → Edit `references/removal-patterns.md` or `references/improvement-examples.md` (no SKILL.md changes needed)

**Extending uncertainty evaluation** → Edit `references/uncertainty-patterns.md` (add pattern types, content signals, decision tree)

**Adding configuration options** → Edit `reviewrc-template.md` + document in `references/config-options-reference.md`

**Changing output format** → Edit `references/output-formats.md` templates

**Adding reference file** → Create in `references/` + add progressive disclosure trigger in SKILL.md + document in navigation table above

**Modifying core logic** → Edit `SKILL.md` (scope detection, workflow orchestration, validation)


## Integration Points

### With Other Plugins
- Can be invoked by other skills/agents via skill API
- Standalone operation (no dependencies on other plugins)

### With User Projects
- Reads project config from `.reviewrc.md`
- Respects `.gitignore` patterns
- Integrates with git workflow (staging, commits, branches)

### With Claude Code
- Slash commands registered in `commands/`
- Skill available for model invocation
- Hooks: None (standalone plugin)
- MCP servers: None (uses built-in tools only)

## Related Documentation

- **User guide**: [README.md](./README.md)
- **Installation**: [README.md](./README.md#quick-start)
- **Configuration**: `reviewrc-template.md`, `references/config-overview.md`
- **Examples**: `references/workflow-examples.md`
- **Changelog**: [CHANGELOG.md](./CHANGELOG.md)
