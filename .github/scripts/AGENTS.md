@README.md

## Directory & File Structure

```
.github/scripts/
├── README.md                           # Developer quick reference
├── AGENTS.md                          # This file - LLM navigation guide
├── lib/
│   ├── common.sh                      # Shared utilities (logging, validation, env)
│   ├── yaml-operations.sh             # YAML extraction and update functions
│   └── version-operations.sh          # Version extraction and sync functions
├── discover-components.sh             # Component discovery library (plugins/commands/skills/agents)
├── validate-issue-templates.sh        # Read-only template validation (CI/CD ready)
├── update-issue-templates.sh          # Write-only template updates
├── validate-versions.sh               # Read-only version validation (CI/CD ready)
└── update-versions.sh                 # Write-only version synchronization
```

## Component Overview

This directory provides scripts for maintaining the Claude Code Plugins repository:

**Issue Template Management:**
- **Validation Script** (`validate-issue-templates.sh`) - CI/CD validation with GitHub Actions integration
- **Update Script** (`update-issue-templates.sh`) - Simple maintenance updates

**Version Management:**
- **Validation Script** (`validate-versions.sh`) - CI/CD validation of version consistency
- **Update Script** (`update-versions.sh`) - Synchronize versions from marketplace.json

**Libraries:**
- `lib/common.sh` - Shared utilities (logging, validation, env)
- `lib/yaml-operations.sh` - YAML extraction and update functions
- `lib/version-operations.sh` - Version extraction and sync functions
- `discover-components.sh` - Component discovery library

## Architecture

**Two-script design split by responsibility (validate vs update):**

### Issue Template Scripts

- **`validate-issue-templates.sh`** - Read-only validation for CI/CD
  - Compares current template dropdowns against discovered components
  - Never modifies files
  - Integrates with GitHub Actions (annotations, job summaries, outputs)

- **`update-issue-templates.sh`** - Write-only updates for local maintenance
  - Updates template YAML files with discovered components
  - Creates `.bak` backups before modifications
  - Simple operation, no CI features

### Version Management Scripts

- **`validate-versions.sh`** - Read-only validation for CI/CD
  - Compares versions across marketplace.json, README.md, SKILL.md, CHANGELOG.md
  - marketplace.json is the authoritative source
  - Integrates with GitHub Actions (annotations, job summaries, outputs)

- **`update-versions.sh`** - Write-only synchronization
  - Propagates versions from marketplace.json to all other locations
  - Creates `.bak` backups before modifications
  - Supports `--dry-run` and `--plugin <name>` options

**Shared libraries** (sourced by scripts):
- `lib/common.sh` - Logging, validation, dependency checks
- `lib/yaml-operations.sh` - YAML parsing and manipulation with AWK
- `lib/version-operations.sh` - Version extraction and update functions
- `discover-components.sh` - Component discovery from marketplace structure

## Key Navigation Points

| Task | Primary File | Secondary File | Key Concepts |
|------|--------------|----------------|--------------|
| Add GitHub Actions feature | `validate-*.sh` scripts | `lib/common.sh` | Annotations, job summaries, output vars |
| Add logging function | `lib/common.sh` | - | log_info, log_success, log_warning, log_error |
| Add YAML operation | `lib/yaml-operations.sh` | - | AWK-based parsing, extraction, updates |
| Add version operation | `lib/version-operations.sh` | - | jq/awk/sed parsing, extraction, updates |
| Add component discovery | `discover-components.sh` | - | find commands, jq parsing |
| Modify template validation | `validate-issue-templates.sh` | `lib/yaml-operations.sh` | validate_dropdown(), array comparison |
| Modify template update | `update-issue-templates.sh` | `lib/yaml-operations.sh` | update_dropdown(), backup creation |
| Modify version validation | `validate-versions.sh` | `lib/version-operations.sh` | validate_*_version(), per-plugin checks |
| Modify version update | `update-versions.sh` | `lib/version-operations.sh` | update_*_version(), backup creation |
| Add template type | template scripts + ISSUE_TEMPLATE | `discover-components.sh` | Discovery + validation + update functions |
| Add version location | version scripts | `lib/version-operations.sh` | Extract + update functions |

## When to Modify What

**Adding GitHub Actions feature** (annotations, summaries, outputs) → Edit `validate-*.sh` scripts with `GITHUB_ACTIONS_MODE` checks + update `lib/common.sh` for logging if needed

**Adding new logging level** → Edit `lib/common.sh` log functions + add both normal and GitHub Actions mode outputs

**Adding YAML operation** → Edit `lib/yaml-operations.sh` + add new function with AWK-based parsing pattern

**Adding version operation** → Edit `lib/version-operations.sh` + add extract_*_version() and update_*_version() functions

**Adding component discovery type** → Edit `discover-components.sh` + add new function with find/jq pattern + export function

**Adding template type** (e.g., hooks) → Create discovery function in `discover-components.sh` + add validation function in `validate-issue-templates.sh` + add update function in `update-issue-templates.sh` + call from main() in both scripts + create template in `.github/ISSUE_TEMPLATE/`

**Adding version location** (new file with version) → Add extract function + update function in `lib/version-operations.sh` + add validation in `validate-versions.sh` + add sync in `update-versions.sh`

**Changing template file locations** → Edit TEMPLATES_DIR in main scripts + update validation/update functions

**Modifying backup behavior** → Edit update functions in `lib/yaml-operations.sh` or `lib/version-operations.sh` + modify cp command or add versioning

**Adding environment variable** → Edit `lib/common.sh` or main script setup sections + add validation in validate_*_files()
