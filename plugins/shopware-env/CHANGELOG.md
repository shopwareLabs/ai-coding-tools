# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
