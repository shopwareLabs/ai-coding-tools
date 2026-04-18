# Templates

Source of truth for shared code copied into plugins. Plugin copies must be byte-identical to their template.

## Directories

| Directory | Contents | Consumers |
|---|---|---|
| `plugin-setup/` | Setup skill SKILL.md template | Any plugin with a `setting-up` skill |
| `mcp-shared/` | MCP server framework (JSON-RPC, config discovery, env wrapping) | `dev-tooling`, `shopware-env` |
| `hooks-shared/` | Hook script library (input parsing, config loading, tool blocking) | `dev-tooling`, `shopware-env` |

## How sync works

1. Edit the file in `templates/`
2. Copy to every consumer plugin listed in the table above
3. Verify with `diff` — copies must be byte-identical
4. A project-level Claude rule (`.claude/rules/template-sync.md`) activates when plugin copies are touched and reminds to sync from templates

## Adding a shared file

1. Add the file to the appropriate `templates/` subdirectory
2. Copy to all consumer plugins
3. Update the mapping in `.claude/rules/template-sync.md`
4. Update the table in this README

## Adding a consumer plugin

1. Copy all relevant template files into the plugin
2. Add the plugin to the mapping in `.claude/rules/template-sync.md`
3. Update the table in this README

## Not templated

These files live in `plugins/dev-tooling/shared/` but are owned by dev-tooling, not templates:

- `scope.sh` — full scope resolution system (dev-tooling only)
- `mcp-js-tooling.schema.json` — JS config schema (dev-tooling only)
- `lsp_bootstrap.sh`, `lsp_null.sh`, `lsp_proxy.py` — LSP support (dev-tooling only)
