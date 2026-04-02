# Scope Detection

Determine scope from file paths for the Shopware AI Coding Tools marketplace.

## Scope Categories

### Plugin Scopes (from `plugins/` directory)

The primary scope source. Run `ls plugins/` for the current list. Each plugin directory name is a valid scope.

Path mapping:
- `plugins/<name>/**` → scope = `<name>`
- Example: `plugins/dev-tooling/mcp-server/php/server.sh` → `dev-tooling`
- Example: `plugins/test-writing/skills/phpunit-unit-test-writing/SKILL.md` → `test-writing`

### Infrastructure Scopes

| Scope | Files |
|-------|-------|
| `hooks` | `hooks/`, plugin hook directories, hooks.json files |
| `marketplace` | `.claude-plugin/marketplace.json`, plugin.json files across plugins |
| `ci` | `.github/workflows/`, `.github/scripts/` |
| `github` | `.github/ISSUE_TEMPLATE/`, `.github/*.md` |

### Omit Scope When

- Root docs only: README.md, CONTRIBUTING.md, AGENTS.md, LICENSE → `docs: ...`
- Root configs only: pyproject.toml, uv.lock, .gitignore → `chore: ...` or `build: ...`
- Cross-cutting changes spanning 3+ unrelated plugins
- Type is `ci` with only generic CI changes (not plugin-specific workflows)

## Confidence Levels

**HIGH**: All files under a single `plugins/<name>/` directory
- `plugins/gh-tooling/mcp-server/server.sh`, `plugins/gh-tooling/README.md` → `gh-tooling`

**MEDIUM**: Files span a plugin directory and related infrastructure
- `plugins/dev-tooling/hooks/hooks.json`, `.github/workflows/test-hooks.yml` → `dev-tooling`

**LOW**: Files across multiple unrelated plugins → ask user
- `plugins/dev-tooling/...`, `plugins/gh-tooling/...`, `plugins/test-writing/...`

## Special Cases

**New plugin commit**: scope = new plugin name, even though marketplace.json and README.md also change (those are incidental).

**Plugin merge**: when one plugin is merged into another (e.g., adr-writing → contributor-writing), scope = target plugin name.

**Hooks spanning plugins**: if SessionStart hooks added to multiple plugins, scope = `hooks` (the cross-cutting concern).

**BATS tests**: scope = the plugin being tested, derived from `plugin-tests/<plugin-name>/`.
