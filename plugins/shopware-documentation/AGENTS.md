@README.md

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
├── CLAUDE.md
└── CHANGELOG.md
```

## Runtime vs Developer Docs

| Runtime (executed or loaded by the skill)                          | Developer docs (human reference only) |
|----------------------------------------------------------------------|------------------------------------------|
| `skills/structuring-documentation/SKILL.md`                          | `README.md`                              |
| `skills/structuring-documentation/references/surface-contract.md`    | `AGENTS.md` (this file)                  |
| `skills/structuring-documentation/references/splitting.md`           | `CLAUDE.md`                              |
| `skills/structuring-documentation/scripts/measure.sh`                | `CHANGELOG.md`                           |

## Tests

Tests live in `plugin-tests/shopware-documentation/`: `measure_cli.bats`, `measure_size.bats`, `measure_links.bats`, plus fixtures under `fixtures/`. Run via `.bats/bats-core/bin/bats plugin-tests/shopware-documentation/*.bats` from the repo root.

## Version Sync

`plugin.json` version, the `structuring-documentation` skill's `SKILL.md` frontmatter version, and the latest `CHANGELOG.md` entry stay in lockstep. Bump all three together; see the `plugin-updating` skill.
