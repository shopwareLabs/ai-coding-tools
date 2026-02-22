# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.7.0] - 2026-02-22

### Added
- **`commit_pulls` tool** - Lists GitHub pull requests associated with a pushed commit SHA. GitHub-only; no local git equivalent. Returns PR number, title, URL, and state by default. Supports `jq_filter`, `suppress_errors`, and `fallback` parameters.
- **`gh-tooling` server scope statement** - `instructions` now explicitly states that all tools require GitHub network connectivity and are not a replacement for local git commands. `git show`, `git log`, `git diff` etc. should be used via Bash for local operations.

### Removed
- **`commit_info` tool** - Removed because its primary use case (changed files list, commit message) is fully covered by `git show <sha>` locally. The only GitHub-exclusive feature (associated PR lookup) is now available via the focused `commit_pulls` tool. This prevents the model from incorrectly reaching for a GitHub API call when a local git command suffices.

### Changed
- Hook (`check-gh-tools.sh`): bare `commits/SHA` endpoint is no longer blocked (no MCP tool covers it; use `git show` locally). The `commits/SHA/pulls` pattern now redirects to `commit_pulls`.

## [2.6.0] - 2026-02-22

### Added
- **`coverage_path` parameter for `phpunit_run`** - Specify a custom output path for the coverage report file or directory. Defaults: `clover`/`cobertura` → `coverage.xml`, `html` → `coverage/`. Not applicable for `text` format.

### Changed
- **File-based coverage formats always emit a text summary** - When `coverage_format` is `clover`, `cobertura`, or `html`, PHPUnit now also runs `--coverage-text` in the same invocation so the MCP response always includes a human-readable coverage summary alongside the file output.

## [2.5.1] - 2026-02-22

### Changed
- `coverage_format` parameter description for `phpunit_run` now clarifies that `clover` is required to identify which specific lines are not covered (per-line XML with hit counts), `html` provides a visual line-by-line report, and `text` only provides aggregate percentages

## [2.5.0] - 2026-02-21

### Added
- **`suppress_errors` parameter** (all 19 gh-tooling tools) - Set to `true` to discard stderr; the tool returns empty output instead of an error message. Useful when a resource may not exist.
- **`fallback` parameter** (all 19 gh-tooling tools) - Text to return (with exit 0) when the gh command fails. Combine with `suppress_errors` for clean "not found" handling.
- **`jq_filter` parameter** (7 new tools: `pr_view`, `pr_list`, `issue_view`, `issue_list`, `run_view`, `run_list`, `search`) - jq expression applied as post-processing. Syntax is validated before execution.
- **jq syntax validation** on all existing `jq_filter` parameters (`pr_comments`, `pr_reviews`, `pr_files`, `pr_commits`, `job_view`, `job_annotations`, `commit_info`, `api`) - compile errors are caught and reported before the gh command runs.
- **`max_lines` parameter** (`pr_view`, `pr_diff`, `pr_checks`, `pr_comments`, `pr_reviews`, `issue_view`, `api`) - Return only the first N lines of output.
- **`tail_lines` parameter** (`pr_diff`, `run_logs`, `job_logs`, `api`) - Return only the last N lines of output.
- **Grep parameters** (`pr_diff`, `run_logs`, `job_logs`): `grep_pattern` (extended regex filter), `grep_context_before`/`grep_context_after` (context lines), `grep_ignore_case`, `grep_invert`.
- **`_gh_validate_jq_filter()` helper** in `lib/common.sh` - validates jq syntax using `jq -n`; only rejects compile/parse/lexical errors, not runtime errors on null input.
- **`_gh_post_process()` helper** in `lib/common.sh` - applies jq → grep → head → tail pipeline steps in order; each step is a no-op when its parameter is empty/zero.
- **30 new BATS tests** in `plugin-tests/dev-tooling/mcp_tool_gh.bats` covering all new parameters and both helper functions.

### Changed
- `run_logs` and `job_logs`: refactored from piped `head` to `_gh_post_process` for consistent pipeline handling.
- All 19 gh-tooling tools: replaced bare `"${cmd[@]}" 2>&1` with structured execution block that captures exit code before branching on `suppress_errors`/`fallback`.

## [2.4.0] - 2026-02-21

### Added
- **`gh-tooling` MCP server** - GitHub CLI wrapper with 19 tools for repository operations:
  - **PR tools**: `pr_view`, `pr_diff`, `pr_list`, `pr_checks`, `pr_comments`, `pr_reviews`, `pr_files`, `pr_commits`
  - **Issue tools**: `issue_view`, `issue_list`
  - **CI/Actions tools**: `run_view`, `run_list`, `run_logs`, `job_view`, `job_logs`, `job_annotations`
  - **Commit tools**: `commit_info`
  - **Search tools**: `search`
  - **API escape hatch**: `api` for raw GitHub REST API calls
- Optional configuration via `.mcp-gh-tooling.json` (default repo, hook enforcement toggle)
- Array-based command execution for injection-safe argument passing
- `max_lines` parameter on log tools to truncate large CI log output

## [2.3.0] - 2026-02-18

### Added
- **`coverage_driver` parameter for `phpunit_run`** - Controls which coverage driver is activated at runtime
  - `xdebug` - Prepends `XDEBUG_MODE=coverage` to the PHPUnit command (required for Xdebug 3, which has coverage mode off by default)
  - `pcov` - No env var injection; requires pcov extension loaded in php.ini
  - Omit to rely on PHPUnit's own driver detection (backward-compatible default)
- **`phpunit.coverage_driver` config option** - Set a project-wide default driver in `.mcp-php-tooling.json`; overridable per tool call
- `XDEBUG_MODE=coverage` injection works across all environments (native, Docker, Vagrant, DDEV) without changes to the environment wrapper

## [2.2.0] - 2026-01-08

### Added
- **Shopware LSP** integration via `.lsp.json` - service ID completion, Twig templates, snippets, routes, feature flags
- Requires manual `shopware-lsp` binary installation from [GitHub releases](https://github.com/shopwareLabs/shopware-lsp/releases)

## [2.1.0] - 2025-12-19

### Added
- **PreToolUse hooks** to enforce MCP tool usage instead of direct bash commands:
  - `check-php-tools.sh` - Blocks PHPStan, ECS, PHPUnit, bin/console commands
  - `check-js-admin-tools.sh` - Blocks Administration npm/npx commands
  - `check-js-storefront-tools.sh` - Blocks Storefront npm/npx commands
- Shared hook library (`hooks/scripts/lib/common.sh`) with `parse_hook_input()`, `load_mcp_config()`, `block_tool()`
- `enforce_mcp_tools` configuration option (default: true) to disable hook enforcement
- BATS test suite in `plugin-tests/code-quality/dev-tooling/`

## [2.0.0] - 2025-12-18

### Added
- **js-admin-tooling MCP server** - Administration JavaScript tools:
  - `eslint_check`, `eslint_fix` - ESLint linting
  - `stylelint_check`, `stylelint_fix` - SCSS linting
  - `prettier_check`, `prettier_fix` - Code formatting
  - `jest_run` - Unit testing
  - `tsc_check` - TypeScript type checking
  - `lint_all` - Run all lint checks in one command
  - `lint_twig` - ESLint for Twig templates
  - `unit_setup` - Regenerate Jest import resolver
  - `vite_build` - Build with Vite
- **js-storefront-tooling MCP server** - Storefront JavaScript tools:
  - `eslint_check`, `eslint_fix` - ESLint linting
  - `stylelint_check`, `stylelint_fix` - SCSS linting
  - `jest_run` - Unit testing
  - `webpack_build` - Build with Webpack
- Shared configuration via `.mcp-js-tooling.json` for both JS servers

### Changed
- **BREAKING**: Plugin renamed from `php-tooling` to `dev-tooling`

### Migration

1. Uninstall: `/plugin uninstall php-tooling@shopware-plugins`
2. Install: `/plugin install dev-tooling@shopware-plugins`
3. Restart Claude Code
4. PHP tools work unchanged with existing `.mcp-php-tooling.json`
5. For JS tools: Create `.mcp-js-tooling.json` with environment configuration

## [1.5.0] - 2025-12-17

### Added
- Config discovery in popular LLM coding tool directories:
  - `.aiassistant/` (JetBrains AI Assistant)
  - `.amazonq/` (Amazon Q Developer)
  - `.cline/` (Cline / Claude Dev)
  - `.cursor/` (Cursor AI)
  - `.kiro/` (Kiro - Amazon Q CLI successor)
  - `.windsurf/` (Windsurf / Codeium)
  - `.zed/` (Zed editor)
- Cross-tool configuration sharing via deep-merge support

### Changed
- Improved error messages to list all supported config directories
- Config locations ordered alphabetically for deterministic merge behavior

## [1.4.0] - 2025-12-17

### Added
- `console_run` tool - Execute any Symfony console command with arguments and options
- `console_list` tool - List available console commands with namespace filtering
- Support for Symfony global options: env, verbosity, no_debug, no_interaction
- Flexible options handling: boolean flags, string values, and arrays
- Console configuration section in `.mcp-php-tooling.json`

## [1.3.1] - 2025-12-17

### Fixed
- Added missing `lib/config.sh` library file that was not included in 1.3.0 release

## [1.3.0] - 2025-12-16

### Added
- `MCP_PHP_TOOLING_CONFIG` environment variable for config path override
- Config discovery with deep merging (`.mcp-php-tooling.json` + `.claude/.mcp-php-tooling.json`)
- Extensible `CONFIG_LOCATIONS` array in new `lib/config.sh` module

### Changed
- Consolidated into single plugin (removed separate `php-tooling-mcp-config-location-*` plugins)
- Replaced `--config` argument with environment variable and auto-discovery

### Migration
Uninstall `php-tooling-mcp-config-location-*` plugins, update php-tooling, restart Claude Code.

## [1.2.0] - 2025-12-16

### Changed
- Split MCP server configuration into separate location-based plugins
- Removed `.mcp.json` from main plugin (requires separate config plugin to activate)
- Added `php-tooling-mcp-config-location-root` plugin (config at project root)
- Added `php-tooling-mcp-config-location-dotclaude` plugin (config in `.claude/` directory)

## [1.1.0] - 2025-12-16

### Changed
- **BREAKING**: Renamed configuration file from `.lintrc.local.json` to `.mcp-php-tooling.json`
- Added `--config` argument to override config file path

## [1.0.0] - 2025-12-15

### Added
- PHPStan static analysis tool (`phpstan_analyze`)
- ECS code style checking tool (`ecs_check`)
- ECS code style fixing tool (`ecs_fix`)
- PHPUnit test runner tool (`phpunit_run`)
- Multi-environment support: native, docker, vagrant, ddev
- Auto-detection of development environment from project files
- Configuration via `.lintrc.local.json` file
- Bash-based MCP server implementation (minimal dependencies)
