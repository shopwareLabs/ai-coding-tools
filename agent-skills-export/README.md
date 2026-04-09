# Agent Skills Export

Build [Agent Skills](https://agentskills.io)-compliant ZIP packages from Claude Code skills. Transforms SKILL.md frontmatter, enriches metadata from plugin.json, validates against the spec, and produces portable ZIPs usable in Cursor, Codex, Gemini, and other compatible tools.

## ⚡ Quick Start

```bash
# From the repo root
make build-skill SKILL=plugins/contributor-writing/skills/adr-writing
make build-skills   # all opted-in skills
```

ZIPs are written to `agent-skills-export/dist/`.

## 🔬 How It Works

Skills opt in for export by placing an empty `.agent-skills` marker file next to their `SKILL.md`. The build tool then:

1. **Strips** non-spec frontmatter fields (`version`, `model`, `allowed-tools`)
2. **Enriches** with plugin metadata (`metadata.version`, `metadata.author`, `license` from `plugin.json`)
3. **Validates** against the Agent Skills spec using [skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref)
4. **Packages** the skill directory as a ZIP

## 🖥️ CLI Usage

```
$ build-agent-skill --help
Usage: build-agent-skill [OPTIONS] SKILL_DIR [OUTPUT_DIR]

  Build an Agent Skills-compliant ZIP from a Claude Code skill.

Arguments:
  SKILL_DIR   Path to the skill directory containing SKILL.md  [required]
  OUTPUT_DIR  Output directory for the ZIP [default: current directory]
```

Run from the repo root without installing:

```bash
uv run --project agent-skills-export build-agent-skill <skill-dir> [output-dir]
```

## 🏗️ Development

```bash
cd agent-skills-export
uv sync --extra dev
```

From the repo root:

```bash
make check       # lint + typecheck + test
make test        # tests only
make lint        # ruff check + format
make typecheck   # mypy strict
```

## ⚖️ License

MIT
