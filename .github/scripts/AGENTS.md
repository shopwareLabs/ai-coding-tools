@README.md

## Directory & File Structure

```
.github/scripts/
├── README.md                           # Developer quick reference
├── AGENTS.md                          # This file - LLM navigation guide
├── lib/
│   ├── common.sh                      # Shared utilities (logging, validation, env)
│   └── yaml-operations.sh             # YAML extraction and update functions
├── discover-components.sh             # Component discovery library (plugins/commands/skills/agents)
├── validate-issue-templates.sh        # Read-only validation (CI/CD ready)
└── update-issue-templates.sh          # Write-only template updates
```

## Component Overview

This directory provides scripts for maintaining GitHub issue template dropdowns:

- **Libraries** (`lib/`, `discover-components.sh`) - Reusable functions sourced by main scripts
- **Validation Script** (`validate-issue-templates.sh`) - CI/CD validation with GitHub Actions integration
- **Update Script** (`update-issue-templates.sh`) - Simple maintenance updates

## Architecture

**Two-script design split by responsibility:**

- **`validate-issue-templates.sh`** - Read-only validation for CI/CD
  - Compares current template dropdowns against discovered components
  - Never modifies files
  - Integrates with GitHub Actions (annotations, job summaries, outputs)

- **`update-issue-templates.sh`** - Write-only updates for local maintenance
  - Updates template YAML files with discovered components
  - Creates `.bak` backups before modifications
  - Simple operation, no CI features

**Shared libraries** (sourced by both scripts):
- `lib/common.sh` - Logging, validation, dependency checks
- `lib/yaml-operations.sh` - YAML parsing and manipulation with AWK
- `discover-components.sh` - Component discovery from marketplace structure

## Key Navigation Points

| Task | Primary File | Secondary File | Key Concepts |
|------|--------------|----------------|--------------|
| Add GitHub Actions feature | `validate-issue-templates.sh` | `lib/common.sh` | Annotations, job summaries, output vars |
| Add logging function | `lib/common.sh` | - | log_info, log_success, log_warning, log_error |
| Add YAML operation | `lib/yaml-operations.sh` | - | AWK-based parsing, extraction, updates |
| Add component discovery | `discover-components.sh` | - | find commands, jq parsing |
| Modify validation logic | `validate-issue-templates.sh` | `lib/yaml-operations.sh` | validate_dropdown(), array comparison |
| Modify update logic | `update-issue-templates.sh` | `lib/yaml-operations.sh` | update_dropdown(), backup creation |
| Add template type | All scripts + template | `.github/ISSUE_TEMPLATE/` | Discovery + validation + update functions |

## When to Modify What

**Adding GitHub Actions feature** (annotations, summaries, outputs) → Edit `validate-issue-templates.sh` sections with `GITHUB_ACTIONS_MODE` checks + update `lib/common.sh` for logging if needed

**Adding new logging level** → Edit `lib/common.sh` log functions + add both normal and GitHub Actions mode outputs

**Adding YAML operation** → Edit `lib/yaml-operations.sh` + add new function with AWK-based parsing pattern

**Adding component discovery type** → Edit `discover-components.sh` + add new function with find/jq pattern + export function

**Adding template type** (e.g., hooks) → Create discovery function in `discover-components.sh` + add validation function in `validate-issue-templates.sh` + add update function in `update-issue-templates.sh` + call from main() in both scripts + create template in `.github/ISSUE_TEMPLATE/`

**Changing template file locations** → Edit TEMPLATES_DIR in main scripts + update validation/update functions

**Modifying backup behavior** → Edit `lib/yaml-operations.sh` update_dropdown() + modify cp command or add versioning

**Adding environment variable** → Edit `lib/common.sh` or main script setup sections + add validation in validate_files()
