@README.md

## Directory Structure

```
plugins/code-contribution-analysis/
├── .claude-plugin/
│   └── plugin.json               # Plugin manifest (name, version, metadata)
├── README.md                     # User documentation
├── AGENTS.md                     # LLM navigation guide (this file)
├── CLAUDE.md                     # Points to AGENTS.md
├── CHANGELOG.md                  # Version history
└── skills/
    ├── pr-analyzing/
    │   └── SKILL.md              # PR analysis skill
    └── issue-analyzing/
        └── SKILL.md              # Issue analysis skill
```

## Component Overview

This plugin contains **only skills**. No MCP servers, no hooks, no commands, no agents, no executable code.

The skills depend on one companion plugin and one capability:

| Dependency                | Provides                                                      | Required? |
|---------------------------|---------------------------------------------------------------|-----------|
| `chunkhound-integration`  | `code_research` MCP tool for semantic architectural research  | Yes (hard requirement — skill errors out if absent) |
| GitHub access (any)       | PR/issue fetching — GitHub MCP server, `gh` CLI, or API calls | Yes (no specific tool required) |

The skills deliberately do not name a specific GitHub tool. They describe the fetch operations and let the model use whatever GitHub access is configured in the session.

## Key Navigation Points

| Task                                              | File                                                    |
|---------------------------------------------------|---------------------------------------------------------|
| Change PR fetch sequence or tools                 | `skills/pr-analyzing/SKILL.md` → "Step 1" section       |
| Change PR research strategy                       | `skills/pr-analyzing/SKILL.md` → "Step 3" section       |
| Change PR output structure                        | `skills/pr-analyzing/SKILL.md` → "Output Structure"     |
| Change issue fetch sequence                       | `skills/issue-analyzing/SKILL.md` → "Step 1" section    |
| Change issue research strategy                    | `skills/issue-analyzing/SKILL.md` → "Step 3" section    |
| Change issue output structure                     | `skills/issue-analyzing/SKILL.md` → "Output Structure"  |
| Update activation triggers                        | Skill frontmatter `description` field                   |
| Change error handling behavior                    | Skill "Errors" section                                  |

## Design Philosophy

1. **Pure skills, no runtime code** — The plugin contains only instruction files. All tool execution happens via MCP from companion plugins.

2. **Standalone and embeddable** — The skills work identically whether invoked by a human in a Claude Code session or by a Claude Agent SDK application loading the plugin programmatically. There is no split between "interactive mode" and "batch mode."

3. **Incremental research** — ChunkHound queries are expensive. The skills use a staged approach (Stage 1 → Stage 2 → Stage 3) and proceed only when prior stages' findings are insufficient. This keeps simple analyses fast and deep analyses focused.

4. **Hard dependency on research** — Missing `chunkhound-integration` is a hard stop. Architectural research is the substantive part of the output, not an optional layer; without it, the skill would produce something that looks like analysis but silently omits the most valuable section. The skill refuses rather than degrades. Missing GitHub access is also a hard stop, since there is nothing to analyze without the contribution data.

5. **Output is conversation text** — Skills do not write files, mutate state, or invoke other skills. They return structured analysis as conversation text and let the caller decide what to do with it.

## Why Two Skills Instead of One

PRs and issues differ fundamentally in what they contain:

- **PRs have a diff** — the analysis anchors on changed code and traces architectural relationships outward
- **Issues have a problem description** — the analysis anchors on identifying the affected code area before researching it

The tool usage patterns (GitHub for data, ChunkHound for research) and output structure are shared, but the research strategy diverges enough that splitting into two skills keeps each one focused. A single "contribution-analyzing" skill would have two large branches that share little in practice.

## Integration Points

### From Claude Code Sessions

Users invoke the skills implicitly by asking natural-language questions that match the activation triggers in each skill's frontmatter `description`. No slash commands, no explicit invocation.

### From Claude Agent SDK Applications

Applications load the plugin via the Agent SDK `plugins` option along with the companion plugins. Claude autonomously invokes the skills when the prompt references a PR or issue number. See the README for a code example.

## External Dependencies

- **chunkhound-integration plugin** (required runtime dependency) — installed separately
- **ChunkHound index** — required; built and maintained by the user via ChunkHound's own tooling
- **GitHub access** — any available method (MCP server, `gh` CLI, API calls). Not a plugin dependency.
