# Type Detection

Determine conventional commit type from diffs with confidence-based analysis.

## Decision Tree

Apply in priority order:

1. Reverting commit? → `revert`
2. Only docs (*.md, comments, README)? → `docs`
3. Only formatting/whitespace? → `style`
4. Only test files (plugin-tests/, *.bats)? → `test`
5. Only build/deps (pyproject.toml, uv.lock, package.json)? → `build`
6. Only CI configs (.github/workflows/, .github/scripts/)? → `ci`
7. New plugin, skill, agent, command, or MCP tool added? → `feat`
8. Fixes broken behavior in existing component? → `fix`
9. Performance improvements? → `perf`
10. Code restructuring without behavior change? → `refactor`
11. Otherwise → `chore`

## Project-Specific Type Guidance

| Change | Type | Notes |
|--------|------|-------|
| New plugin added | `feat` | Scope = new plugin name |
| New skill/agent/command in existing plugin | `feat` | Scope = plugin name |
| New MCP tool in existing server | `feat` | Scope = plugin name |
| Plugin merged/split/renamed | `refactor` | Often breaking (`!`) |
| SKILL.md rule refinement | `fix` | If correcting wrong behavior |
| SKILL.md rule addition | `feat` | If adding new capability |
| Hook script fix | `fix` | Scope = plugin or `hooks` |
| BATS test addition | `test` | Scope = plugin being tested |
| marketplace.json update | `chore` | Scope = `marketplace` |
| Issue template update | `chore` | Scope = `github` |
| README/CONTRIBUTING changes only | `docs` | Typically no scope |

## Confidence Levels

**HIGH**: Single type clearly dominates
- New SKILL.md + references/ → feat
- Only .bats files → test
- Only .github/workflows/ → ci

**MEDIUM**: Primary type clear with minor secondary changes
- New skill + updated README → feat (README is incidental)
- Bug fix + added test for the fix → fix

**LOW**: Multiple types equally valid → ask user with AskUserQuestion
- New feature + bug fix equally present
- refactor + feat ambiguous

## Breaking Change Detection

Mark as breaking (`!`) when:
- Plugin restructured (skills/agents moved or removed)
- MCP tool renamed or removed
- MCP tool parameters changed (required params added/removed)
- Hook event type changed
- Plugin directory renamed

NOT breaking:
- New skill/agent/command added (additive)
- New MCP tool added
- Optional parameter added to MCP tool
- Internal reference file changes
