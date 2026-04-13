# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.9.1] - 2026-04-13

### Fixed
- `setting-up` SKILL.md: bare-path reference to `references/plugin-setup.md` so progressive disclosure loads it correctly.

## [3.9.0] - 2026-04-10

### Added
- **Interactive setup skill** — `setting-up` skill walks users through plugin configuration: checks prerequisites (jq, optionally shopware-lsp), creates `.mcp-php-tooling.json` and optionally `.mcp-js-tooling.json` with environment-specific settings, validates the MCP server connection, and reports post-setup steps. Activates when users ask about setup or when MCP tools fail due to missing config.

## [3.8.0] - 2026-04-09

### Added
- **PostToolUse baseline check hook** — After `phpstan_analyze` runs on specific files, automatically checks whether those files have entries in the PHPStan baseline (`phpstan-baseline.neon` or `phpstan-baseline.php`). If matches are found, injects a warning into the conversation prompting the developer to verify whether the baseline entries are still needed. Prevents stale baseline entries from causing CI failures that file-scoped local runs miss. Auto-detects baseline format and file location. Skips silently for full-project runs where PHPStan validates the baseline natively.

## [3.7.0] - 2026-04-09

### Added
- **Rector refactoring tools** — `rector_fix` applies configured Rector refactorings and reports diffs; `rector_check` previews changes without applying (dry-run). Both use `composer rector` for Shopware's bootstrap integration. Parameters: `paths`, `output_format` (json/console), `config`, `only` (single rule filter), `only_suffix` (file name filter), `clear_cache`. Hook enforcement blocks `vendor/bin/rector` and `composer rector`.

### Changed
- **ECS tool descriptions updated** — `ecs_fix` is now described as the preferred tool; `ecs_check` description directs users to prefer `ecs_fix` unless a read-only preview is needed. This steers LLMs toward the more efficient fix-first workflow.

## [3.6.0] - 2026-04-03

### Added
- **Docker Compose environment type** — New `docker-compose` environment that resolves container name and working directory from Docker Compose at tool call time. Reads `compose.yaml` (including overrides) via the `docker compose` CLI. Defaults to the `web` service with auto-detected workdir from bind mounts. All resolution happens per tool call — the MCP server starts cleanly without Docker running. Configurable via optional `docker-compose.file`, `docker-compose.service`, and `docker-compose.workdir` fields. Recommended environment for `shopware/shopware` development.

## [3.5.0] - 2026-04-01

### Added
- **SessionStart hook** — Injects MCP tool usage directives into conversation context at the start of every session. Lists all available tools across the three MCP servers and instructs Claude to use them instead of bash commands. Includes sequential invocation rule per server (parallel calls across different servers are allowed). Prompt is maintained in `hooks/prompts/mcp-tool-directives.md` and output uses the JSON `additionalContext` format. Respects `enforce_mcp_tools` setting per config prefix.

## [3.4.1] - 2026-04-01

### Fixed
- **Jest `--testPathPattern` renamed to `--testPathPatterns`** - Updated the Jest flag in both admin and storefront MCP servers to use the plural form required by recent Jest versions. The tool input parameter was also renamed from `testPathPattern` to `testPathPatterns`.
- **Misleading PHPStan/ECS config examples** - Removed `phpstan.config` and `ecs.config` from the README and schema examples. These referenced filenames (`phpstan.neon`, `ecs.php`) that don't exist in Shopware. Both tools auto-discover the correct config files (`phpstan.neon.dist`, `.php-cs-fixer.dist.php`) when no explicit config is set.

## [3.4.0] - 2026-03-30

### Added
- **Environment noise filtering** - Filters known environment warnings (e.g., Xdebug Step Debug connection failures) from all PHP and JS tool output. Uses a pattern list in `shared/environment.sh` (`ENV_NOISE_PATTERNS`) that is easy to extend. Only filters noise that is never useful in MCP context — errors and failures are never affected.

### Removed
- **`result-only` output format from `phpunit_run`** - LLMs default to this "efficient" format, which suppresses individual test failure details. When output is truncated, the summary line at the end gets cut too, leaving no signal about what failed. Removing it ensures test failures are always visible in the output.

## [3.3.0] - 2026-02-26

### Added
- **`result-only` output format for `phpunit_run`** - Suppresses per-test progress dots and detailed failure output, showing only the final summary line (e.g., "OK (42 tests, 108 assertions)"). Maps to PHPUnit 10+ `--no-progress` and `--no-results` flags.

## [3.2.0] - 2026-02-24

### Added
- **`phpunit_coverage_gaps` tool** - Discover uncovered lines and methods from Clover XML coverage reports. Accepts `clover_path` (default: `coverage.xml`) and `source_filter` (path substring) parameters. Shows per-file coverage percentage, uncovered method names, and line ranges grouped into consecutive ranges (e.g., `15-17, 25`). Sorted worst coverage first. Paths displayed relative to project root. Summary includes total file count and gap count. Two-step workflow: run `phpunit_run` with `coverage_format: "clover"` first, then `phpunit_coverage_gaps`. Uses portable awk-based XML parsing (no xmllint dependency). Works across all environments (native, Docker, Vagrant, DDEV) via `exec_command`.

## [3.1.1] - 2026-02-24

### Fixed
- **Shell quoting for PHP MCP tool parameters** - Single-quote user-provided values (PHPUnit filter patterns, file paths, console arguments, and option values) when embedding them in eval'd command strings. Shell metacharacters such as `|` in PHPUnit filter patterns (`testA|testB`) were previously interpreted as pipe operators instead of being passed as literal strings.

## [3.1.0] - 2026-02-23

### Added
- **`log_file` configuration option** - Route MCP server logs to a project-local file (e.g., `.claude/mcp-debug.log`) for easier debugging. Supported by all three MCP servers (php-tooling, js-admin-tooling, js-storefront-tooling). Relative paths resolve against the project root. The default `server.log` continues to be written; the extra file is strictly additive. Invalid paths (non-existent parent directory) emit a warning and are silently skipped.

## [3.0.0] - 2026-02-23

### Removed
- **BREAKING**: `gh-tooling` MCP server extracted into standalone `gh-tooling` plugin. Install separately: `/plugin install gh-tooling@shopware-ai-coding-tools`
- **BREAKING**: `check-gh-tools.sh` PreToolUse hook moved to `gh-tooling` plugin

### Migration

1. Install the new plugin: `/plugin install gh-tooling@shopware-ai-coding-tools`
2. Restart Claude Code
3. GitHub tools (`mcp__gh-tooling__*`) work unchanged — the MCP server name is preserved
4. `.mcp-gh-tooling.json` config files require no changes

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

1. Uninstall: `/plugin uninstall php-tooling@shopware-ai-coding-tools`
2. Install: `/plugin install dev-tooling@shopware-ai-coding-tools`
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
