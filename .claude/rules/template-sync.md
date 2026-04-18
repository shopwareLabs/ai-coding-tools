---
paths:
  - "templates/**"
  - "plugins/*/shared/mcpserver_core.sh"
  - "plugins/*/shared/config.sh"
  - "plugins/*/shared/environment.sh"
  - "plugins/*/shared/docker-compose.sh"
  - "plugins/*/hooks/scripts/lib/common.sh"
  - "plugins/*/SETUP.md"
  - "plugins/*/skills/setting-up/SKILL.md"
  - "plugins/*/skills/setting-up/references/plugin-setup.md"
---

# Template Sync Enforcement

The files matched by this rule have a source of truth in `templates/`. Do not edit them in-place inside a plugin.

## Workflow

1. Make changes in the template directory first
2. Copy to every consumer plugin listed below
3. Verify byte-identical with `diff` (see exception for setup skill frontmatter)

## Mapping

| Template | Consumer | Identical? |
|---|---|---|
| `templates/mcp-shared/mcpserver_core.sh` | `plugins/dev-tooling/shared/mcpserver_core.sh` | yes |
| `templates/mcp-shared/config.sh` | `plugins/dev-tooling/shared/config.sh` | yes |
| `templates/mcp-shared/environment.sh` | `plugins/dev-tooling/shared/environment.sh` | yes |
| `templates/mcp-shared/docker-compose.sh` | `plugins/dev-tooling/shared/docker-compose.sh` | yes |
| `templates/hooks-shared/common.sh` | `plugins/dev-tooling/hooks/scripts/lib/common.sh` | yes |
| `templates/plugin-setup/SKILL.md` | `plugins/<plugin>/skills/setting-up/SKILL.md` for every plugin with a `SETUP.md` | body identical, frontmatter differs |
| `plugins/<plugin>/SETUP.md` | `plugins/<plugin>/skills/setting-up/references/plugin-setup.md` | yes |

## Setup skill frontmatter exception

`plugins/<plugin>/skills/setting-up/SKILL.md` shares its body with the template but keeps a per-plugin frontmatter. When syncing from `templates/plugin-setup/SKILL.md`:

1. Replace the body below the closing `---` with the template body
2. Leave the frontmatter alone — `name`, `description`, and `version` are plugin-specific
3. The `version` field must match `plugins/<plugin>/.claude-plugin/plugin.json`; if the plugin was just version-bumped, update it here too

Verification: `diff <(sed '1,/^---$/d; 1,/^---$/d' template) <(sed '1,/^---$/d; 1,/^---$/d' copy)` — body-only diff must be empty.

## Exception

`plugins/dev-tooling/shared/scope.sh` is owned by dev-tooling. Not templated.
