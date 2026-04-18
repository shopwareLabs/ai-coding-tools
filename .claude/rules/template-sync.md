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

Files matched by this rule are copies. The source of truth is `templates/`. Never edit a copy in place — edit the template and propagate.

## Workflow

1. Edit the template
2. Copy to every consumer in the mapping
3. Verify with the "Validate template synchronization" step of `.github/workflows/validate.yml` (the same script also runs in CI)

## Mapping

The script invocation in the workflow step above is authoritative. Adding or removing a consumer means updating that step and this table together.

| Mode | Template | Consumer |
|---|---|---|
| identical | `templates/mcp-shared/mcpserver_core.sh` | `plugins/dev-tooling/shared/mcpserver_core.sh` |
| identical | `templates/mcp-shared/config.sh` | `plugins/dev-tooling/shared/config.sh` |
| identical | `templates/mcp-shared/environment.sh` | `plugins/dev-tooling/shared/environment.sh` |
| identical | `templates/mcp-shared/docker-compose.sh` | `plugins/dev-tooling/shared/docker-compose.sh` |
| identical | `templates/hooks-shared/common.sh` | `plugins/dev-tooling/hooks/scripts/lib/common.sh` |
| identical | `plugins/dev-tooling/SETUP.md` | `plugins/dev-tooling/skills/setting-up/references/plugin-setup.md` |
| body | `templates/plugin-setup/SKILL.md` | `plugins/dev-tooling/skills/setting-up/SKILL.md` |
| identical | `plugins/gh-tooling/SETUP.md` | `plugins/gh-tooling/skills/setting-up/references/plugin-setup.md` |
| body | `templates/plugin-setup/SKILL.md` | `plugins/gh-tooling/skills/setting-up/SKILL.md` |
| identical | `plugins/chunkhound-integration/SETUP.md` | `plugins/chunkhound-integration/skills/setting-up/references/plugin-setup.md` |
| body | `templates/plugin-setup/SKILL.md` | `plugins/chunkhound-integration/skills/setting-up/SKILL.md` |
| identical | `templates/mcp-shared/mcpserver_core.sh` | `plugins/shopware-env/shared/mcpserver_core.sh` |
| identical | `templates/mcp-shared/config.sh` | `plugins/shopware-env/shared/config.sh` |
| identical | `templates/mcp-shared/environment.sh` | `plugins/shopware-env/shared/environment.sh` |
| identical | `templates/mcp-shared/docker-compose.sh` | `plugins/shopware-env/shared/docker-compose.sh` |
| identical | `templates/hooks-shared/common.sh` | `plugins/shopware-env/hooks/scripts/lib/common.sh` |

**`identical`**: copy must be byte-identical.
**`body`**: content below the second `---` must match. Frontmatter stays plugin-specific — replace only the body, leave `name`, `description`, and `version` alone. The `version` field must match `plugins/<plugin>/.claude-plugin/plugin.json`; bump it here when the plugin version bumps.

## Not templated

`plugins/dev-tooling/shared/scope.sh` is owned by dev-tooling. Don't add it to the mapping.
