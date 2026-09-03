## Named-value assignments

- `docs.surfaces` =
  | Surface | Owns | Shape | Single-owner |
  |---|---|---|---|
  | `README.md` | Marketplace pitch, quick start, the plugin index, third-party-integration and license notices | Emoji-prefixed H2s; one `### <plugin>` per plugin with install command, scope, prerequisites, and a link to the plugin README | enforced |
  | `AGENTS.md` | Project jargon; marketplace architecture; the `marketplace.json` and `plugin.json` schemas; plugin component types; the runtime-file vs developer-documentation split; the add-a-plugin workflow; testing and validation commands | `@README.md` first line, then H2 sections | enforced |
  | `SECURITY.md` | Vulnerability reporting | GitHub default | enforced |
  | `docs/claude-code-setup.md` | The recommended Claude Code configuration recipe | Numbered emoji H2s, prose plus config blocks | enforced |
  | `docs/rules/README.md` | The index of the published rule-file catalog and the rule-vs-skill decision test | Emoji-prefixed H2s plus the catalog tables | enforced |
  | `docs/rules/<rule>.md` | One behavioral rule each, self-contained for copying into `~/.claude/rules/` | Decision Test, Core Rules, Banned Patterns, Red Flags | enforced |
  | `templates/README.md` | The template-to-consumer mapping, the sync procedure, and what is deliberately not templated | H2 per topic plus a Directories table | enforced |
  | `plugin-tests/README.md` | BATS setup and run commands, the tag vocabulary, the helper and test skeletons, the test-tree layout | Emoji-prefixed H2s | enforced |
  | `plugin-tests/AGENTS.md` | LLM navigation for the test tree: helper contracts, `REPO_ROOT` resolution, hook exit codes, when-to-modify routing | `@README.md` plus H2 sections | enforced |
  | `.github/scripts/README.md` | Each maintenance script's usage, flags, and exit codes, plus the library function lists | Emoji-prefixed H2s, one H3 per script | enforced |
  | `.github/scripts/AGENTS.md` | The validate-vs-update two-script architecture and modification guidance for that tree | `@README.md` plus H2 sections | enforced |
  | `plugins/<name>/README.md` | User documentation for one plugin: features, install, quick start, tool reference, configuration | Emoji-prefixed H2s | enforced |
  | `plugins/<name>/AGENTS.md` | LLM navigation for one plugin: directory tree, component responsibilities, when-to-modify routing | Usually `@README.md` plus H2 sections; `contributor-writing` and `shopware-documentation` open with a heading or blockquote pointer instead, deliberately | enforced |
  | `plugins/<name>/docs/<concern>.md` | One concern split out of a plugin README once it outgrew it | Prose plus tables | enforced |
  | `agent-skills-export/README.md` | User documentation for the export CLI | Emoji-prefixed H2s | enforced |
  | `agent-skills-export/AGENTS.md` | LLM navigation for the export package: module responsibilities, build pipeline, when-to-modify routing | H2 sections | enforced |
  | `plugins/<name>/CHANGELOG.md`, `agent-skills-export/CHANGELOG.md` | The per-version record of what changed | Keep a Changelog: `## [X.Y.Z] - YYYY-MM-DD` with `### Added` / `### Changed` / `### Fixed` | exempt — a version entry necessarily restates the change the target surfaces now describe as current behavior |
  | `plugins/<name>/SETUP.md` | The interactive setup walkthrough for one plugin | Numbered steps | exempt — synced byte-identical into its `plugin-setup` consumer |
  | `plugins/plugin-setup/skills/<plugin>-setting-up/references/plugin-setup.md` | Nothing of its own | Byte-identical copy of the plugin's `SETUP.md` | exempt — the duplication is the distribution mechanism, enforced by the template-sync check |

  `CLAUDE.md` files are untracked local working files in this repository, not documentation surfaces. Never create, edit, or cite one.
- `docs.pointer_file` = `AGENTS.md`. It is the only committed pointer convention, and it carries LLM navigation for its directory. Most tracked `AGENTS.md` open with a literal `@README.md` line, but three do not — `agent-skills-export/`, `plugins/contributor-writing/`, and `plugins/shopware-documentation/` open with a heading or a prose blockquote pointing at `README.md` instead. Those are existing choices, not drift: do not rewrite an `AGENTS.md` opener to match the majority, and add `@README.md` only to a file being created. `CLAUDE.md` is untracked here — the companion-file rule does not apply, and the pointer branch never produces or edits a `CLAUDE.md`.
- `docs.jargon_home` = `AGENTS.md` (repository root). It defines marketplace, plugin, skill, agent, slash command, hook, MCP server, and the runtime-file vs developer-documentation split. No other surface re-defines them.
- `docs.changelog` = `plugins/<name>/CHANGELOG.md` and `agent-skills-export/CHANGELOG.md`, Keep a Changelog with Semantic Versioning, entries headed `## [X.Y.Z] - YYYY-MM-DD`. A plugin's changelog version must match its `.claude-plugin/plugin.json` and the `version` frontmatter of every SKILL.md in that plugin; `.github/scripts/validate-versions.sh` enforces this and runs in `.github/workflows/validate.yml`. Read `.github/scripts/README.md` §validate-versions.sh before changing a version anywhere. Never bump a version that was not explicitly asked for.
- `docs.diagrams` = A fenced ASCII directory tree is the house form whenever the subject is file or directory layout; every `AGENTS.md` uses one. Otherwise table-first: add a diagram only when a table cannot express the relationship.

## Pre-Step-1

Classify the file before naming a surface. Only developer documentation is in scope; read `AGENTS.md` §Understanding Developer Documentation for the split this repository draws.

STOP and use the owning authoring workflow when the path matches runtime instruction content — Markdown that Claude Code reads and executes, not documentation: `plugins/*/skills/**`, `plugins/*/agents/*.md`, `plugins/*/commands/*.md`, `plugins/*/hooks/prompts/*.md`, `plugins/*/references/*.md`, `plugins/*/rules/**`, `templates/plugin-setup/SKILL.md`, `.claude/skills/**`, `.claude/rules/*.md`, `.claude/hook-contexts/*.md`.

STOP when the path is test data: `plugin-tests/**/fixtures/**`. That content is fixed by the assertions that read it.

STOP when the path is an untracked working document: `docs/superpowers/plans/**`, `docs/superpowers/specs/**`.

## Post-Step-5

Two cross-surface checks this repository adds.

When the edit touched a plugin's `SETUP.md`, copy it to its consumer under `plugins/plugin-setup/skills/<plugin>-setting-up/references/plugin-setup.md` in the same change — the template-sync step in `.github/workflows/validate.yml` requires the two byte-identical.

When the edit added or removed a plugin, skill, agent, or slash command, run `.github/scripts/update-issue-templates.sh`. The issue-template dropdowns are generated from the tree, and `validate-issue-templates.sh` fails the build when they lag; read `.github/scripts/README.md` §update-issue-templates.sh for its behavior.
