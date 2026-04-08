# Shopware AI Coding Tools

> **Experimental Community Project**: This repository is maintained by Shopware Labs and is not an official Shopware product. It is not affiliated with, endorsed by, or sponsored by Anthropic or any other AI provider. "Claude" and "Claude Code" are trademarks of Anthropic. This project is provided as-is without warranty.

A [Claude Code plugin marketplace](https://docs.claude.com/en/docs/claude-code/plugins) for Shopware development. Provides development tools, test generation, code research, and more — integrated directly into your Claude Code workflow.

## ⚡ Quick Start

**Requirements:** [Claude Code](https://docs.claude.com/en/docs/claude-code) installed.

Add the marketplace, then install the plugins you need:

```bash
/plugin marketplace add shopwareLabs/ai-coding-tools
/plugin install dev-tooling@shopware-ai-coding-tools
```

Restart Claude Code after installing plugins that include MCP servers.

## 🧩 Available Plugins

| Plugin                                                  | Description                                                                                                 | Components                                          |
|---------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|-----------------------------------------------------|
| [dev-tooling](#dev-tooling)                             | PHPStan, ECS, PHPUnit, ESLint, Stylelint, Jest, and more via MCP servers. Includes Shopware LSP.            | 🔌 MCP · 🪝 Hooks · 🧠 LSP                          |
| [gh-tooling](#gh-tooling)                               | GitHub CLI wrapper for PRs, issues, CI runs, and search.                                                    | 🔌 MCP · 🪝 Hooks                                   |
| [test-writing](#test-writing)                           | Automated PHPUnit test generation and validation for Shopware 6.                                            | 🎯 Skills · 🤖 Agents · 🔌 MCP                      |
| [chunkhound-integration](#chunkhound-integration)       | Semantic code research using ChunkHound.                                                                    | 🔌 MCP · 🎯 Skills · 🤖 Agents · 💬 Cmds · 🪝 Hooks |
| [ci-failure-interpretation](#ci-failure-interpretation) | CI failure log interpretation for GitHub Actions workflows.                                                 | 🎯 Skills                                           |
| [contributor-writing](#contributor-writing)             | ADRs, PR descriptions, commit messages, RELEASE_INFO, and UPGRADE entries for the Shopware core repository. | 🎯 Skills                                           |

### dev-tooling

Three MCP servers for PHP and JavaScript operations plus Shopware LSP for intelligent code completion. Supports native, Docker, Vagrant, and DDEV environments.

```bash
/plugin install dev-tooling@shopware-ai-coding-tools
```

- **PHP:** PHPStan static analysis, ECS code style, PHPUnit test runner with coverage gap analysis, Symfony Console
- **Administration JS:** ESLint, Stylelint, Prettier, Jest, TypeScript, Vite builds
- **Storefront JS:** ESLint, Stylelint, Jest, Webpack builds
- **Shopware LSP:** Service ID completion, Twig templates, snippets, routes, feature flags

Prerequisites: `jq`, restart after install. For LSP: [`shopware-lsp`](https://github.com/shopwareLabs/shopware-lsp/releases) binary in PATH.

See [full documentation](./plugins/dev-tooling/README.md) for configuration and tool reference.

### gh-tooling

GitHub CLI MCP server for pull requests, issues, CI runs, jobs, commits, and search. Works without configuration when `gh` is authenticated.

```bash
/plugin install gh-tooling@shopware-ai-coding-tools
```

- **PRs:** view, diff, list, checks, comments, reviews, files, commits
- **Issues:** view, list
- **CI:** run status, logs, job-level debugging, annotations
- **Other:** commit-to-PR lookup, cross-repo search, raw API access

Prerequisites: `jq`, `gh` CLI authenticated, restart after install.

See [full documentation](./plugins/gh-tooling/README.md) for configuration and tool reference.

### test-writing

Generates and validates PHPUnit unit tests for Shopware 6. Analyzes source classes, detects the test category (DTO, Service, Flow/Event, DAL, Exception), generates tests, reviews them against 46 Shopware-specific rules, and iterates fixes until they pass. Also supports team-based consensus review using [Agent Teams](https://code.claude.com/docs/en/agent-teams) (experimental).

```bash
/plugin install test-writing@shopware-ai-coding-tools
```

Just ask Claude to generate tests — the skill activates automatically:

```
Generate unit tests for src/Core/Content/Product/ProductEntity.php
```

Prerequisites: `dev-tooling` plugin installed, `.mcp-php-tooling.json` in project root, restart after install.

See [full documentation](./plugins/test-writing/README.md) for categories, rules, and workflow details.

### chunkhound-integration

Semantic code research using [ChunkHound's](https://chunkhound.github.io/) multi-hop search and LLM synthesis. Understands code architecture, traces data flows, and discovers component relationships.

```bash
/plugin install chunkhound-integration@shopware-ai-coding-tools
```

```
/research how does authentication work in this codebase?
/research find all payment service dependencies
```

Prerequisites: ChunkHound installed (`uv tool install chunkhound`), embedding provider configured, index initialized, restart after install.

See [full documentation](./plugins/chunkhound-integration/README.md) for setup and configuration.

### ci-failure-interpretation

Knowledge skill for interpreting CI failure logs from Shopware GitHub Actions workflows. Covers PHPUnit, PHPStan, ECS, ESLint, TypeScript, Stylelint, Prettier, Jest, Playwright, ludtwig, and Lighthouse.

```bash
/plugin install ci-failure-interpretation@shopware-ai-coding-tools
```

The skill activates automatically when analyzing CI failures — just ask Claude to interpret logs or debug a failed CI run. No prerequisites beyond installation.

See [full documentation](./plugins/ci-failure-interpretation/README.md) for supported tools and failure patterns.

### contributor-writing

Writing skills for Shopware core contributors: Architecture Decision Records, PR descriptions, commit messages, and `RELEASE_INFO`/`UPGRADE` entries. Analyzes branch diffs, classifies changes, asks for context, and writes content calibrated to change magnitude.

```bash
/plugin install contributor-writing@shopware-ai-coding-tools
```

```
Write an ADR about switching to Redis for cart persistence
Write a PR description for my changes
Write a release info entry for my changes
Generate a squash commit message for this branch
Write a commit message for my changes
```

Skills activate automatically. Requires `gh-tooling` plugin for PR analysis.

See [full documentation](./plugins/contributor-writing/README.md) for workflow details and writing rules.

## 🐛 Reporting Issues

Found a bug or quality issue? [Open an issue](https://github.com/shopwareLabs/ai-coding-tools/issues/new/choose) using our specialized templates for commands, skills, agents, hooks, MCP servers, or other components.

## 🔗 Third-Party Integrations

Some plugins in this marketplace integrate with external services (e.g. `chunkhound-integration` wraps the ChunkHound CLI with user-configured embedding providers such as VoyageAI, OpenAI, or Ollama). These integrations are entirely opt-in and user-configured: the plugins invoke user-installed CLI tools using environment variables and configuration files supplied by the user. Shopware Labs does not receive, store, or route any data processed through these integrations. Users who configure external AI providers are solely responsible for compliance with those providers' terms of service and any applicable data protection requirements, including obligations arising from transfers to third countries.

## ⚖️ License

This project is licensed under the [MIT License](./LICENSE).

---

> [!NOTE]
> Yes, an AI wrote this README. And everything else as well.
> Yes, a human told it to add emojis. The human has ADHD, which
> — as it turns out — means his brain already ran on associative
> pattern-matching and nonlinear leaps before LLMs made it cool.
> They call him ... LLMartin. The emojis are a feature.
