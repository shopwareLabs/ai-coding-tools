# GitHub Scripts

Automation scripts for maintaining the AI Coding Tools repository.

## Quick Start

```bash
# Validate issue templates (CI/CD use)
.github/scripts/validate-issue-templates.sh

# Update issue templates (maintenance)
.github/scripts/update-issue-templates.sh

# Validate plugin versions (CI/CD use)
.github/scripts/validate-versions.sh

# Synchronize plugin versions (maintenance)
.github/scripts/update-versions.sh
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

### validate-versions.sh

Read-only validation for CI/CD pipelines. Verifies that plugin versions are synchronized across plugin.json (authoritative source), README.md, SKILL.md frontmatter, and CHANGELOG.md.

**Usage:**
```bash
./validate-versions.sh                # Normal mode
./validate-versions.sh --github-actions  # CI mode (auto-detected)
```

**Exit Codes:**
- `0` - All versions synchronized
- `1` - Version mismatches detected
- `2` - Fatal error

**Features:**
- GitHub Actions integration (annotations, job summaries, output variables)
- Per-plugin validation with detailed error reporting
- Never modifies files

---

### update-versions.sh

Synchronizes plugin versions from plugin.json (authoritative source: `.claude-plugin/plugin.json` per plugin) to README.md, SKILL.md files, and CHANGELOG.md.

**Usage:**
```bash
./update-versions.sh                  # Update all plugins
./update-versions.sh --dry-run        # Preview changes
./update-versions.sh --plugin name    # Update single plugin
```

**Exit Codes:**
- `0` - Success
- `2` - Fatal error

**Features:**
- Uses marketplace.json as single source of truth
- Creates `.bak` backups before modifications
- Dry-run mode for safe previews
- Single-plugin mode for targeted updates

---

### discover-components.sh

Library script for discovering plugin components. Source this in other scripts.

**Functions:**
- `discover_plugins()` - Published plugins
- `discover_commands()` - Slash commands with plugins
- `discover_skills()` - Skills with plugins
- `discover_agents()` - Agents with plugins
- `discover_plugins_with_hooks()` - Plugins containing hooks
- `discover_mcp_servers()` - MCP servers with plugins
- `discover_plugins_with_mcp()` - Plugins containing MCP servers

**Usage:**
```bash
export REPO_ROOT="/path/to/repo"
export MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
source discover-components.sh
```

---

### setup-bats.sh

Installs BATS testing framework for hook script testing.

**Usage:**
```bash
./.github/scripts/setup-bats.sh
```

**Installs to:** `.bats/` directory (gitignored)

**Components:**
- bats-core v1.11.0
- bats-support v0.3.0
- bats-assert v2.1.0

**Related:**
- Tests: `plugin-tests/**/*.bats`
- CI Workflow: `.github/workflows/test-hooks.yml`

## Libraries

### lib/common.sh
Shared utilities: logging, validation, dependency checking, GitHub Actions auto-detection.

### lib/yaml-operations.sh
YAML manipulation: `extract_dropdown_options()`, `update_dropdown()`.

### lib/version-operations.sh
Version management: `extract_plugin_version()`, `extract_readme_version()`, `extract_skill_version()`, `extract_changelog_version()`, `update_readme_version()`, `update_skill_version()`, `update_changelog_header()`. Authoritative source: `.claude-plugin/plugin.json` per plugin.

## Requirements

- **jq** - JSON processor
- **sed** - Stream editor
- **Bash 3.2+** - macOS/Linux compatible

Install on macOS: `brew install jq`
Install on Ubuntu: `sudo apt-get install -y jq`

## Developer Guide

See `AGENTS.md` for architecture details and modification guidance.
