@README.md

## Directory Structure

```
plugins/ci-failure-interpretation/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── ci-log-interpretation/
│       ├── SKILL.md                     # Core: tool identification, noise rules, reporting
│       └── references/
│           ├── php-tools.md             # PHPUnit, PHPStan, ECS failure anatomy
│           ├── js-tools.md              # ESLint, tsc, Stylelint, Prettier, Jest failure anatomy
│           ├── e2e-tools.md             # Playwright, Lighthouse, ludtwig failure anatomy
│           └── log-envelope.md          # GitHub Actions log format, noise layers
├── README.md
├── AGENTS.md                            # This file
├── CLAUDE.md
└── CHANGELOG.md
```

## When to Modify

| Task | File |
|------|------|
| Add/change tool identification rules | `skills/ci-log-interpretation/SKILL.md` |
| Add/change noise filtering rules | `skills/ci-log-interpretation/SKILL.md` |
| Change reporting format | `skills/ci-log-interpretation/SKILL.md` |
| Update PHP tool knowledge | `skills/.../references/php-tools.md` |
| Update JS tool knowledge | `skills/.../references/js-tools.md` |
| Update E2E tool knowledge | `skills/.../references/e2e-tools.md` |
| Update log format knowledge | `skills/.../references/log-envelope.md` |

## Design Philosophy

1. **Pure knowledge, not workflow** — The skill teaches Claude how to read logs, it does not prescribe a debugging workflow or guide tool usage
2. **Progressive disclosure** — Core identification and noise rules inline in SKILL.md, detailed tool anatomy in reference files loaded on demand
3. **False positive focus** — Each tool section explicitly lists what looks like an error but isn't, since these are the most common misinterpretation traps
4. **Real examples** — All failure patterns come from actual Shopware CI runs, not hypothetical output
