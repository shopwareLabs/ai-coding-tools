---
paths:
  - "plugins/*/shared/mcpserver_core.sh"
  - "plugins/*/shared/config.sh"
  - "plugins/*/shared/environment.sh"
  - "plugins/*/shared/docker-compose.sh"
  - "plugins/*/hooks/scripts/lib/common.sh"
---

# Template Sync Enforcement

The files matched by this rule have a source of truth in `templates/`. Do not edit them in-place inside a plugin.

## Workflow

1. Make changes in the template directory first
2. Copy to all consumer plugins
3. Verify byte-identical with `diff`

## Mapping

| Template | Consumers |
|---|---|
| `templates/mcp-shared/mcpserver_core.sh` | `plugins/dev-tooling/shared/` |
| `templates/mcp-shared/config.sh` | same |
| `templates/mcp-shared/environment.sh` | same |
| `templates/mcp-shared/docker-compose.sh` | same |
| `templates/hooks-shared/common.sh` | `plugins/dev-tooling/hooks/scripts/lib/` |

## Exception

`plugins/dev-tooling/shared/scope.sh` is owned by dev-tooling. Not templated.
