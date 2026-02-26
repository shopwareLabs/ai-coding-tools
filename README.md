# Shopware Claude Code Plugins

> **Experimental Community Project**: This repository is maintained by Shopware Labs and is not an official Shopware product. It is not affiliated with, endorsed by, or sponsored by Anthropic or any other AI provider. "Claude" and "Claude Code" are trademarks of Anthropic. This project is provided as-is without warranty.

Claude Code plugins for Shopware development. Supports all plugin types: commands, agents, skills, hooks, and MCP servers.

## Quick Start

For detailed information about using marketplaces, see the [official Claude Code marketplace documentation](https://docs.claude.com/en/docs/claude-code/plugins).

Add this marketplace to your Claude Code installation:

```bash
/plugin marketplace add shopwareLabs/claude-code-plugins
```

## Available Plugins

### adr-writing (v1.0.0)

Write and validate Architecture Decision Records following Shopware's ADR conventions. Encodes rules from Shopware's coding guidelines, patterns from 80+ existing ADRs, and general ADR best practices. See [documentation](./plugins/adr-writing/README.md) for details.

```bash
/plugin install adr-writing@shopware-plugins
```

**Skill:**
- `adr-creating` - Auto-invoked when creating or validating ADRs

### dev-tooling (v3.2.0)

Three MCP servers for PHP and JavaScript operations plus **Shopware LSP** for intelligent code completion. Supports native, Docker, Vagrant, and DDEV environments. See [documentation](./plugins/dev-tooling/README.md) for details.

```bash
/plugin install dev-tooling@shopware-plugins
```

**Prerequisites:**
- **Restart Claude Code** after installation (required for MCP servers)
- `jq` installed on system
- For LSP: `shopware-lsp` binary in PATH ([download](https://github.com/shopwareLabs/shopware-lsp/releases))

**Shopware LSP** (Language Server Protocol):
- Service ID completion in PHP, XML, and YAML files
- Twig template support with completion and navigation
- Snippet validation and completion
- Route name completion with parameter support
- Feature flag detection and completion

**PHP Tools** (`php-tooling` server):
- `phpstan_analyze` - PHPStan static analysis with configurable level (0-9)
- `ecs_check` / `ecs_fix` - ECS code style checking and auto-fix
- `phpunit_run` - PHPUnit test runner with suite selection, filtering, coverage
- `phpunit_coverage_gaps` - Discover uncovered lines and methods from Clover XML coverage reports
- `console_run` / `console_list` - Symfony console command execution

**Administration Tools** (`js-admin-tooling` server):
- `eslint_check` / `eslint_fix` - ESLint code quality checking and auto-fix
- `stylelint_check` / `stylelint_fix` - Stylelint SCSS/CSS checking and auto-fix
- `prettier_check` / `prettier_fix` - Prettier format checking and auto-fix
- `jest_run` - Jest test runner with filtering and coverage
- `tsc_check` - TypeScript type checking
- `lint_all` - Run all lint checks in one command
- `lint_twig` - ESLint for Twig templates
- `unit_setup` - Regenerate Jest import resolver
- `vite_build` - Build with Vite

**Storefront Tools** (`js-storefront-tooling` server):
- `eslint_check` / `eslint_fix` - ESLint code quality checking and auto-fix
- `stylelint_check` / `stylelint_fix` - Stylelint SCSS/CSS checking and auto-fix
- `jest_run` - Jest test runner with filtering and coverage
- `webpack_build` - Build with Webpack

**Configuration:**
- PHP: `.mcp-php-tooling.json`, JS: `.mcp-js-tooling.json`
- Config discovery in project root and LLM tool directories
- Supported: `.claude/`, `.cursor/`, `.windsurf/`, `.zed/`, `.cline/`, `.aiassistant/`, `.amazonq/`, `.kiro/`

**MCP Tool Enforcement:**
- PreToolUse hooks block bash commands (`vendor/bin/phpstan`, `npm run lint`, etc.) in favor of MCP tools
- Disable per-server with `"enforce_mcp_tools": false` in the respective config file

### gh-tooling (v1.1.0)

GitHub CLI MCP server for pull requests, issues, CI runs, jobs, commits, and search. Configuration-optional: works without config when `gh` is authenticated. See [documentation](./plugins/gh-tooling/README.md) for details.

```bash
/plugin install gh-tooling@shopware-plugins
```

**Prerequisites:**
- **Restart Claude Code** after installation (required for MCP server)
- `jq` installed on system
- `gh` CLI installed and authenticated (`gh auth login`)

**GitHub Tools** (`gh-tooling` server):
- `pr_view` / `pr_diff` / `pr_list` / `pr_checks` - Pull request inspection and CI status
- `pr_comments` / `pr_reviews` / `pr_files` / `pr_commits` - Detailed PR review data
- `issue_view` / `issue_list` - Issue inspection
- `run_view` / `run_list` / `run_logs` - GitHub Actions CI run status and logs
- `job_view` / `job_logs` / `job_annotations` - Job-level CI debugging
- `commit_pulls` - List PRs associated with a pushed commit SHA
- `search` - Cross-repo issue and PR search
- `api` - Raw GitHub REST API escape hatch

**Configuration:**
- Optional: `.mcp-gh-tooling.json` (default repo, hook enforcement)
- Config discovery in project root and LLM tool directories

**MCP Tool Enforcement:**
- PreToolUse hook blocks bash `gh` commands in favor of MCP tools
- Supports opt-in `gh api` blocking for endpoints with dedicated tools (`block_api_commands: true`)
- Disable with `"enforce_mcp_tools": false` in config file

### test-writing (v2.0.3)

Generate and validate PHPUnit unit tests for Shopware 6. Features split reviewer architecture with read-only analyzer and edit-capable fixer agent for improved context efficiency. Analyzes source classes, generates category-appropriate tests, reviews for compliance, and fixes issues until tests pass. See [documentation](./plugins/test-writing/README.md) for details.

```bash
/plugin install test-writing@shopware-plugins
```

**Prerequisites:**
- `dev-tooling` plugin must be installed (MCP server reference is bundled)
- `.mcp-php-tooling.json` configuration file in project root
- **Restart Claude Code** after installation (required for MCP server)

**Features:**
- Automated test generation with category detection (DTO, Service, Flow/Event, DAL, Exception)
- Split reviewer architecture: read-only reviewer for analysis, fixer agent for fix iterations (improved context efficiency)
- MCP-driven rule discovery with 46 test writing rules for Shopware testing compliance
- Oscillation detection to prevent infinite fix loops
- Bundled MCP server config with customizable path

**Skill:**
- `phpunit-unit-test-writing` - Auto-invoked when generating unit tests

### chunkhound-integration (v1.0.3)

Semantic code research using [ChunkHound's](https://chunkhound.github.io/) multi-hop search and LLM synthesis. Enables architectural understanding, component relationship discovery, and intelligent routing between semantic search and native tools. See [documentation](./plugins/chunkhound-integration/README.md) for details.

```bash
/plugin install chunkhound-integration@shopware-plugins
```

**Prerequisites:**
- ChunkHound installed (`uv tool install chunkhound`)
- `.chunkhound.json` config with embedding provider (VoyageAI, OpenAI, or Ollama)
- Index initialized (`chunkhound index` in project root)
- **Restart Claude Code** after installation (required for MCP server)

**Commands:**
- `/research <query>` - Deep code research with semantic analysis
  - Examples: `/research how does authentication work?`, `/research find all payment service dependencies`
- `/chunkhound-status` - Diagnose installation, index health, and MCP connectivity

**Skill:**
- `code-research-routing` - Auto-invoked for architectural questions, routes to ChunkHound vs native tools

**Agent:**
- `code-researcher` - Specialized agent for complex multi-file investigations

**Hook:**
- PreToolUse hook suggests ChunkHound for architectural Grep queries

## Reporting Issues

Found a bug or quality issue with a plugin? We have specialized issue templates to help you report problems effectively:

- **[🔧 Command Quality Issue](https://github.com/shopwareLabs/claude-code-plugins/issues/new?template=command_issue.yml)** - Report issues with slash commands (`/research`, `/chunkhound-status`, etc.)
- **[🎯 Skill Quality Issue](https://github.com/shopwareLabs/claude-code-plugins/issues/new?template=skill_issue.yml)** - Report issues with auto-invoked skills
- **[🤖 Agent Quality Issue](https://github.com/shopwareLabs/claude-code-plugins/issues/new?template=agent_issue.yml)** - Report issues with specialized subagents
- **[🪝 Hook Quality Issue](https://github.com/shopwareLabs/claude-code-plugins/issues/new?template=hook_issue.yml)** - Report issues with PreToolUse/PostToolUse hooks and pattern matching
- **[🔌 MCP Server Issue](https://github.com/shopwareLabs/claude-code-plugins/issues/new?template=mcp_issue.yml)** - Report issues with MCP server tools and configuration
- **[⚙️ Plugin Component Issue](https://github.com/shopwareLabs/claude-code-plugins/issues/new?template=plugin_component_other.yml)** - Report issues with other plugin components

## Third-Party Integrations

Some plugins in this marketplace integrate with external services (e.g. `chunkhound-integration` wraps the ChunkHound CLI with user-configured embedding providers such as VoyageAI, OpenAI, or Ollama). These integrations are entirely opt-in and user-configured: the plugins invoke user-installed CLI tools using environment variables and configuration files supplied by the user. Shopware Labs does not receive, store, or route any data processed through these integrations. Users who configure external AI providers are solely responsible for compliance with those providers' terms of service and any applicable data protection requirements, including obligations arising from transfers to third countries.

## License

This project is licensed under the [MIT License](./LICENSE).
