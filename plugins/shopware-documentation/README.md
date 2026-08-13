# Shopware Documentation

Structuring skill for Markdown documentation surfaces in Shopware repositories. Keeps every `README.md`, `AGENTS.md`, `CLAUDE.md`, and `docs/` sibling at one subject, one content class, and a bounded amount of reading — measured, not estimated.

## 📦 Installation

```bash
/plugin install shopware-documentation@shopware-ai-coding-tools
```

## ⚡ Quick Start

The `structuring-documentation` skill activates automatically when documentation surfaces are written, audited, or split:

```
Is this README too long?
Split src/Core/Framework/ContentSystem/README.md
Measure the docs under src/Storefront/ContentSystem
Where does this documentation belong?
```

## 🗜️ Measurement Script

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/measure.sh" <size|links|all> [flags] PATH...
```

`${CLAUDE_SKILL_DIR}` resolves to the installed skill's directory at runtime; when running the script by hand, substitute the path to `skills/structuring-documentation` yourself.

| Mode    | Reports                                                                                                                                                                                                          |
|---------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `size`  | counted characters, raw characters, routing rows, and a budget verdict per surface                                                                                                                               |
| `links` | every relative Markdown cross-reference and anchor resolved from the citing file's position (web and mail links [http, https, mailto] and non-`.md` targets skipped by design), plus backticked bare `.md` paths |
| `all`   | both                                                                                                                                                                                                             |

| Flag                 | Effect                                                   |
|----------------------|----------------------------------------------------------|
| `--goal N`           | at-goal budget, default 5000 counted characters          |
| `--limit N`          | allowed budget, default 6500                             |
| `--ceiling N`        | never-ships budget, default 10000                        |
| `--max-index-rows N` | routing rows an index may carry, default 20              |
| `--strict`           | exit 1 on any finding instead of reporting and exiting 0 |

> [!NOTE]
> The script has no default scope. Every invocation names the paths to measure.

## 🎛️ Scope and Budget Overrides

Scope is supplied per invocation: the paths named in the request, or the documentation files the current change touches. When no scope is stated, the skill asks instead of assuming one.

Budgets are named values — `docs.size_goal`, `docs.size_limit`, `docs.size_ceiling`, `docs.max_index_rows` — that a project or a user instruction may assign. Assigned values are passed to the script as `--goal`, `--limit`, `--ceiling`, and `--max-index-rows`; unassigned, the script's built-in defaults apply. A project may also supply its own subject-ownership table, which the skill consults wherever ownership decides where a fact lives.

## 📚 Documentation

- **Core skill**: [skills/structuring-documentation/SKILL.md](skills/structuring-documentation/SKILL.md)
- **Surface contract**: [skills/structuring-documentation/references/surface-contract.md](skills/structuring-documentation/references/surface-contract.md)
- **Splitting procedure**: [skills/structuring-documentation/references/splitting.md](skills/structuring-documentation/references/splitting.md)

## ⚖️ License

MIT
