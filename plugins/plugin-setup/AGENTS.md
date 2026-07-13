@README.md

## Directory Structure

```
plugins/plugin-setup/
├── .claude-plugin/plugin.json    # Plugin metadata
├── CHANGELOG.md                  # Version history
├── CLAUDE.md                     # Points to AGENTS.md
├── AGENTS.md                     # This file
├── README.md                     # User documentation
└── skills/
    ├── dev-tooling-setting-up/
    │   ├── SKILL.md              # Synced body from templates/plugin-setup/SKILL.md
    │   └── references/
    │       └── plugin-setup.md   # Synced copy of plugins/dev-tooling/SETUP.md
    └── chunkhound-integration-setting-up/
        ├── SKILL.md              # Synced body from templates/plugin-setup/SKILL.md
        └── references/
            └── plugin-setup.md   # Synced copy of plugins/chunkhound-integration/SETUP.md
```

## Skills

Each skill is a thin shell around a source plugin's `SETUP.md`. The interactive workflow is identical across the three skills; what varies is the plugin-specific frontmatter and the per-plugin setup guide loaded from `references/plugin-setup.md`.

- **Workflow changes** (for all three skills) → Edit `templates/plugin-setup/SKILL.md`, then resync into each skill's `SKILL.md` body
- **Setup procedure for dev-tooling** → Edit `plugins/dev-tooling/SETUP.md`, then resync into `skills/dev-tooling-setting-up/references/plugin-setup.md`
- **Setup procedure for chunkhound-integration** → Edit `plugins/chunkhound-integration/SETUP.md`, then resync into `skills/chunkhound-integration-setting-up/references/plugin-setup.md`
- **Skill description / trigger phrasing** → Edit the `description` field in each skill's `SKILL.md` frontmatter. Frontmatter is skill-specific and not template-synced.

## Adding a new setup skill

When a fourth plugin gains a `SETUP.md`:

1. Create `plugins/<source-plugin>/SETUP.md` in the source plugin (source of truth)
2. Add `skills/<source-plugin>-setting-up/SKILL.md` here with plugin-specific frontmatter (`name`, `description`) and the body from `templates/plugin-setup/SKILL.md`
3. Create `skills/<source-plugin>-setting-up/references/plugin-setup.md` as a copy of the source plugin's `SETUP.md`
4. Add two template-sync mappings (one `body` for `SKILL.md`, one `identical` for `references/plugin-setup.md`) in both `.claude/rules/template-sync.md` and `.github/workflows/validate.yml`
5. Update this plugin's `README.md` skills table and the root `README.md` plugin-setup section

## Key Design Decisions

- **Template-synced**: Each skill's `SKILL.md` body and `references/plugin-setup.md` are kept in sync via `.github/scripts/validate-template-sync.sh`. The authoritative mapping lives in `.claude/rules/template-sync.md` and the workflow step.
- **Skill versions match the plugin-setup plugin version**, not the source plugin's version. The `validate-versions.sh` check expects each skill's `version` frontmatter to match `.claude-plugin/plugin.json`. Bump skills and `plugin.json` together when plugin-setup changes.
- **SETUP.md stays in the source plugin**, not in this plugin. The source plugin owns its setup procedure. This plugin only hosts the interactive skills that consume those guides.
- **Plugin-specific descriptions** in each skill's frontmatter drive auto-routing. The body is identical, but the description must mention the source plugin name and likely user phrasing ("set up dev-tooling", "set up chunkhound-integration") so the right skill activates.
- **No runtime components**. Only skills. No MCP server, no hooks, no commands, no agents. This keeps the plugin uninstallable after setup without disrupting other plugins.
