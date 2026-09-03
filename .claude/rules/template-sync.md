---
paths:
  - "templates/**"
  - "plugins/*/shared/mcpserver_core.sh"
  - "plugins/*/shared/config.sh"
  - "plugins/*/shared/environment.sh"
  - "plugins/*/shared/docker-compose.sh"
  - "plugins/*/hooks/scripts/lib/common.sh"
  - "plugins/*/SETUP.md"
  - "plugins/plugin-setup/skills/*/SKILL.md"
  - "plugins/plugin-setup/skills/*/references/plugin-setup.md"
---

# Template Sync Enforcement

Files matched by this rule are copies. Never edit a copy in place — change the source of truth and propagate.

`plugins/*/shared/mcpserver_core.sh` is vendored from the `shopwareLabs/bash-mcp-sdk` repository at the release pinned in `.mcp-sdk.lock` — it has no template in this repository. Protocol changes go upstream, get released there, then land here by bumping the lock (both `version=` and `sha256=`) and running `.github/scripts/vendor-mcp-sdk.sh`. `--check` verifies without writing. Everything else in the mapping below is templated from `templates/`.

## Workflow

1. Edit the template
2. Copy to every consumer in the mapping
3. Verify with the "Validate template synchronization" step of `.github/workflows/validate.yml` (the same script also runs in CI)

## Mapping

The script invocation in the workflow step above is authoritative. Adding or removing a consumer means updating that step and this table together.

| Mode | Template | Consumer |
|---|---|---|
| vendored | `shopwareLabs/bash-mcp-sdk` `lib/mcpserver_core.sh` at `.mcp-sdk.lock` | `plugins/dev-tooling/shared/mcpserver_core.sh` |
| vendored | `shopwareLabs/bash-mcp-sdk` `lib/mcpserver_core.sh` at `.mcp-sdk.lock` | `plugins/test-writing/shared/mcpserver_core.sh` |
| identical | `templates/mcp-shared/config.sh` | `plugins/dev-tooling/shared/config.sh` |
| identical | `templates/mcp-shared/environment.sh` | `plugins/dev-tooling/shared/environment.sh` |
| identical | `templates/mcp-shared/docker-compose.sh` | `plugins/dev-tooling/shared/docker-compose.sh` |
| identical | `templates/hooks-shared/common.sh` | `plugins/dev-tooling/hooks/scripts/lib/common.sh` |
| identical | `plugins/dev-tooling/SETUP.md` | `plugins/plugin-setup/skills/dev-tooling-setting-up/references/plugin-setup.md` |
| body | `templates/plugin-setup/SKILL.md` | `plugins/plugin-setup/skills/dev-tooling-setting-up/SKILL.md` |
| identical | `plugins/chunkhound-integration/SETUP.md` | `plugins/plugin-setup/skills/chunkhound-integration-setting-up/references/plugin-setup.md` |
| body | `templates/plugin-setup/SKILL.md` | `plugins/plugin-setup/skills/chunkhound-integration-setting-up/SKILL.md` |
| vendored | `shopwareLabs/bash-mcp-sdk` `lib/mcpserver_core.sh` at `.mcp-sdk.lock` | `plugins/shopware-env/shared/mcpserver_core.sh` |
| identical | `templates/mcp-shared/config.sh` | `plugins/shopware-env/shared/config.sh` |
| identical | `templates/mcp-shared/environment.sh` | `plugins/shopware-env/shared/environment.sh` |
| identical | `templates/mcp-shared/docker-compose.sh` | `plugins/shopware-env/shared/docker-compose.sh` |
| identical | `templates/hooks-shared/common.sh` | `plugins/shopware-env/hooks/scripts/lib/common.sh` |

**`vendored`**: copy must be byte-identical to the SDK file at the pinned release; enforced by `vendor-mcp-sdk.sh --check` in `.github/workflows/validate.yml`, not by the template-sync script.
**`identical`**: copy must be byte-identical.
**`body`**: content below the second `---` must match. Frontmatter stays skill-specific — replace only the body, leave `name`, `description`, and `version` alone. The `version` field must match the consumer plugin's `plugin.json`; bump it when the consumer plugin version bumps.

## Not templated

`plugins/dev-tooling/shared/scope.sh` is owned by dev-tooling. Don't add it to the mapping.
