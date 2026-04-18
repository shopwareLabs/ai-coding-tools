---
name: plugin-updating
description: Update plugin versions for the Shopware AI Coding Tools marketplace. Use when bumping a plugin version. Handles version bumps across plugin.json and SKILL.md frontmatters.
allowed-tools: Read, Edit, Write, Bash, Glob, Grep
---

# Plugin Updating

Handles plugin version management for the Shopware AI Coding Tools marketplace.

Template synchronization for `templates/plugin-setup/` and shared shell scripts is covered by `.claude/rules/template-sync.md`, which activates automatically when a template or consumer file is touched.

## Version Bump

When updating a plugin's version:

### Step 1: Identify the plugin

Determine which plugin to update from context. Verify the plugin exists under `plugins/`.

### Step 2: Determine version bump level

If the user specifies a target version, use it. Otherwise, reason about the changes to determine MAJOR, MINOR, or PATCH.

**Core question:** "Can users do something they could not do before?"

```
MAJOR — Consumer behavior must change to keep working
  Plugin renamed or extracted
  Skill invocation model changed
  MCP tool surface rewritten
  Agent names/roles replaced
  Config files require migration

MINOR — New user-facing capability added
  New skill, MCP tool, hook type, agent, command, or environment
  Significant new parameters on existing tools
  New independently-queryable test rule

PATCH — Everything else
  Bug fixes, refinements, internal refactoring
  Description/docs improvements
  Validation/guard additions to existing features
  Removing deprecated internals
```

**Watch for these traps:**
- "Added" does not always mean MINOR — adding validation to an existing feature is PATCH (same capability, better quality)
- "Breaking" in a description does not always mean MAJOR — if the orchestrator absorbs the change transparently, consumers are unaffected
- Batch additions that individually seem incremental can collectively warrant MINOR when they form a cohesive new capability

For detailed triggers, public API definitions, and edge cases see `references/version-bump-reasoning.md`.

### Step 3: Bump plugin.json and all SKILL.md versions

Run the bundled helper script:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/bump-plugin-version.sh" <plugin> <new-version>
```

It updates `plugins/<plugin>/.claude-plugin/plugin.json` (surgical text replacement that preserves formatting) and rewrites the `version:` field in every `plugins/<plugin>/skills/*/SKILL.md` frontmatter. Do not edit these files by hand.

### Step 4: Update CHANGELOG.md

Read the existing `plugins/<plugin>/CHANGELOG.md`. Add a new version section at the top following the existing format.

### Step 5: Stage changes

```bash
git add plugins/<plugin>
```

Do not commit. The user will commit when ready.

### Step 6: Sync the setup skill version (if applicable)

If the plugin has a `SETUP.md`, the `version` field in `plugins/<plugin>/skills/setting-up/SKILL.md` must match the new plugin version. Update it in place — leave the rest of the frontmatter and body alone. See `.claude/rules/template-sync.md` for the body-sync workflow.

## SETUP.md Format Reference

Plugins that participate in the setup skill pattern have a `SETUP.md` at their root with these required sections:

| Heading | Level | Purpose |
|---------|-------|---------|
| `# {Plugin Name} Setup` | H1 | Plugin name |
| `## Prerequisites` | H2 | External tools to check |
| `### {tool name}` | H3 | One per tool: **Check**, **Install**, **Required by** |
| `## Configuration Files` | H2 | Config files to create |
| `### {filename}` | H3 | One per file: **Required**, **Location** |
| `#### Setup Questions` | H4 | Numbered questions with options |
| `#### Minimal Config` | H4 | Simplest valid config (code block) |
| `## Validation` | H2 | Steps to verify setup |
| `## Post-Setup` | H2 | Restart requirements, next steps |
