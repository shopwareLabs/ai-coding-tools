## Pre-Step-8

Apply these project-specific type-detection rows after the universal decision tree in `references/type-detection.md`. They refine but do not replace the universal tree.

| Change | Type | Notes |
|--------|------|-------|
| New plugin added | `feat` | Scope = new plugin name |
| New skill, agent, or command in existing plugin | `feat` | Scope = plugin name |
| New MCP tool in existing server | `feat` | Scope = plugin name |
| Plugin merged, split, or renamed | `refactor` | Often breaking (`!`) |
| SKILL.md rule refinement correcting wrong behavior | `fix` | Scope = plugin name |
| SKILL.md rule addition adding new capability | `feat` | Scope = plugin name |
| Hook script fix | `fix` | Scope = plugin name or `hooks` |
| BATS test addition under `plugin-tests/<plugin>/` | `test` | Scope = plugin being tested |
| `marketplace.json` update | `chore` | Scope = `marketplace` |
| Issue template update under `.github/ISSUE_TEMPLATE/` | `chore` | Scope = `github` |
| Only `README.md`, `CONTRIBUTING.md`, or `AGENTS.md` | `docs` | Omit scope |

Project-specific breaking-change indicators (mark `!`):

- Plugin restructured (skills, agents, or commands moved or removed).
- MCP tool renamed or removed.
- MCP tool required parameters added or removed.
- Plugin directory renamed.

The following are NOT breaking:

- New skill, agent, or command added (additive).
- New MCP tool added.
- Optional parameter added to an MCP tool.
- Internal reference file changes.

## Pre-Step-9

Override the universal scope inference default with the rules below. Apply in priority order; if a rule matches, use its scope. Fall back to the universal default only if no rule matches.

Enumerate plugin names first with `ls plugins/` so the resolver knows the valid plugin-scope set.

Plugin scopes (primary):

- All files under `plugins/<name>/**` resolve to scope = `<name>`.

Infrastructure scopes:

- Files in `hooks/`, plugin hook directories, or any `hooks.json` resolve to scope = `hooks`.
- `.claude-plugin/marketplace.json` or any `plugin.json` across plugins resolves to scope = `marketplace`.
- `.github/workflows/` or `.github/scripts/` resolves to scope = `ci`.
- `.github/ISSUE_TEMPLATE/` or `.github/*.md` resolves to scope = `github`.

Scope omission:

- Root docs only (`README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `LICENSE`): omit scope.
- Root configs only (`pyproject.toml`, `uv.lock`, `.gitignore`): omit scope.
- Cross-cutting changes spanning 3 or more unrelated plugins: omit scope.
- Type is `ci` with only generic CI changes (not plugin-specific workflows): omit scope.

Special cases:

- New-plugin commit: scope = new plugin name even when `marketplace.json` and the root `README.md` also change (those are incidental).
- Plugin merge: scope = target plugin name (e.g., `adr-writing` merged into `contributor-writing` resolves to `contributor-writing`).
- Hooks added or changed across multiple plugins simultaneously: scope = `hooks`.
- BATS tests under `plugin-tests/<plugin>/`: scope = the plugin being tested.

Confidence handling:

- HIGH: all files under a single `plugins/<name>/` directory.
- MEDIUM: files span a plugin directory and related infrastructure; use the plugin scope.
- LOW: files across multiple unrelated plugins; use `AskUserQuestion` to confirm scope or omission.
