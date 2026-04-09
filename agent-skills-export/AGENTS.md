# Agent Skills Export — Technical Reference

Python CLI tool that transforms Claude Code skills into portable ZIP packages following the [Agent Skills](https://agentskills.io) specification.

## Project Structure

```
agent-skills-export/
├── pyproject.toml                    # Package config, tooling, dependencies
├── Makefile                          # → repo root Makefile delegates here
├── src/
│   └── agent_skills_export/
│       ├── __init__.py               # Public API exports
│       ├── __main__.py               # python -m entry point
│       ├── cli.py                    # Typer CLI (build-agent-skill command)
│       └── core.py                   # All build logic
└── tests/
    ├── conftest.py                   # Shared fixtures
    ├── test_parse.py                 # Frontmatter parsing/serialization
    ├── test_discover.py              # plugin.json discovery
    ├── test_transform.py             # Frontmatter transformation
    ├── test_exclude.py               # File exclusion patterns
    └── test_build.py                 # End-to-end build + CLI
```

## Module Responsibilities

| Module | Responsibility |
|--------|---------------|
| `core.py` | Parsing, transformation, exclusion, ZIP creation, validation |
| `cli.py` | Typer app wrapping `core.build_skill` and `core.validate_skill` |
| `__init__.py` | Re-exports public functions from `core.py` |

## Build Pipeline (core.py)

1. Parse `SKILL.md` frontmatter with PyYAML
2. Walk up to find nearest `.claude-plugin/plugin.json`
3. Strip non-spec fields (`version`, `model`, `allowed-tools`)
4. Enrich from plugin.json (`metadata.version`, `metadata.author`, `license`)
5. Rewrite SKILL.md with transformed frontmatter + original body
6. Copy other files, excluding junk (`.DS_Store`, `__pycache__/`, IDE files, etc.)
7. Validate with `skills-ref` (optional, skipped if not installed)
8. Create ZIP as `{skill-name}/{contents}`

## Development

```bash
# Install dev dependencies
cd agent-skills-export
uv sync --extra dev

# Run all checks
make check           # from repo root
uv run ruff check src/ tests/
uv run ruff format --check src/ tests/
uv run mypy src/
uv run pytest
```

## When to Modify

| Task | File |
|------|------|
| Change which frontmatter fields are stripped/preserved | `core.py` → `SPEC_FIELDS` |
| Change which files are excluded from ZIPs | `core.py` → `EXCLUDED_NAMES`, `EXCLUDED_EXTENSIONS` |
| Change how plugin.json data maps to frontmatter | `core.py` → `transform_frontmatter()` |
| Change CLI arguments or behavior | `cli.py` |
| Change validation behavior | `core.py` → `validate_skill()` |
| Add a new exclusion pattern | `core.py` constants + `tests/test_exclude.py` parametrize list |

## Dependencies

- **Runtime:** `pyyaml`, `typer`
- **Optional:** `skills-ref` (for validation, via `[validate]` extra)
- **Dev:** `ruff`, `mypy`, `pytest`, `types-pyyaml`

## Tooling

- **Linter/formatter:** ruff (strict rule set, 100 char line length)
- **Type checker:** mypy (strict mode, relaxed for tests)
- **Tests:** pytest (47 tests, parametrized)
- **Build backend:** hatchling (src layout)
- **Package manager:** uv
