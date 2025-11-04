# GitHub Scripts

Automation scripts for maintaining the Claude Code Plugins repository.

## Quick Start

```bash
# Validate templates (CI/CD use)
.github/scripts/validate-issue-templates.sh

# Update templates (maintenance)
.github/scripts/update-issue-templates.sh
```

## Scripts

### validate-issue-templates.sh

Read-only validation for CI/CD pipelines. Verifies that issue template dropdowns match the current plugin structure.

**Usage:**
```bash
./validate-issue-templates.sh                # Normal mode
./validate-issue-templates.sh --github-actions  # CI mode (auto-detected)
```

**Exit Codes:**
- `0` - All templates up-to-date
- `1` - Templates outdated
- `2` - Fatal error

**Features:**
- GitHub Actions integration (annotations, job summaries, output variables)
- Detailed diff reporting (missing/extra options)
- Never modifies files

---

### update-issue-templates.sh

Updates all issue template dropdowns by scanning the repository for plugins, commands, skills, and agents.

**Usage:**
```bash
./update-issue-templates.sh
```

**Exit Codes:**
- `0` - Success
- `2` - Fatal error

**Features:**
- Updates 4 template files automatically
- Creates `.bak` backups before modifications
- Simple write-only operation

---

### discover-components.sh

Library script for discovering plugin components. Source this in other scripts.

**Functions:**
- `discover_plugins()` - Published plugins
- `discover_commands()` - Slash commands with plugins
- `discover_skills()` - Skills with plugins
- `discover_agents()` - Agents with plugins

**Usage:**
```bash
export REPO_ROOT="/path/to/repo"
export MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
source discover-components.sh
```

## Libraries

### lib/common.sh
Shared utilities: logging, validation, dependency checking, GitHub Actions auto-detection.

### lib/yaml-operations.sh
YAML manipulation: `extract_dropdown_options()`, `update_dropdown()`.

## Requirements

- **jq** - JSON processor
- **sed** - Stream editor
- **Bash 3.2+** - macOS/Linux compatible

Install on macOS: `brew install jq`
Install on Ubuntu: `sudo apt-get install -y jq`

## Developer Guide

See `AGENTS.md` for architecture details and modification guidance.
