# Plugin Setup

Interactive setup skills for plugins that ship a `SETUP.md`. Install this plugin alongside `dev-tooling` or `chunkhound-integration` and ask Claude to walk you through configuration. Uninstall it once setup is complete to keep the skill description surface small.

## ⚡ Quick Start

```bash
/plugin install plugin-setup@shopware-ai-coding-tools
```

Then ask Claude to set up the plugin you just installed:

```
Help me set up dev-tooling
Help me set up chunkhound-integration
```

## 🧩 Skills

| Skill                               | Trigger                         | Source plugin            |
|-------------------------------------|---------------------------------|--------------------------|
| `dev-tooling-setting-up`            | "set up dev-tooling"            | `dev-tooling`            |
| `chunkhound-integration-setting-up` | "set up chunkhound-integration" | `chunkhound-integration` |

Each skill checks prerequisites, creates or updates config files, pre-approves MCP tool permissions in `.claude/settings.local.json`, validates the result, and reports any remaining manual steps.

## 🔗 How it stays in sync

Each skill's reference file (`references/plugin-setup.md`) is a byte-identical copy of the source plugin's `SETUP.md`. The template body (`skills/<name>/SKILL.md`) is kept in sync with `templates/plugin-setup/SKILL.md`. Both copies are validated by CI via `.github/scripts/validate-template-sync.sh`.

To update a setup guide, edit the source plugin's `SETUP.md`, then copy it to this plugin's corresponding `references/plugin-setup.md`.

## ⚖️ License

MIT
