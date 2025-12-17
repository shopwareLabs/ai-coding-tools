@README.md

# Shopware Claude Code Plugin Marketplace - Technical Reference

## Understanding Skills

**Skills are executable code, not documentation.** Markdown files in `skills/[skill-name]/` directories (SKILL.md, references/*.md) are instruction files that Claude Code reads and executes. Modifying these files changes the skill's behavior directly - treat them as you would Python or JavaScript code.

## Understanding Slash Commands

**Slash commands are executable code, not documentation.** Markdown files in `commands/` directories are instruction files that Claude Code reads and executes when users invoke the command. Modifying these files changes what happens when users run the slash command.

## Marketplace Architecture

### Structure
```
.claude-plugin/marketplace.json  # Main catalog
plugins/
  [category]/
    [plugin-name]/              # Plugin source directory
```

### marketplace.json Schema

The marketplace configuration follows the official Claude Code marketplace schema. See [docs/marketplace-schema.json](../docs/marketplace-schema.json) for the complete JSON Schema definition.

**Required fields:**
- `name` - Marketplace identifier in kebab-case
- `owner` - Object with at least `name` property (optionally `email`, `url`)
- `plugins` - Array of plugin definitions

**Plugin object structure:**
- `name` (required) - Plugin identifier in kebab-case
- `source` (required) - Relative path starting with `./`
- `description` - Brief description of functionality
- `version` - Semantic version string
- `author` - Object with `name`, optionally `email` and `url`
- `license` - SPDX license identifier (e.g., "MIT", "Apache-2.0")
- `keywords` - Array of tags for discovery
- `homepage` - Documentation URL
- `repository` - Source code repository URL

## Plugin Component Types

Claude Code plugins can include any combination of these components:

- **Commands** - Custom slash commands (markdown files in `commands/`)
- **Agents** - Specialized subagents (markdown files in `agents/`)
- **Skills** - Model-invoked capabilities (`skills/[skill-name]/SKILL.md`)
- **Hooks** - Event handlers (configured via `hooks/hooks.json`)
- **MCP Servers** - External tool integration (`.mcp.json` configuration)

### MCP Server Cross-Plugin Dependencies

When an MCP config plugin needs to reference server code from another plugin, **do not use relative paths** like `${CLAUDE_PLUGIN_ROOT}/../other-plugin/`. This fails because the plugin cache uses versioned subdirectories (`plugin-name/1.0.0/`).

**Solution**: Use a wrapper script that dynamically discovers the dependency:

```bash
#!/bin/bash
# run-server.sh
CACHE_ROOT="$(dirname "$(dirname "$(cd "$(dirname "$0")" && pwd)")")"
SERVER=$(find "$CACHE_ROOT/dependency-plugin" -name "server.sh" -path "*/mcp-server/*" 2>/dev/null | sort -V | tail -1)
[ -z "$SERVER" ] && echo '{"jsonrpc":"2.0","error":{"code":-32603,"message":"dependency-plugin not found"}}' >&2 && exit 1
exec "$SERVER" "$@"
```

Reference in `.mcp.json`: `"command": "${CLAUDE_PLUGIN_ROOT}/run-server.sh"`

See `plugins/code-quality/php-tooling/` for implementation.

### Skills Directory Structure

Skills follow this pattern:
```
plugin-root/
└── skills/
    └── skill-name/
        └── SKILL.md
```

Example: `plugins/code-quality/comment-review/skills/comment-reviewing/SKILL.md`

## Development Workflow

### Adding a New Plugin

1. **Create plugin directory**: `plugins/[category]/[plugin-name]/`
2. **Add component files** (choose any combination):
   - `commands/` - Custom slash commands
   - `agents/` - Specialized agents
   - `skills/[skill-name]/SKILL.md` - Model-invoked skills
   - `hooks/` - Event handlers (hooks.json)
   - `.mcp.json` - MCP server configuration
3. **Update marketplace.json**:
   - Add entry to `plugins` array with required fields: `name`, `source`
   - Set `source` to relative path starting with `./`
   - Add recommended fields: `description`, `version`, `author`, `license`, `keywords`, `repository`
4. **Update README.md**: Add to "Available Plugins" section
5. **Validate**: `claude plugin validate .`

### Version Management

- Plugin versions: Individual `version` field in plugin entries
- Follow semantic versioning (e.g., "1.0.0", "2.1.3")
- Bump versions when releasing updates or breaking changes
- Skill versions: When updating a plugin version in `marketplace.json`, also update the `version` field in the YAML frontmatter of all skills belonging to that plugin (`skills/*/SKILL.md`)

## Testing & Validation

### Local Testing
```bash
# Validate marketplace structure
claude plugin validate .

# Test locally before publishing
/plugin marketplace add /path/to/claude-code-plugins
```

### Pre-release Checklist
- [ ] `claude plugin validate .` passes
- [ ] All plugin versions updated in marketplace.json
- [ ] All skill versions updated in SKILL.md frontmatter (must match plugin version)
- [ ] README.md "Available Plugins" section current

## Distribution

Repository must be public with `.claude-plugin/marketplace.json` in root for GitHub distribution.

## Plugin Usage Directives

Directives for using official Anthropic plugins when developing this marketplace. Follow the thin subagent pattern for context isolation.

### Thin Subagent Invocation Pattern

When invoking plugin-dev skills, use the Task tool for context isolation:

```
Task(subagent_type="skill-reviewer", prompt="Review the skill at [path]")
```

This provides:
- **Context isolation** - Skill runs in separate context window
- **Role specification** - Agent focuses solely on skill task
- **Clean output** - Results returned without polluting main context

### Plugin Development (plugin-dev)

**Proactive Usage Rules:**
- ALWAYS use `/plugin-dev:create-plugin` when creating new plugins for this marketplace
- ALWAYS invoke `skill-reviewer` agent after creating or modifying any skill
- ALWAYS invoke `plugin-validator` agent before committing plugin changes

**Skill Invocation (via Task tool for isolation):**

| Skill | When to Invoke | Pre-validation |
|-------|---------------|----------------|
| `plugin-dev:skill-development` | Creating/improving skills | Verify skills/ directory exists |
| `plugin-dev:agent-development` | Creating/improving agents | Verify agents/ directory exists |
| `plugin-dev:command-development` | Creating slash commands | Verify commands/ directory exists |
| `plugin-dev:hook-development` | Adding hooks | Verify hooks/ directory structure |
| `plugin-dev:mcp-integration` | Configuring MCP servers | Verify .mcp.json path |
| `plugin-dev:plugin-structure` | Setting up plugin architecture | Verify plugin root path |
| `plugin-dev:plugin-settings` | Adding plugin configuration | Verify .claude/ directory exists |

**Agent Invocation (via Task tool):**

| Agent | When to Invoke | Scope Constraints |
|-------|---------------|-------------------|
| `skill-reviewer` | After creating/modifying skills | Read-only analysis, no edits |
| `agent-creator` | When user requests new agent | Generate config only, user applies |
| `plugin-validator` | Before commits/publishing | Validation only, report issues |

### Feature Development (feature-dev)

**Proactive Usage Rules:**
- Use `/feature-dev` when implementing significant new features
- Use `code-explorer` agent to understand existing patterns before making changes
- Use `code-architect` agent for non-trivial implementation decisions
- Use `code-reviewer` agent after completing significant code changes

**Command:**
- `/feature-dev [description]` - 7-phase guided workflow: Discovery → Exploration → Clarification → Architecture → Implementation → Review → Integration

**Agent Invocation (via Task tool):**

| Agent | When to Invoke | Scope Constraints |
|-------|---------------|-------------------|
| `code-explorer` | Research before changes | Read-only exploration |
| `code-architect` | Architectural decisions | Design only, no implementation |
| `code-reviewer` | After significant changes | Review only, suggest improvements |
