> Conceptual overview and design rationale for this module live in `README.md`
> (same directory). The references and constraints below are sufficient for most
> code changes; read the README only when you need the mental model.

## Directory Structure

```
plugins/shopware-documentation/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── structuring-documentation/
│       ├── SKILL.md
│       ├── .agent-skills
│       ├── references/
│       │   ├── surface-contract.md
│       │   └── splitting.md
│       └── scripts/
│           └── measure.sh
├── README.md
├── AGENTS.md                            # This file
└── CHANGELOG.md
```

A local `CLAUDE.md` containing `@AGENTS.md` may sit beside this file. It is gitignored repo-wide, so it stays untracked by convention and never ships with the plugin.

## Runtime vs Developer Docs

| Runtime (executed or loaded by the skill)                         | Developer docs (human reference only) |
|-------------------------------------------------------------------|---------------------------------------|
| `skills/structuring-documentation/SKILL.md`                       | `README.md`                           |
| `skills/structuring-documentation/references/surface-contract.md` | `AGENTS.md` (this file)               |
| `skills/structuring-documentation/references/splitting.md`        | `CHANGELOG.md`                        |
| `skills/structuring-documentation/scripts/measure.sh`             |                                       |

## Tests

Tests live in `plugin-tests/shopware-documentation/`: `measure_cli.bats`, `measure_size.bats`, `measure_links.bats`, plus fixtures under `fixtures/`. Run via `.bats/bats-core/bin/bats plugin-tests/shopware-documentation/*.bats` from the repo root.

## Version Sync

`plugin.json` version, the `structuring-documentation` skill's `SKILL.md` frontmatter version, and the latest `CHANGELOG.md` entry stay in lockstep. Bump all three together; see the `plugin-updating` skill.
