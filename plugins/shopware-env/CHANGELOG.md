# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1] - 2026-07-13

### Changed
- The `dev-environment-bootstrapping` Phase 5 handoff message and README §Integration now point users to `github-mcp@github-agent-tools` for GitHub tooling instead of the retired `gh-tooling@shopware-ai-coding-tools` — the GitHub tooling moved to the standalone `github-agent-tools` marketplace.

## [1.2.0] - 2026-06-25

### Added
- Tool-call arguments are now validated against the called tool's declared `inputSchema` before dispatch. Every field listed in `required` must be present, and when the schema sets `additionalProperties: false` any field outside `properties` is rejected — the call returns an `isError` result naming the missing or unknown parameters instead of running the tool. Applies to the `lifecycle-tooling` server; tools without a schema are left unvalidated. Added as `validate_tool_arguments` in the shared `mcpserver_core.sh` (kept byte-identical to the `templates/mcp-shared/` source).

## [1.1.1] - 2026-05-13

### Changed
- `dev-environment-bootstrapping` description rewritten to follow https://agentskills.io/skill-creation/optimizing-descriptions: leads with imperative "Use this skill when..." and lists explicit trigger phrases drawn from the README ("set up a Shopware dev environment", "clone and install Shopware", "bootstrap Shopware and a new plugin called X", etc.). No behavior change.

## [1.1.0] - 2026-04-21

### Added
- `install_dependencies` MCP tool now accepts an `update` boolean (default `false`). When `true`, runs `composer update` instead of `composer install`, and passes `install` instead of `clean-install` to the npm:admin / npm:storefront composer scripts. Use after bumping versions in `composer.json` or `package.json` to regenerate lockfiles. Applies to whichever of `composer`, `administration`, `storefront` are enabled.

### Changed
- `install_dependencies` no longer auto-detects install-vs-update from `composer.lock` presence. The default is always `composer install` / npm `clean-install`; updates are opt-in via the new `update` flag. `composer install` on a fresh clone (no lockfile) emits a warning and proceeds to generate one, matching Shopware's own CI setup.

## [1.0.1] - 2026-04-19

### Changed
- Internal shellcheck cleanup. No behavior change. In `shared/mcpserver_core.sh`, the `log()` function now splits `local line` from its assignment so the `local` builtin no longer masks `date`'s exit status (SC2155). In `shared/environment.sh`, obsolete inline shellcheck directives (SC2154 / SC2034) were removed now that the repo-level `.shellcheckrc` covers them.

## [1.0.0] - 2026-04-18

### Added
- MCP server `lifecycle-tooling` with 8 tools: `install_dependencies`, `database_install`, `database_reset`, `testdb_prepare`, `frontend_build_admin`, `frontend_build_storefront`, `plugin_create`, `plugin_setup`
- `dev-environment-bootstrapping` skill for first-run setup orchestration
- SessionStart hook with lifecycle tool directives
- PreToolUse hook enforcing MCP tools over bash equivalents
- Reads dev-tooling's `.mcp-php-tooling.json` as optional config fallback
